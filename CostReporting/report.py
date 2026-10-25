#!/usr/bin/env python3
"""Offline, evidence-backed infrastructure estimates and separate billed actuals."""
import argparse
import csv
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN, localcontext
import hashlib
import io
import json
from pathlib import Path
import re
import sys


class InputError(ValueError):
    """Invalid or ambiguous cost evidence."""


def require(condition, message):
    if not condition:
        raise InputError(message)


def text(value, name):
    require(isinstance(value, str) and bool(value.strip()), f"{name}: expected nonempty string")
    require(not any(ord(c) < 32 for c in value), f"{name}: control characters prohibited")
    return value


def number(value, name, negative=False):
    require(isinstance(value, str) and bool(re.fullmatch(r"-?\d{1,18}(\.\d{1,12})?", value)),
            f"{name}: use decimal string, at most 18 integer / 12 fractional digits")
    try:
        result = Decimal(value)
    except InvalidOperation as exc:
        raise InputError(f"{name}: invalid decimal") from exc
    require(negative or result >= 0, f"{name}: negative value")
    return result


def stamp(value):
    text(value, "timestamp")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise InputError(f"invalid ISO timestamp: {value}") from exc
    require(result.tzinfo is not None, "timestamps require timezone")
    return result.astimezone(timezone.utc)


def period(value):
    require(isinstance(value, dict) and set(value) == {"start", "end"}, "period requires start/end")
    start, end = stamp(value["start"]), stamp(value["end"])
    require(start < end, "period must have start before end (half-open interval)")
    return start, end


def money(value):
    with localcontext() as ctx:
        ctx.prec = 80
        return str(value.quantize(Decimal("0.000001"), rounding=ROUND_HALF_EVEN))


def load(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"duplicate JSON key: {key}")
            result[key] = value
        return result
    def reject_constant(value):
        raise InputError(f"nonfinite JSON value prohibited: {value}")
    with Path(path).open(encoding="utf-8") as stream:
        result = json.load(stream, object_pairs_hook=pairs, parse_float=Decimal,
                           parse_constant=reject_constant)
    require(isinstance(result, dict), "JSON document root must be an object")
    return result


def scope_check(scope):
    require(isinstance(scope, dict) and set(scope) == {"provider", "account", "tags"},
            "scope requires provider/account/tags (Azure account = subscription ID)")
    require(scope["provider"] in ("aws", "azure"), "provider must be aws or azure")
    text(scope["account"], "account")
    require(isinstance(scope["tags"], dict), "tags must be an object")
    for key, value in scope["tags"].items():
        text(key, "tag key")
        text(value, "tag value")


def evidence(doc, metadata, name):
    require(isinstance(doc, dict) and type(doc.get("schema_version")) is int
            and doc["schema_version"] == 1, f"{name}: schema_version must be 1")
    require(doc.get("scope") == metadata["scope"], f"{name}: scope mismatch")
    text(doc.get("source"), f"{name}.source")
    require(stamp(doc.get("as_of")) <= stamp(metadata["generated_at"]), f"{name}: future as_of")


def selector(row):
    return tuple(text(row.get(k), k) for k in ("region", "service", "sku", "unit", "terms"))


SPEC_FIELDS = ("role", "vcpu", "memory_gib", "disk_type", "disk_gb", "iops", "throughput_mbps", "source")


def specs(value):
    require(isinstance(value, dict) and not set(value) - set(SPEC_FIELDS), "invalid infrastructure specs")
    result = {key: value.get(key) for key in SPEC_FIELDS}
    for key in ("role", "disk_type", "source"):
        if result[key] is not None:
            text(result[key], f"specs.{key}")
    for key in ("vcpu", "memory_gib", "disk_gb", "iops", "throughput_mbps"):
        if result[key] is not None:
            number(result[key], f"specs.{key}")
    if any(result[key] is not None for key in SPEC_FIELDS if key != "source"):
        text(result["source"], "evidenced specs require source")
    return result


