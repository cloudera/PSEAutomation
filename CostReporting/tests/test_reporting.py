import copy
import csv
from decimal import Decimal
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import aws_cur
import report
import terraform_inventory
import provider_prices

FIXTURES = Path(__file__).parent / "fixtures"
ROOT = Path(__file__).resolve().parents[1]


class Reports(unittest.TestCase):
    def setUp(self):
        self.inv = report.load(FIXTURES / "inventory.json")
        self.price = report.load(FIXTURES / "pricing.json")
        self.bill = report.load(FIXTURES / "billing.json")

    def build(self):
        return report.build(self.inv, self.price, self.bill)

    def test_formats_reconcile_and_credits_stay_separate(self):
        result = self.build()
        self.assertEqual(result["estimates"]["total"], "3.042963")
        self.assertEqual(result["actuals"]["total"], "2.000000")
        rendered = report.render(result)
        self.assertEqual(json.loads(rendered["report.json"]), result)
        ledger = list(csv.DictReader(io.StringIO(rendered["report.csv"])))
        for section, key in (("ESTIMATE", "estimates"), ("BILLED", "actuals")):
            total = sum(Decimal(row["amount"]) for row in ledger if row["section"] == section)
            self.assertEqual(total, Decimal(result[key]["total"]))
        for row in ledger:
            self.assertIn(row["section"], rendered["report.txt"])
            if row["amount"]:
                self.assertIn(row["amount"], rendered["report.txt"])
        self.assertNotIn("5.042963", rendered["report.txt"])

    def test_partial_unknown_and_unavailable_not_zero(self):
        self.price["rates"].pop()
        result = report.build(self.inv, self.price)
        self.assertIsNone(result["resources"][1]["amount"])
        self.assertEqual(result["estimates"]["priced_subtotal"], "2.962963")
        self.assertIsNone(result["estimates"]["total"])
        self.assertIsNone(result["actuals"]["total"])
        self.assertEqual(result["actuals"]["status"], "unavailable")
        self.assertEqual(result["coverage"]["priced_percent"], "50")
        self.inv["resources"][0]["quantity"] = None
        self.assertIsNone(report.build(self.inv, self.price)["estimates"]["priced_subtotal"])

    def test_explicit_zero_is_priced_and_exclusion_incomplete(self):
        self.inv["resources"][0]["quantity"] = "0"
        self.inv["exclusions"] = ["Networking usage not inventoried"]
        result = self.build()
        self.assertEqual(result["resources"][0]["amount"], "0.000000")
        self.assertIsNone(result["estimates"]["total"])
        self.assertEqual(result["coverage"]["unpriced"], 0)
        self.assertFalse(result["coverage"]["complete"])

    def test_line_rounding_half_even_and_subtotal_sum(self):
        self.inv["resources"][0]["quantity"] = "1"
        self.price["rates"][0]["rate"] = "0.0000005"
        self.price["rates"][1]["rate"] = "0.0000015"
        result = self.build()
        self.assertEqual([r["amount"] for r in result["resources"]], ["0.000000", "0.000002"])
        self.assertEqual(result["estimates"]["total"], "0.000002")

    def test_duplicate_resources_prices_and_json_keys(self):
        for doc, key in ((self.inv, "resources"), (self.price, "rates"), (self.bill, "lines")):
            doc[key].append(copy.deepcopy(doc[key][0]))
            with self.assertRaises(report.InputError):
                self.build()
            doc[key].pop()
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "duplicate.json"
            path.write_text('{"a": 1, "a": 2}')
            with self.assertRaises(report.InputError):
                report.load(path)

    def test_invalid_quantities(self):
        for value in ("NaN", "Infinity", "-1", "1e2", 2.1, True, "0.1234567890123", ""):
            self.inv["resources"][0]["quantity"] = value
            with self.subTest(value=value), self.assertRaises(report.InputError):
                self.build()

    def test_mismatches_and_missing_evidence(self):
        changes = [
            (self.price, "currency", "EUR", True),
            (self.bill, "currency", "EUR", False),
            (self.bill, "metric", "amortized_cost", False),
            (self.bill, "scope", {"provider": "azure"}, False),
            (self.price, "as_of", "2099-01-01T00:00:00Z", False),
            (self.bill, "source", "", False),
        ]
        for doc, key, value, rate in changes:
            target = doc["rates"][0] if rate else doc
            old = target.get(key)
            target[key] = value
            with self.subTest(key=key), self.assertRaises(report.InputError):
                self.build()
            target[key] = old
        self.price["rates"][0]["valid_period"]["end"] = "2026-10-01T12:00:00Z"
        with self.assertRaises(report.InputError):
            self.build()

    def test_period_overlap_credit_and_partial_billing(self):
        row = copy.deepcopy(self.bill["lines"][0])
        row["line_id"] = "different-id-same-charge"
        self.bill["lines"].append(row)
        with self.assertRaises(report.InputError):
            self.build()
        self.bill["lines"].pop()
        self.bill["complete"] = False
        self.assertIsNone(self.build()["actuals"]["total"])
        self.assertEqual(self.build()["actuals"]["priced_subtotal"], "2.000000")
        self.bill["lines"][1]["amount"] = "0.5"
        with self.assertRaises(report.InputError):
            self.build()
        self.bill["lines"][1]["amount"] = "-0.5"
        self.bill["lines"][1]["charge_id"] = "absent"
        with self.assertRaises(report.InputError):
            self.build()
        self.bill["lines"][1]["charge_id"] = "charge-1"
        self.bill["period"]["end"] = "2026-10-03T00:00:00Z"
        with self.assertRaises(report.InputError):
            self.build()

    def test_credits_already_included_cannot_be_added_again(self):
        self.bill["credits_policy"] = "included_in_amounts"
        with self.assertRaises(report.InputError):
            self.build()
        self.bill["lines"].pop()
        self.assertEqual(self.build()["actuals"]["total"], "2.500000")
        self.bill["credits_policy"] = "excluded_or_unknown"
        with self.assertRaises(report.InputError):
            self.build()
        self.bill["complete"] = False
        self.bill["lines"] = []
        self.assertIsNone(self.build()["actuals"]["priced_subtotal"])

    def test_billing_precision_and_freshness(self):
        self.bill["lines"] = [self.bill["lines"][0]]
        self.bill["lines"][0]["amount"] = "999999999999999999.1234567"
        value = report.billed(self.bill, self.inv["metadata"])
        self.assertEqual(value["total"], "999999999999999999.123457")
        self.assertEqual(value["freshness_age_hours"], "12")
        self.bill["as_of"] = "2026-10-01T12:00:00Z"
        with self.assertRaises(report.InputError):
            self.build()

    def test_invalid_timestamps_shape_and_missing_quantity(self):
        self.inv["metadata"]["period"]["end"] = "2026-10-01T00:00:00Z"
        with self.assertRaises(report.InputError):
            self.build()
        self.inv["metadata"]["period"]["end"] = "2026-10-02T00:00:00"
        with self.assertRaises(report.InputError):
            self.build()
        self.inv["metadata"]["period"]["end"] = "2026-10-02T00:00:00Z"
        self.inv["resources"][0].pop("quantity")
        with self.assertRaises(report.InputError):
            self.build()

    def test_node_counts_group_rollups_and_monthly_scenario(self):
        compute = self.inv["resources"][0]
        compute["specs"] = {"role": "worker", "vcpu": "2", "memory_gib": "4",
                            "source": "fixture://provider-instance-type-export"}
        second = copy.deepcopy(compute)
        second["resource_id"] = "i-fixture-2"
        self.inv["resources"].append(second)
        self.inv["metadata"].update(monthly_hours="720", monthly_assumption="Uniform 720-hour scenario.")
        result = self.build()
        group = next(group for group in result["groups"] if group["meter"] == "compute")
        self.assertEqual(group["node_count"], 2)
        self.assertEqual(group["resource_count"], 2)
        self.assertEqual(group["usage_quantity"], "48")
        self.assertEqual(group["group_vcpu"], "4")
        self.assertEqual(group["group_memory_gib"], "8")
        self.assertEqual(group["total"], "5.925926")
        self.assertEqual(group["monthly_total"], "177.777764")
        for row in group["members"]:
            self.assertEqual(row["monthly_amount"], "88.888882")
        self.assertEqual(sum(Decimal(group["total"]) for group in result["groups"]),
                         Decimal(result["estimates"]["total"]))
        self.assertEqual(sum(Decimal(group["monthly_total"]) for group in result["groups"]),
                         Decimal(result["estimates"]["monthly_scenario"]["total"]))
        ledger = list(csv.DictReader(io.StringIO(report.render(result)["report.csv"])))
        self.assertEqual(sum(Decimal(row["amount"]) for row in ledger if row["section"] == "ESTIMATE_GROUP"),
                         Decimal(result["estimates"]["priced_subtotal"]))
        self.assertEqual(sum(Decimal(row["monthly_amount"]) for row in ledger if row["section"] == "ESTIMATE"),
                         Decimal(result["estimates"]["monthly_scenario"]["priced_subtotal"]))

    def test_missing_specs_and_monthly_hours_stay_unavailable(self):
        result = self.build()
        self.assertIsNone(result["resources"][0]["specs"]["vcpu"])
        self.assertIsNone(result["resources"][0]["monthly_amount"])
        self.assertIsNone(result["estimates"]["monthly_scenario"]["total"])
        self.inv["metadata"]["monthly_hours"] = "720"
        with self.assertRaises(report.InputError):
            self.build()
        self.inv["metadata"]["monthly_assumption"] = "Fixed scenario"
        self.inv["resources"][0]["specs"] = {"vcpu": "2"}
        with self.assertRaises(report.InputError):
            self.build()

    def test_unknown_group_retains_known_partial_subtotal(self):
        second = copy.deepcopy(self.inv["resources"][0])
        second["resource_id"] = "i-unknown-hours"
        second["quantity"] = None
        self.inv["resources"].append(second)
        result = self.build()
        group = next(group for group in result["groups"] if group["meter"] == "compute")
        self.assertEqual(group["node_count"], 2)
        self.assertIsNone(group["usage_quantity"])
        self.assertIsNone(group["total"])
        self.assertEqual(group["priced_subtotal"], "2.962963")

    def test_network_units_and_shared_resources_not_counted_as_nodes(self):
        for meter, unit, qty in (("nat-runtime", "hour", "24"), ("nat-data", "GB", "10")):
            row = {**self.inv["resources"][0], "resource_id": "nat-fixture", "meter": meter,
                   "service": "AmazonVPC", "sku": meter, "unit": unit, "quantity": qty}
            self.inv["resources"].append(row)
            rate = {**self.price["rates"][0], "service": "AmazonVPC", "sku": meter,
                    "unit": unit, "rate": "0.1"}
            self.price["rates"].append(rate)
        result = self.build()
        self.assertEqual(result["coverage"]["compute_nodes"], 1)
        self.assertEqual(result["coverage"]["physical_resources"], 3)
        self.assertEqual(result["coverage"]["resource_meters"], 4)
        network = [group for group in result["groups"] if group["service"] == "AmazonVPC"]
        self.assertEqual({group["unit"] for group in network}, {"hour", "GB"})
        self.assertTrue(all(group["node_count"] is None for group in network))
        self.assertEqual(sum(Decimal(group["total"]) for group in result["groups"]),
                         Decimal(result["estimates"]["total"]))
        duplicate = copy.deepcopy(self.inv["resources"][-1])
        duplicate["workflow"] = "Utilities"
        self.inv["resources"].append(duplicate)
        with self.assertRaises(report.InputError):
            self.build()

    def test_adjacent_billing_windows_allowed_outside_rejected(self):
        self.bill["lines"] = [self.bill["lines"][0]]
        row = copy.deepcopy(self.bill["lines"][0])
        row["line_id"] = "charge-2"
        self.bill["lines"][0]["period"]["end"] = "2026-10-01T12:00:00Z"
        row["period"]["start"] = "2026-10-01T12:00:00Z"
        self.bill["lines"].append(row)
        self.assertEqual(self.build()["actuals"]["total"], "5.000000")
        row["period"]["end"] = "2026-10-03T00:00:00Z"
        with self.assertRaises(report.InputError):
            self.build()

    def test_cli_artifacts_errors_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "report"
            args = [sys.executable, str(ROOT / "report.py"),
                    "--inventory", str(FIXTURES / "inventory.json"),
                    "--pricing", str(FIXTURES / "pricing.json"), "--output", str(output)]
            process = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual({p.name for p in output.iterdir()}, {"report.json", "report.csv", "report.txt"})
            self.assertEqual(output.stat().st_mode & 0o777, 0o700)
            for path in output.iterdir():
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            doc = report.load(output / "report.json")
            self.assertIn("pricing", doc["metadata"]["input_sha256"])
            process = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(process.returncode, 2)
            self.assertIn("ERROR", process.stderr)


