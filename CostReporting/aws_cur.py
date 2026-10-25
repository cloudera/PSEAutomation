#!/usr/bin/env python3
"""Normalize a local AWS CUR CSV export, with strict scope and no cloud access."""
import argparse
import csv
import json
from pathlib import Path
import sys

from report import InputError, billed, load, require, text


def convert(rows, context):
    meta = context["metadata"]
    require(meta["scope"]["provider"] == "aws", "CUR requires AWS scope")
    credit_refs = context.get("credit_references", {})
    require(isinstance(credit_refs, dict), "credit_references must be an object")
    lines, references = [], set()
    for row in rows:
        require(row.get("lineItem/UsageAccountId") == meta["scope"]["account"],
                "CUR account mismatch; supply one scoped account export")
        require(row.get("lineItem/CurrencyCode") == meta["currency"], "CUR currency mismatch")
        for key, value in meta["scope"]["tags"].items():
            require(row.get(f"resourceTags/user:{key}") == value, f"CUR tag mismatch: {key}")
        kind = row.get("lineItem/LineItemType")
        require(kind in ("Usage", "DiscountedUsage", "Fee", "RIFee", "Tax", "Credit", "Refund"),
                f"unsupported CUR line type {kind}; do not drop adjustments silently")
        line_id = text(row.get("identity/LineItemId"), "CUR line ID")
        credit = kind in ("Credit", "Refund")
        line = {"line_id": line_id,
                "resource_id": text(row.get("lineItem/ResourceId"), "CUR resource ID"),
                "region": text(row.get("product/region"), "CUR region"),
                "meter": ":".join(text(row.get(key), key) for key in
                                  ("lineItem/UsageType", "lineItem/Operation")) + f":{kind}",
                "period": {"start": row.get("lineItem/UsageStartDate"),
                           "end": row.get("lineItem/UsageEndDate")},
                "amount": row.get("lineItem/UnblendedCost"), "kind": "credit" if credit else "charge"}
        if credit:
            line["charge_id"] = text(credit_refs.get(line_id), "credit reference")
            references.add(line_id)
        lines.append(line)
    require(references == set(credit_refs), "unused credit reference IDs")
    charges = {line["line_id"]: line for line in lines if line["kind"] == "charge"}
    for line in lines:
        if line["kind"] == "credit":
            charge = charges.get(line["charge_id"])
            require(charge is not None, "credit reference charge missing")
            # CUR uses a different line type for credits, but the meter must identify its charge.
            line["meter"] = charge["meter"]
    doc = {"schema_version": 1, "source": context["source"], "as_of": context["as_of"],
           "scope": meta["scope"], "period": meta["period"], "currency": meta["currency"],
           "metric": "unblended_cost", "complete": context["complete"],
           "coverage_note": context["coverage_note"], "credits_policy": context["credits_policy"],
           "lines": lines}
    billed(doc, meta)
    return doc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cur", required=True)
    parser.add_argument("--context", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    try:
        with Path(args.cur).open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            require(reader.fieldnames and len(reader.fieldnames) == len(set(reader.fieldnames)),
                    "CUR requires unique CSV headers")
            doc = convert(reader, load(args.context))
        with Path(args.output).open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(doc, indent=2) + "\n")
        Path(args.output).chmod(0o600)
    except (InputError, OSError, ValueError, TypeError, KeyError, csv.Error) as exc:
        print(f"aws-cur: ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