def groups(rows):
    grouped = {}
    for row in rows:
        properties = {k: v for k, v in row["specs"].items() if k != "source"}
        key = json.dumps([*selector(row), row["meter"], properties], sort_keys=True)
        grouped.setdefault(key, []).append(row)
    result = []
    for key, members in sorted(grouped.items()):
        first = members[0]
        known = [row for row in members if row["amount"] is not None]
        quantities = [row["quantity"] for row in members]
        monthly = [row["monthly_amount"] for row in members if row["monthly_amount"] is not None]
        subtotal = money(sum((Decimal(row["amount"]) for row in known), Decimal(0))) if known else None
        result.append({
            "group_id": hashlib.sha256(key.encode()).hexdigest()[:16],
            **{k: first[k] for k in ("region", "service", "sku", "unit", "terms", "meter")},
            "specs": {k: v for k, v in first["specs"].items() if k != "source"},
            "resource_count": len({row["resource_id"] for row in members}),
            "node_count": len({row["resource_id"] for row in members}) if first["meter"] == "compute" else None,
            "group_vcpu": str(Decimal(first["specs"]["vcpu"]) * len(members))
            if first["meter"] == "compute" and first["specs"]["vcpu"] is not None else None,
            "group_memory_gib": str(Decimal(first["specs"]["memory_gib"]) * len(members))
            if first["meter"] == "compute" and first["specs"]["memory_gib"] is not None else None,
            "usage_quantity": str(sum((Decimal(q) for q in quantities), Decimal(0)))
            if all(q is not None for q in quantities) else None,
            "unit_price": first["price"]["rate"] if first["price"] else None,
            "priced_subtotal": subtotal, "total": subtotal if len(known) == len(members) else None,
            "monthly_priced_subtotal": money(sum((Decimal(q) for q in monthly), Decimal(0))) if monthly else None,
            "monthly_total": money(sum((Decimal(q) for q in monthly), Decimal(0)))
            if len(monthly) == len(members) else None,
            "members": [{"resource_id": row["resource_id"], "usage_quantity": row["quantity"],
                         "amount": row["amount"], "monthly_amount": row["monthly_amount"]}
                        for row in members]})
    return result


def build(inventory, pricing, billing=None):
    with localcontext() as ctx:
        ctx.prec = 80
        return _build(inventory, pricing, billing)