class InventoryAdapters(unittest.TestCase):
    def setUp(self):
        self.snapshot = report.load(FIXTURES / "terraform.json")
        self.context = report.load(FIXTURES / "terraform-context.json")
        self.price = report.load(FIXTURES / "pricing.json")

    def convert(self):
        return terraform_inventory.convert(self.snapshot, self.context, "PvC-InfraDeployer")

    def test_real_shape_nested_terraform_quantities_and_resource_identity(self):
        inventory = self.convert()
        self.assertEqual([Decimal(r["quantity"]) for r in inventory["resources"]],
                         [Decimal("24"), Decimal("1")])
        self.assertEqual(inventory["resources"][1]["resource_id"], "vol-fixture")
        result = report.build(inventory, self.price)
        self.assertEqual(result["estimates"]["priced_subtotal"], "3.042963")
        self.assertIsNone(result["estimates"]["total"])  # Export cannot prove full cloud inventory.

    def test_missing_terms_does_not_infer_os_or_price(self):
        self.context["terms"] = {}
        result = report.build(self.convert(), self.price)
        self.assertEqual(result["coverage"]["unpriced"], 2)

    def test_fractional_storage_month_is_valid_decimal(self):
        self.context["month_hours"] = "730"
        result = report.build(self.convert(), self.price)
        self.assertEqual(result["coverage"]["priced"], 2)

    def test_terraform_specs_preserve_evidenced_disk_and_cpu(self):
        resource = self.snapshot["values"]["root_module"]["child_modules"][0]["resources"][0]
        resource["values"]["cpu_options"] = [{"core_count": 2, "threads_per_core": 2}]
        resource["values"]["root_block_device"][0].update(iops=3000, throughput=125)
        self.context["specs"] = {
            resource["address"] + "/compute": {"role": "worker", "memory_gib": "16",
                                              "source": "fixture://instance-type-export"}}
        inventory = self.convert()
        compute, disk = inventory["resources"]
        self.assertEqual(compute["specs"]["vcpu"], "4")
        self.assertEqual(compute["specs"]["memory_gib"], "16")
        self.assertEqual(disk["specs"]["disk_gb"], "30")
        self.assertEqual(disk["specs"]["disk_type"], "gp3")
        self.assertEqual(disk["specs"]["iops"], "3000")
        self.assertEqual(disk["specs"]["throughput_mbps"], "125")

    def test_wrong_region_and_unused_terms_rejected(self):
        self.context["region"] = "us-west-2"
        with self.assertRaises(report.InputError):
            self.convert()
        self.context["region"] = "us-east-1"
        self.context["terms"]["nonexistent/storage"] = "wrong"
        with self.assertRaises(report.InputError):
            self.convert()

    def test_state_and_plan_basis_do_not_mix(self):
        self.context["basis"] = "planned"
        with self.assertRaises(report.InputError):
            self.convert()
        self.snapshot["planned_values"] = self.snapshot.pop("values")
        self.assertTrue(self.convert()["resources"][0]["resource_id"].startswith("planned:"))

    def test_azure_compute_and_disk_remains_unknown(self):
        self.context["metadata"]["scope"]["provider"] = "azure"
        self.context["region"] = "westus2"
        self.context["terms"] = {"azurerm_linux_virtual_machine.host/compute": "linux-ondemand"}
        self.snapshot["values"]["root_module"] = {"resources": [{
            "address": "azurerm_linux_virtual_machine.host", "type": "azurerm_linux_virtual_machine",
            "values": {"id": "/subscriptions/fixture/vm/host", "size": "Standard_D4s_v5",
                       "location": "West US 2"}}]}
        result = terraform_inventory.convert(self.snapshot, self.context, "OnCloud/Azure")
        self.assertEqual(result["resources"][0]["sku"], "Standard_D4s_v5")
        self.assertIsNone(result["resources"][1]["quantity"])

    def test_cur_native_columns_credits_and_scope_checks(self):
        billing = report.load(FIXTURES / "billing.json")
        context = {**billing, "metadata": self.context["metadata"],
                   "credit_references": {"credit-1": "charge-1"}}
        rows = []
        for line in billing["lines"]:
            rows.append({
                "identity/LineItemId": line["line_id"], "lineItem/ResourceId": line["resource_id"],
                "lineItem/UsageAccountId": "fixture-account", "lineItem/CurrencyCode": "USD",
                "resourceTags/user:Workshop": "fixture", "product/region": "us-east-1",
                "lineItem/UsageType": "BoxUsage:t3.medium", "lineItem/Operation": "RunInstances",
                "lineItem/LineItemType": "Credit" if line["kind"] == "credit" else "Usage",
                "lineItem/UsageStartDate": line["period"]["start"],
                "lineItem/UsageEndDate": line["period"]["end"],
                "lineItem/UnblendedCost": line["amount"]})
        result = aws_cur.convert(rows, context)
        self.assertEqual(report.billed(result, context["metadata"])["total"], "2.000000")
        rows[0]["lineItem/UsageAccountId"] = "wrong"
        with self.assertRaises(report.InputError):
            aws_cur.convert(rows, context)


