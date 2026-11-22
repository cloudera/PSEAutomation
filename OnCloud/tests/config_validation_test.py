import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
COMMON = {
    "PROVISION_KEYCLOAK": "NO",
    "PROVISION_CAII": "NO",
    "WORKSHOP_NAME": "testworkshop",
    "NUMBER_OF_WORKSHOP_USERS": "1",
    "WORKSHOP_USER_PREFIX": "user",
    "WORKSHOP_USER_DEFAULT_PASSWORD": "test",
    "CDP_DEPLOYMENT_TYPE": "public",
    "LOCAL_MACHINE_IP": "127.0.0.1/32",
    "ENABLE_DATA_SERVICES": "[None]",
    "DOMAIN": "example.com",
    "HOSTEDZONEID": "Z123456",
    "DATALAKE_VERSION": "7.3.2",
}


class ConfigValidationTest(unittest.TestCase):
    def test_read_only_crlf_and_missing_region(self):
        for cloud, region in (("AWS", "ap-southeast-1"), ("Azure", "westus2")):
            for include_region in (True, False):
                with self.subTest(cloud=cloud, include_region=include_region):
                    values = dict(COMMON)
                    if include_region:
                        values[f"{cloud.upper()}_REGION"] = region
                    content = "".join(f"{key}:{value}\r\n" for key, value in values.items()).encode()
                    with tempfile.TemporaryDirectory() as directory:
                        config = Path(directory) / "configfile"
                        config.write_bytes(content)
                        config.chmod(0o444)
                        script = ROOT / "OnCloud" / cloud / "build" / "entrypoint" / "hol-functions.sh"
                        result = subprocess.run(
                            [
                                "bash", "-c",
                                'source "$1"; USER_CONFIG_FILE="$2"; '
                                'sleep() { :; }; validating_variables',
                                "config-test", str(script), str(config),
                            ],
                            env={**os.environ, "HOME_DIR": "/tmp"},
                            capture_output=True,
                            text=True,
                        )
                        self.assertEqual(config.read_bytes(), content)
                        self.assertEqual(result.returncode == 0, include_region, result.stdout + result.stderr)
                        if not include_region:
                            self.assertIn(f"{cloud.upper()}_REGION", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