def _build(inventory, pricing, billing):
    require(isinstance(inventory, dict), "inventory must be an object")
    meta = inventory.get("metadata")
    require(isinstance(meta, dict), "inventory.metadata required")
    scope_check(meta.get("scope"))
    start, end = period(meta.get("period"))
    stamp(meta.get("generated_at"))
    monthly_hours = meta.get("monthly_hours")
    if monthly_hours is not None:
        require(number(monthly_hours, "monthly_hours") > 0, "monthly_hours must be positive")
        text(meta.get("monthly_assumption"), "monthly_assumption required for monthly scenario")
    duration = end - start
    hours = (Decimal(duration.days * 86400 + duration.seconds) +
             Decimal(duration.microseconds) / Decimal(1000000)) / Decimal(3600)
    require(isinstance(meta.get("currency"), str) and
            re.fullmatch("[A-Z]{3}", meta["currency"]), "currency must be a three-letter code")
    evidence(inventory, meta, "inventory")
    text(inventory.get("basis"), "inventory.basis")
    require(inventory["basis"] in ("planned", "inventoried"), "basis must be planned or inventoried")
    text(inventory.get("assumptions"), "assumptions")
    exclusions = inventory.get("exclusions")
    require(isinstance(exclusions, list), "exclusions must be a list (explicit scope gaps)")
    for item in exclusions:
        text(item, "exclusion")
    evidence(pricing, meta, "pricing")
    require(isinstance(pricing.get("rates"), list), "pricing.rates must be a list")
    rates = {}
    for row in pricing["rates"]:
        require(isinstance(row, dict), "rate must be an object")
        key = selector(row)
        require(key not in rates, f"duplicate/ambiguous price: {key}")
        require(row.get("currency") == meta["currency"], "pricing currency mismatch")
        text(row.get("source"), "rate.source")
        require(stamp(row.get("as_of")) <= stamp(pricing["as_of"]), "rate as_of after pricing snapshot")
        valid_start, valid_end = period(row.get("valid_period"))
        require(valid_start <= start and end <= valid_end, "rate validity must cover entire estimate period")
        number(row.get("rate"), "rate")
        rates[key] = row
    resources = inventory.get("resources")
    require(isinstance(resources, list) and resources, "resources must be a nonempty list")
    seen, rows, warnings = set(), [], [
        "Estimates use pinned exported prices, not live rates or a bill; inventory completeness is operator-declared."]
    for item in resources:
        require(isinstance(item, dict), "resource must be an object")
        require(set(item) - {"specs"} == {"resource_id", "meter", "region", "workflow", "source", "service",
                                         "sku", "unit", "terms", "quantity"},
                "resource fields must match v1 contract exactly; quantity unknown must be explicit null")
        key = (text(item.get("resource_id"), "resource_id"), text(item.get("meter"), "meter"))
        require(key not in seen, f"duplicate resource/meter (including shared resources): {key}")
        seen.add(key)
        text(item.get("workflow"), "workflow")
        text(item.get("source"), "resource.source")
        price_key = selector(item)
        price = rates.get(price_key) if not any(value in ("unknown", "unavailable") for value in price_key) else None
        quantity = item.get("quantity")
        if quantity is not None:
            number(quantity, "quantity")
        amount = None
        reason = None
        if quantity is None:
            reason = "unknown usage quantity"
        elif price is None:
            reason = "no matching evidenced provider price"
        else:
            amount = money(number(quantity, "quantity") * number(price["rate"], "rate"))
        if reason:
            warnings.append(f"{key[0]} / {key[1]}: {reason}")
        monthly_amount = None
        if amount is not None and monthly_hours is not None:
            monthly_amount = money(number(quantity, "quantity") * number(price["rate"], "rate") *
                                   number(monthly_hours, "monthly_hours") / hours)
        rows.append({**item, "specs": specs(item.get("specs", {})), "amount": amount,
                     "monthly_amount": monthly_amount, "price": price, "unpriced_reason": reason})
    priced = [r for r in rows if r["amount"] is not None]
    subtotal = money(sum((Decimal(r["amount"]) for r in priced), Decimal(0))) if priced else None
    complete = len(priced) == len(rows) and not exclusions
    estimates = {"status": "complete" if complete else "incomplete",
                 "priced_subtotal": subtotal, "total": subtotal if complete else None,
                 "currency": meta["currency"], "period": meta["period"],
                 "basis": inventory["basis"], "period_hours": str(hours), "assumptions": inventory["assumptions"]}
    monthly_subtotal = (money(sum((Decimal(row["monthly_amount"]) for row in priced), Decimal(0)))
                        if priced and monthly_hours is not None else None)
    estimates["monthly_scenario"] = {
        "hours": monthly_hours, "assumption": meta.get("monthly_assumption"),
        "priced_subtotal": monthly_subtotal, "total": monthly_subtotal if complete else None,
        "meaning": "Uniform usage projection to explicit hours, not a calendar-month bill or report-period total."}
    actuals = {"status": "unavailable", "reason": "No offline billing export supplied; cloud access not attempted.",
               "total": None, "priced_subtotal": None, "lines": [], "currency": meta["currency"],
               "period": meta["period"]}
    if billing is not None:
        actuals = billed(billing, meta)
        if actuals["status"] == "incomplete":
            warnings.append(f'Billing export incomplete: {actuals["coverage_note"]}; '
                            f'credits policy: {actuals["credits_policy"]}')
    else:
        warnings.append(actuals["reason"])
    warnings.extend(f"Excluded: {item}" for item in exclusions)
    return {"schema_version": 1, "metadata": meta,
            "evidence": {"inventory": {k: inventory[k] for k in ("source", "as_of", "basis")},
                         "pricing": {k: pricing[k] for k in ("source", "as_of")}},
            "resources": rows, "groups": groups(rows), "estimates": estimates, "actuals": actuals,
            "coverage": {"resource_meters": len(rows), "priced": len(priced),
                         "physical_resources": len({row["resource_id"] for row in rows}),
                         "compute_nodes": len({row["resource_id"] for row in rows if row["meter"] == "compute"}),
                         "unpriced": len(rows) - len(priced),
                         "priced_percent": str(Decimal(len(priced) * 100) / Decimal(len(rows))),
                         "exclusions": exclusions, "complete": complete,
                         "meaning": "Count coverage only; not spend coverage or proof inventory is exhaustive."},
            "warnings": warnings}