class ProviderPriceAdapters(unittest.TestCase):
    def setUp(self):
        self.export = report.load(FIXTURES / "aws-prices.json")
        self.context = report.load(FIXTURES / "price-context.json")

    def test_aws_native_price_evidence_and_report(self):
        price = provider_prices.convert(self.export, self.context)
        inv = report.load(FIXTURES / "inventory.json")
        inv["resources"][0]["terms"] = "Linux/Shared/NA/Used"
        result = report.build(inv, price)
        self.assertEqual(result["resources"][0]["amount"], "2.962963")
        self.assertIn("FAKE-DIMENSION", result["resources"][0]["price"]["source"])
        self.assertEqual(result["coverage"]["unpriced"], 1)

    def test_aws_tier_region_and_terms_rejected(self):
        binding = self.context["bindings"][0]
        for key, value in (("region", "wrong"), ("terms", "Windows"), ("unit", "GB-month")):
            old = binding[key]
            binding[key] = value
            with self.subTest(key=key), self.assertRaises(report.InputError):
                provider_prices.convert(self.export, self.context)
            binding[key] = old
        dimension = self.export["terms"]["OnDemand"]["FAKE-SKU"]["FAKE-OFFER"]["priceDimensions"]["FAKE-DIMENSION"]
        dimension["endRange"] = "100"
        with self.assertRaises(report.InputError):
            provider_prices.convert(self.export, self.context)

    def test_azure_native_decimal_not_binary_float(self):
        self.context["metadata"]["scope"]["provider"] = "azure"
        self.context["bindings"] = [{
            "meter_id": "meter-fixture", "provider_sku": "sku-fixture",
            "region": "westus2", "service": "Virtual Machines", "sku": "Standard_D4s_v5",
            "unit": "hour", "terms": "VM product/D4s v5/D4s v5"}]
        export = {"Items": [{
            "meterId": "meter-fixture", "skuId": "sku-fixture",
            "type": "Consumption", "isPrimaryMeterRegion": True, "armRegionName": "westus2",
            "currencyCode": "USD", "serviceName": "Virtual Machines",
            "armSkuName": "Standard_D4s_v5", "tierMinimumUnits": 0,
            "productName": "VM product", "skuName": "D4s v5", "meterName": "D4s v5",
            "unitOfMeasure": "1 Hour", "retailPrice": Decimal("0.123456789012"),
            "effectiveStartDate": "2026-10-01T00:00:00Z"}], "NextPageLink": None}
        result = provider_prices.convert(export, self.context)
        self.assertEqual(result["rates"][0]["rate"], "0.123456789012")
        export["Items"].append(copy.deepcopy(export["Items"][0]))
        with self.assertRaises(report.InputError):
            provider_prices.convert(export, self.context)
        export["Items"].pop()
        export["NextPageLink"] = "https://example.invalid/next"
        with self.assertRaises(report.InputError):
            provider_prices.convert(export, self.context)

    def test_cli_native_terraform_to_report_end_to_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            ctx = report.load(FIXTURES / "terraform-context.json")
            key = next(key for key in ctx["terms"] if key.endswith("/compute"))
            ctx["terms"][key] = "Linux/Shared/NA/Used"
            (tmp / "context.json").write_text(json.dumps(ctx))
            commands = [
                [sys.executable, str(ROOT / "terraform_inventory.py"),
                 "--terraform", str(FIXTURES / "terraform.json"),
                 "--context", str(tmp / "context.json"), "--workflow", "PvC-InfraDeployer",
                 "--output", str(tmp / "inventory.json")],
                [sys.executable, str(ROOT / "provider_prices.py"),
                 "--export", str(FIXTURES / "aws-prices.json"),
                 "--context", str(FIXTURES / "price-context.json"),
                 "--output", str(tmp / "pricing.json")],
                [sys.executable, str(ROOT / "report.py"),
                 "--inventory", str(tmp / "inventory.json"), "--pricing", str(tmp / "pricing.json"),
                 "--billing", str(FIXTURES / "billing.json"), "--output", str(tmp / "out")]]
            for command in commands:
                proc = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)
            result = report.load(tmp / "out/report.json")
            self.assertEqual(result["estimates"]["priced_subtotal"], "2.962963")
            self.assertIsNone(result["estimates"]["total"])
            self.assertEqual(result["actuals"]["total"], "2.000000")


if __name__ == "__main__":
    unittest.main()
