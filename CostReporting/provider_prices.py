#!/usr/bin/env python3
"""Extract pinned, flat provider prices from local AWS catalog/Azure retail exports."""
import argparse
from decimal import Decimal
import json
from pathlib import Path
import sys

from report import InputError, load, number, period, require, scope_check, stamp, text

UNITS = {"Hrs": "hour", "GB-Mo": "GB-month", "1 Hour": "hour", "1 GB/Month": "GB-month"}


def convert(export, context):
    meta = context["metadata"]
    scope_check(meta["scope"])
    provider = meta["scope"]["provider"]
    start, end = period(context["valid_period"])
    report_start, report_end = period(meta["period"])
    require(start <= report_start < report_end <= end, "quote validity must cover report period")
    text(context["source"], "provider price export source")
    text(context["validity_assumption"], "validity_assumption")
    require(stamp(context["as_of"]) <= stamp(meta["generated_at"]), "future price snapshot")
    bindings = context["bindings"]
    require(isinstance(bindings, list) and bindings, "price bindings must be nonempty")
    rates, seen = [], set()
    for binding in bindings:
        require(isinstance(binding, dict), "price binding must be an object")
        key = tuple(text(binding.get(k), k) for k in ("region", "service", "sku", "unit", "terms"))
        require(key not in seen, "duplicate native price selector")
        seen.add(key)
        if provider == "aws":
            sku = text(binding["provider_sku"], "AWS product SKU")
            product = export["products"][sku]
            require(isinstance(product, dict), "AWS product must be an object")
            attrs = product["attributes"]
            offer = export["terms"]["OnDemand"][sku][binding["offer_id"]]
            require(isinstance(attrs, dict) and isinstance(offer, dict), "AWS attributes/offer must be objects")
            dimension = offer["priceDimensions"][binding["dimension_id"]]
            require(isinstance(dimension, dict), "AWS price dimension must be an object")
            require(dimension["beginRange"] == "0" and dimension["endRange"] == "Inf"
                    and not dimension.get("appliesTo"), "tiered/conditional AWS rates unsupported")
            native_unit = dimension["unit"]
            amount = dimension["pricePerUnit"][meta["currency"]]
            require(isinstance(amount, str), "AWS pricePerUnit must be a decimal string")
            number(amount, "AWS provider price")
            require(attrs["regionCode"] == binding["region"], "AWS product region mismatch")
            require(attrs["servicecode"] == "AmazonEC2" and product["productFamily"] == "Compute Instance",
                    "AWS native adapter currently supports only EC2 compute")
            require(binding["service"] == "AmazonEC2" and attrs["instanceType"] == binding["sku"],
                    "AWS instance SKU/service mismatch")
            native_terms = "/".join(text(attrs.get(key), key) for key in
                                    ("operatingSystem", "tenancy", "preInstalledSw", "capacitystatus"))
            require(binding["terms"] == native_terms, f"AWS terms must equal {native_terms}")
            effective = offer["effectiveDate"]
            source = f'{context["source"]}#{sku}/{binding["offer_id"]}/{binding["dimension_id"]}'
        else:
            require(isinstance(export.get("Items"), list), "Azure retail export requires Items")
            require(all(isinstance(item, dict) for item in export["Items"]), "Azure Items must be objects")
            require(not export.get("NextPageLink"), "Azure price export is paginated; supply a complete captured page set")
            matches = [item for item in export["Items"] if item.get("meterId") == binding["meter_id"]
                       and item.get("skuId") == binding["provider_sku"]
                       and item.get("type") == "Consumption"
                       and item.get("isPrimaryMeterRegion") is True
                       and item.get("armRegionName") == binding["region"]]
            require(len(matches) == 1, "Azure meter binding must match exactly one primary consumption price")
            item = matches[0]
            require(not item.get("reservationTerm") and not item.get("savingsPlan"),
                    "Azure reservation/savings plan prices unsupported")
            require(item["currencyCode"] == meta["currency"], "Azure price currency mismatch")
            require(item["serviceName"] == binding["service"] and item["armSkuName"] == binding["sku"],
                    "Azure SKU/service mismatch")
            require(item.get("tierMinimumUnits") == 0, "Azure tiered rates unsupported")
            native_terms = "/".join(text(item.get(key), key) for key in ("productName", "skuName", "meterName"))
            require(binding["terms"] == native_terms, f"Azure terms must equal {native_terms}")
            native_unit = item["unitOfMeasure"]
            # load() parses provider JSON numbers directly as Decimal, never through float.
            require(type(item["retailPrice"]) in (Decimal, int), "Azure retailPrice must be a JSON number")
            amount = str(item["retailPrice"])
            number(amount, "Azure retail price")
            effective = item["effectiveStartDate"]
            source = f'{context["source"]}#{binding["provider_sku"]}/{binding["meter_id"]}'
        require(native_unit in UNITS and UNITS[native_unit] == binding["unit"], "unsupported/mismatched price unit")
        require(stamp(effective) <= start, "provider effective date after declared quote validity start")
        require(stamp(effective) <= stamp(context["as_of"]), "price effective after snapshot")
        rates.append({**{key: binding[key] for key in ("region", "service", "sku", "unit", "terms")},
                      "rate": amount, "currency": meta["currency"], "source": source,
                      "as_of": context["as_of"], "valid_period": context["valid_period"],
                      "provider_effective_at": effective,
                      "validity_assumption": context["validity_assumption"]})
    return {"schema_version": 1, "scope": meta["scope"], "source": context["source"],
            "as_of": context["as_of"], "rates": rates}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", required=True)
    parser.add_argument("--context", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    try:
        result = convert(load(args.export), load(args.context))
        with Path(args.output).open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(result, indent=2) + "\n")
        Path(args.output).chmod(0o600)
    except (InputError, OSError, ValueError, TypeError, KeyError) as exc:
        print(f"provider-prices: ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