def billed(doc, meta):
    with localcontext() as ctx:
        ctx.prec = 80
        return _billed(doc, meta)


def _billed(doc, meta):
    evidence(doc, meta, "billing")
    require(doc.get("currency") == meta["currency"], "billing currency mismatch")
    require(doc.get("period") == meta["period"], "billing/report period mismatch")
    require(type(doc.get("complete")) is bool, "billing.complete must be boolean")
    require(doc.get("metric") in ("unblended_cost", "net_unblended_cost", "actual_cost"),
            "billing metric must be unblended_cost/net_unblended_cost/actual_cost (not amortized/forecast)")
    require((meta["scope"]["provider"] == "azure" and doc["metric"] == "actual_cost") or
            (meta["scope"]["provider"] == "aws" and doc["metric"] in ("unblended_cost", "net_unblended_cost")),
            "billing metric does not match provider")
    text(doc.get("credits_policy"), "credits_policy")
    require(doc["credits_policy"] in ("separate_lines", "included_in_amounts", "excluded_or_unknown"),
            "credits_policy must be separate_lines/included_in_amounts/excluded_or_unknown")
    require(doc["credits_policy"] != "excluded_or_unknown" or not doc["complete"],
            "unknown/excluded credits cannot be a complete bill")
    text(doc.get("coverage_note"), "billing.coverage_note")
    require(isinstance(doc.get("lines"), list), "billing.lines must be a list")
    begin, finish = period(meta["period"])
    charges, ids, windows, lines = {}, set(), {}, []
    for row in doc["lines"]:
        require(isinstance(row, dict), "billing line must be an object")
        fields = {"line_id", "resource_id", "meter", "region", "period", "amount", "kind"}
        require(set(row) == fields | ({"charge_id"} if row.get("kind") == "credit" else set()),
                "billing line fields must match v1 contract exactly")
        line_id = text(row.get("line_id"), "line_id")
        require(line_id not in ids, f"duplicate billing line_id: {line_id}")
        ids.add(line_id)
        resource = text(row.get("resource_id"), "billing.resource_id")
        meter = text(row.get("meter"), "billing.meter")
        text(row.get("region"), "billing.region")
        left, right = period(row.get("period"))
        require(begin <= left < right <= finish, "billing line outside report period")
        require(right <= stamp(doc["as_of"]), "billing line ends after evidence as_of")
        amount = number(row.get("amount"), "billing.amount", negative=True)
        require(row.get("kind") in ("charge", "credit"), "billing kind must be charge or credit")
        require((row["kind"] == "credit" and amount <= 0) or
                (row["kind"] == "charge" and amount >= 0), "billing charge/credit sign mismatch")
        if row["kind"] == "charge":
            key = resource, meter
            for old_left, old_right in windows.get(key, []):
                require(not (left < old_right and old_left < right),
                        f"overlapping billing charge windows: {key}")
            windows.setdefault(key, []).append((left, right))
            charges[line_id] = row
        else:
            require(doc["credits_policy"] == "separate_lines",
                    "credit lines would double-count credits already included or excluded")
            text(row.get("charge_id"), "credit.charge_id")
        lines.append({**row, "amount": money(amount)})
    for row in lines:
        if row["kind"] == "credit":
            charge = charges.get(row["charge_id"])
            require(charge is not None, "credit must reference an included charge")
            require(all(row[k] == charge[k] for k in ("resource_id", "meter", "region", "period")),
                    "credit scope/period must match referenced charge")
    subtotal = (money(sum((Decimal(r["amount"]) for r in lines), Decimal(0)))
                if lines or doc["complete"] else None)
    age = stamp(meta["generated_at"]) - stamp(doc["as_of"])
    return {**{k: doc[k] for k in ("source", "as_of", "scope", "metric", "credits_policy",
                                   "coverage_note", "currency", "period", "complete")},
            "freshness_age_hours": str((Decimal(age.days * 86400 + age.seconds)
                                       + Decimal(age.microseconds) / Decimal(1000000)) / Decimal(3600)),
            "status": "available" if doc["complete"] else "incomplete",
            "lines": lines, "priced_subtotal": subtotal,
            "total": subtotal if doc["complete"] else None, "reason": None}


