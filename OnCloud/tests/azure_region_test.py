import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS = ROOT / "OnCloud/Azure/build/entrypoint/hol-functions.sh"
HARNESS = r'''
source "$1"
az() {
    echo "$*" >> "$CALLS"
    case "$1 $2" in
        "account show") echo "subscription-id" ;;
        "rest --method") printf '%s\n' eastus westus2 unknown ;;
        "postgres flexible-server")
            local region=""
            while (($#)); do
                if [[ "$1" == "--location" ]]; then region="$2"; break; fi
                shift
            done
            case "$region" in
                eastus) printf '%s\n' '[{"versions":[],"skus":[],"restrictions":["Enabled"],"restricted":null,"reason":"Provisioning restricted"}]' ;;
                restricted) printf '%s\n' '[{"versions":["14"],"skus":["sku"],"restrictions":["Enabled"],"restricted":null,"reason":"Provisioning restricted"}]' ;;
                westus2) printf '%s\n' '[{"versions":["14"],"skus":["sku"],"restrictions":[],"restricted":null,"reason":null}]' ;;
                unknown) echo 'Azure query failed' >&2; return 1 ;;
                malformed) printf '%s\n' '{}' ;;
            esac ;;
        *) echo "Unexpected Azure command" >&2; return 1 ;;
    esac
}
azure_region="$2"
azure_postgres_flexible_server_region_supported
'''


class AzureRegionTest(unittest.TestCase):
    def run_region(self, region):
        with tempfile.TemporaryDirectory() as directory:
            calls = Path(directory) / "calls"
            result = subprocess.run(
                ["bash", "-c", HARNESS, "region-test", str(FUNCTIONS), region],
                env={**os.environ, "HOME_DIR": "/tmp", "CALLS": str(calls)},
                text=True, capture_output=True,
            )
            return result, calls.read_text()

    def test_available_region_is_read_only_and_repeatable(self):
        for _ in range(2):
            result, calls = self.run_region("westus2")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn("rest --method", calls)
            self.assertIn("--subscription subscription-id --location westus2", calls)

    def test_restricted_region_reports_verified_and_unverified_alternatives(self):
        result, calls = self.run_region("eastus")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Provisioning restricted", result.stderr)
        self.assertIn("westus2", result.stdout + result.stderr)
        self.assertIn("unknown", result.stdout + result.stderr)
        self.assertEqual(calls.count("--location eastus"), 1)

    def test_invalid_capability_response_fails_without_listing_regions(self):
        result, calls = self.run_region("malformed")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not verify", result.stdout + result.stderr)
        self.assertNotIn("rest --method", calls)

    def test_explicit_restriction_overrides_reported_versions_and_skus(self):
        result, calls = self.run_region("restricted")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Provisioning restricted", result.stderr)
        self.assertIn("westus2", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