def flat_rows(report):
    """One shared ledger powers CSV and tabular TXT, including summary rows."""
    meta = report["metadata"]
    common = {"provider": meta["scope"]["provider"], "account": meta["scope"]["account"],
              "currency": meta["currency"], "start": meta["period"]["start"],
              "end": meta["period"]["end"], "period_hours": report["estimates"]["period_hours"],
              "monthly_hours": meta.get("monthly_hours")}
    result = []
    for row in report["resources"]:
        price = row["price"] or {}
        result.append({**common, "section": "ESTIMATE", "resource_id": row["resource_id"],
                       **{key: row["specs"][key] for key in SPEC_FIELDS if key != "source"},
                       "specs_source": row["specs"]["source"], "monthly_amount": row["monthly_amount"],
                       "meter": row["meter"], "region": row["region"], "sku": row["sku"],
                       "service": row["service"], "terms": row["terms"],
                       "inventory_source": row["source"],
                       "unit": row["unit"], "quantity": row["quantity"], "rate": price.get("rate"),
                       "amount": row["amount"], "source": price.get("source"),
                       "as_of": price.get("as_of"), "note": row["unpriced_reason"]})
    for group in report["groups"]:
        result.append({**common, "section": "ESTIMATE_GROUP", "group_id": group["group_id"],
                       **{key: group[key] for key in ("region", "sku", "unit", "meter", "resource_count",
                                                     "node_count", "group_vcpu", "group_memory_gib", "service", "terms")},
                       **group["specs"], "quantity": group["usage_quantity"], "rate": group["unit_price"],
                       "amount": group["priced_subtotal"], "monthly_amount": group["monthly_priced_subtotal"],
                       "group_total": group["total"], "group_monthly_total": group["monthly_total"],
                       "note": "Rollup only; do not add to resource rows. Null group total if incomplete: "
                               + str(group["total"])})
    for row in report["actuals"]["lines"]:
        result.append({**common, "section": "BILLED", "resource_id": row["resource_id"],
                       "meter": row["meter"], "region": row["region"], "amount": row["amount"],
                       "start": row["period"]["start"], "end": row["period"]["end"],
                       "source": report["actuals"]["source"], "as_of": report["actuals"]["as_of"],
                       "note": f'{row["kind"]}: {row["line_id"]}'})
    for section, key in (("ESTIMATE", "estimates"), ("BILLED", "actuals")):
        for field in ("priced_subtotal", "total"):
            result.append({**common, "section": f"{section}_{field.upper()}",
                           "amount": report[key][field], "note": report[key]["status"]})
    for field in ("priced_subtotal", "total"):
        result.append({**common, "section": f"MONTHLY_SCENARIO_{field.upper()}",
                       "monthly_amount": report["estimates"]["monthly_scenario"][field],
                       "note": json.dumps(report["estimates"]["monthly_scenario"], sort_keys=True)})
    for warning in report["warnings"]:
        result.append({**common, "section": "WARNING", "note": warning})
    return result


COLUMNS = ("section", "provider", "account", "resource_id", "group_id", "meter", "region", "role",
           "service", "sku", "terms", "resource_count", "node_count", "vcpu", "memory_gib", "group_vcpu", "group_memory_gib", "disk_type", "disk_gb",
           "iops", "throughput_mbps", "unit", "quantity", "rate", "amount", "monthly_amount", "group_total", "group_monthly_total",
           "currency", "period_hours", "monthly_hours", "start", "end", "source", "as_of", "inventory_source", "specs_source", "note")


def render(report):
    rows = flat_rows(report)
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=COLUMNS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    txt = ["COST REPORT v1 - ESTIMATES and BILLED actuals are separate; never add them.",
           json.dumps({"metadata": report["metadata"], "evidence": report["evidence"],
                       "estimates": report["estimates"],
                       "actuals": {k: v for k, v in report["actuals"].items() if k != "lines"},
                       "coverage": report["coverage"]}, indent=2, sort_keys=True)]

    def table(title, selected, columns):
        txt.extend(["", title])
        if not selected:
            txt.append("(no rows)")
            return
        values = [[str(row.get(key)) if row.get(key) is not None else "null" for key in columns]
                  for row in selected]
        widths = [max(len(key), *(len(row[i]) for row in values)) for i, key in enumerate(columns)]
        txt.append(" | ".join(key.ljust(widths[i]) for i, key in enumerate(columns)))
        txt.extend(" | ".join(value.ljust(widths[i]) for i, value in enumerate(row)) for row in values)

    estimates = [row for row in rows if row["section"] == "ESTIMATE"]
    table("ESTIMATE - individual infrastructure meters (monthly is a separate scenario)", estimates,
          ("resource_id", "meter", "role", "sku", "quantity", "unit", "rate", "amount", "monthly_amount"))
    table("INFRASTRUCTURE SPECS - null means not evidenced, never inferred from SKU", estimates,
          ("resource_id", "meter", "vcpu", "memory_gib", "disk_type", "disk_gb", "iops", "throughput_mbps"))
    table("ESTIMATE_GROUP - rollups only; never add to individual meters",
          [row for row in rows if row["section"] == "ESTIMATE_GROUP"],
          ("group_id", "role", "sku", "resource_count", "node_count", "group_vcpu", "group_memory_gib",
          "quantity", "unit", "rate", "amount", "group_total", "monthly_amount", "group_monthly_total"))
    table("PROVIDER PRICE EVIDENCE", estimates,
          ("resource_id", "meter", "region", "service", "sku", "terms", "source", "as_of"))
    table("INVENTORY / SPEC EVIDENCE", estimates,
          ("resource_id", "meter", "inventory_source", "specs_source"))
    table("BILLED - independent provider actuals, credits included once",
          [row for row in rows if row["section"] == "BILLED"],
          ("resource_id", "meter", "amount", "currency", "start", "end", "note"))
    table("SUMMARY - do not add different sections or periods",
          [row for row in rows if row["section"] not in ("ESTIMATE", "ESTIMATE_GROUP", "BILLED", "WARNING")],
          ("section", "amount", "monthly_amount", "currency"))
    txt.extend(["", "WARNINGS", *report["warnings"]])
    return {"report.json": json.dumps(report, indent=2, sort_keys=True) + "\n",
            "report.csv": stream.getvalue(), "report.txt": "\n".join(txt) + "\n"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True)
    parser.add_argument("--pricing", required=True)
    parser.add_argument("--billing")
    parser.add_argument("--output", required=True, help="New private output directory; never overwrite")
    args = parser.parse_args(argv)
    try:
        inventory, pricing = load(args.inventory), load(args.pricing)
        billing = load(args.billing) if args.billing else None
        report = build(inventory, pricing, billing)
        report["metadata"] = {**report["metadata"], "input_sha256": {
            name: hashlib.sha256(Path(path).read_bytes()).hexdigest()
            for name, path in (("inventory", args.inventory), ("pricing", args.pricing),
                               ("billing", args.billing)) if path}}
        outputs = render(report)
        target = Path(args.output)
        target.mkdir(mode=0o700, parents=False, exist_ok=False)
        for name, content in outputs.items():
            with (target / name).open("x", encoding="utf-8", newline="") as stream:
                stream.write(content)
            (target / name).chmod(0o600)
    except (InputError, OSError, ValueError, TypeError, KeyError) as exc:
        print(f"cost-report: ERROR: {exc}", file=sys.stderr)
        return 2
    print(f"Cost report written: {target} (estimates {report['estimates']['status']}; "
          f"actuals {report['actuals']['status']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
