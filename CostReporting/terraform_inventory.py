#!/usr/bin/env python3
"""Convert an already exported Terraform show JSON snapshot; never invokes Terraform."""
import argparse
from decimal import Decimal, ROUND_HALF_EVEN, localcontext
import json
from pathlib import Path
import sys

from report import InputError, load, number, period, require, scope_check, specs, stamp, text


NON_CHARGED = {
    "aws_vpc", "aws_subnet", "aws_security_group", "aws_security_group_rule",
    "aws_route_table", "aws_route_table_association", "aws_route", "aws_internet_gateway",
    "aws_key_pair", "aws_eip_association", "aws_iam_role", "aws_iam_policy",
    "aws_iam_role_policy", "aws_iam_role_policy_attachment", "aws_iam_instance_profile",
    "aws_s3_bucket_versioning", "azurerm_resource_group", "azurerm_subnet",
    "azurerm_virtual_network", "azurerm_network_interface", "azurerm_network_security_group",
    "azurerm_network_interface_security_group_association", "azurerm_user_assigned_identity",
    "azurerm_role_assignment", "tls_private_key", "local_file", "local_sensitive_file",
}
WORKFLOWS = ("OnCloud/AWS", "OnCloud/Azure", "PvC-InfraDeployer", "Utilities", "ClusterValidation")


def modules(module):
    require(isinstance(module, dict), "Terraform module must be an object")
    resources = module.get("resources", [])
    require(isinstance(resources, list), "Terraform resources must be a list")
    yield from resources
    for child in module.get("child_modules", []):
        yield from modules(child)


def single_block(value, name):
    value = [] if value is None else value
    require(isinstance(value, list) and len(value) <= 1 and all(isinstance(v, dict) for v in value),
            f"Terraform {name} must be a zero/one-element block list")
    return value[0] if value else {}


def convert(snapshot, context, workflow):
    with localcontext() as ctx:
        ctx.prec = 80
        return _convert(snapshot, context, workflow)


def _convert(snapshot, context, workflow):
    require(workflow in WORKFLOWS, "unsupported workflow")
    require(isinstance(snapshot, dict), "Terraform export must be an object")
    require(snapshot.get("format_version") in ("1.0", "1.1", "1.2"),
            "unsupported Terraform JSON format_version")
    meta = context["metadata"]
    scope_check(meta["scope"])
    start, end = period(meta["period"])
    require(stamp(context["as_of"]) <= stamp(meta["generated_at"]), "future inventory snapshot")
    hours = Decimal((end - start).days * 86400 + (end - start).seconds) / Decimal(3600)
    require(start.microsecond == end.microsecond == 0, "Terraform period requires whole seconds")
    month_hours = number(context["month_hours"], "month_hours")
    require(month_hours > 0, "month_hours must be positive")
    basis = context["basis"]
    require(basis in ("planned", "inventoried"), "basis must be planned or inventoried")
    root = snapshot.get("planned_values" if basis == "planned" else "values", {}).get("root_module")
    require(root is not None, "missing Terraform values/root_module for selected basis")
    text(context["source"], "source")
    require(isinstance(context["exclusions"], list), "context.exclusions must be a list")
    terms = context["terms"]
    require(isinstance(terms, dict), "terms must map address/meter to evidenced pricing terms")
    spec_bindings = context.get("specs", {})
    require(isinstance(spec_bindings, dict), "specs must map address/meter to sourced specifications")
    rows, seen, used_terms, used_specs = [], set(), set(), set()
    provider = meta["scope"]["provider"]

    def append(address, rid, meter, service, sku, unit, quantity, details=None):
        binding = f"{address}/{meter}"
        term = terms.get(binding)
        if term is None:
            term = "unknown"
        else:
            text(term, f"terms.{binding}")
            used_terms.add(binding)
        if quantity is not None:
            quantity = quantity.quantize(Decimal("0.000000000001"), rounding=ROUND_HALF_EVEN)
        details = {key: value for key, value in (details or {}).items() if value is not None}
        provided = spec_bindings.get(binding, {})
        require(isinstance(provided, dict), "spec binding must be an object")
        if binding in spec_bindings:
            used_specs.add(binding)
        for key, value in provided.items():
            require(key not in details or value == details[key], f"spec conflicts with Terraform evidence: {binding}/{key}")
        properties = specs({**details, **provided, "source": provided.get("source",
                            f'{context["source"]}#{address}')})
        rows.append({"resource_id": rid, "meter": meter, "region": context["region"],
                     "workflow": workflow, "service": service, "sku": sku or "unknown",
                     "unit": unit, "quantity": str(quantity) if quantity is not None else None,
                     "terms": term, "source": f'{context["source"]}#{address}', "specs": properties})

    def capacity(value):
        if value is None:
            return None
        return number(str(value), "Terraform capacity") * hours / month_hours

    def disk_specs(disk):
        return {"disk_type": disk.get("volume_type") or disk.get("type"),
                **{target: str(disk[source]) if disk.get(source) is not None else None
                   for target, source in (("disk_gb", "volume_size"), ("iops", "iops"),
                                          ("throughput_mbps", "throughput"))}}

    for resource in modules(root):
        require(isinstance(resource, dict), "Terraform resource must be an object")
        if resource.get("mode") == "data":
            continue
        address = text(resource.get("address"), "Terraform address")
        require(address not in seen, f"duplicate Terraform address: {address}")
        seen.add(address)
        kind = text(resource.get("type"), "Terraform type")
        values = resource.get("values") or {}
        require(isinstance(values, dict), "Terraform resource values must be an object")
        if kind.startswith("aws_"):
            require(provider == "aws", "AWS resource in non-AWS scope")
        elif kind.startswith("azurerm_"):
            require(provider == "azure", "Azure resource in non-Azure scope")
        if kind in NON_CHARGED:
            continue
        zone = values.get("availability_zone")
        if zone:
            require(zone.startswith(context["region"]), "Terraform availability_zone/region mismatch")
        location = values.get("location")
        if location:
            require(location.replace(" ", "").lower() == context["region"].replace(" ", "").lower(),
                    "Terraform Azure location/region mismatch")
        rid = values.get("id") if basis == "inventoried" else f"planned:{address}"
        text(rid, "inventoried resource requires physical id; planned uses address")
        if kind == "aws_instance":
            options = single_block(values.get("cpu_options"), "cpu_options")
            vcpu = (number(str(options["core_count"]), "core_count") *
                    number(str(options["threads_per_core"]), "threads_per_core")
                    if options.get("core_count") is not None and options.get("threads_per_core") is not None else None)
            append(address, rid, "compute", "AmazonEC2", values.get("instance_type"),
                   "hour", hours if values.get("instance_type") else None,
                   {"vcpu": str(vcpu) if vcpu is not None else None})
            disk = single_block(values.get("root_block_device"), "root_block_device")
            volume_id = disk.get("volume_id")
            append(address, volume_id or f"{rid}#root", "storage", "AmazonEBS", disk.get("volume_type"),
                   "GB-month", capacity(disk.get("volume_size"))
                   if basis == "planned" or volume_id else None, disk_specs(disk))
        elif kind == "aws_ebs_volume":
            append(address, rid, "storage", "AmazonEBS", values.get("type"),
                   "GB-month", capacity(values.get("size")),
                   disk_specs({**values, "volume_size": values.get("size")}))
        elif kind == "aws_eip":
            append(address, rid, "public-ip", "AmazonVPC", "public-ipv4", "hour", hours)
        elif kind == "azurerm_linux_virtual_machine":
            append(address, rid, "compute", "Virtual Machines", values.get("size"),
                   "hour", hours if values.get("size") else None)
            # Azure disk tiers are per-disk, not GB-month; size must be mapped to a tier.
            disk = single_block(values.get("os_disk"), "os_disk")
            append(address, rid + "#os-disk", "os-disk", "Managed Disks", None, "unknown", None,
                   {"disk_type": disk.get("storage_account_type"),
                    "disk_gb": str(disk["disk_size_gb"]) if disk.get("disk_size_gb") is not None else None})
        else:
            append(address, rid, "unmapped", kind, kind, "unknown", None)
        for disk in values.get("ebs_block_device") or []:
            require(isinstance(disk, dict), "Terraform embedded EBS must be a block object")
            device = text(disk.get("device_name"), "device_name")
            volume_id = disk.get("volume_id")
            append(address, volume_id or f"{rid}#{device}", "storage",
                   "AmazonEBS", disk.get("volume_type"), "GB-month",
                   capacity(disk.get("volume_size")) if basis == "planned" or volume_id else None, disk_specs(disk))
    require(set(terms) == used_terms, f"unused/invalid terms bindings: {sorted(set(terms) - used_terms)}")
    require(set(spec_bindings) == used_specs, "unused infrastructure specs bindings")
    text(context["region"], "region")
    return {"schema_version": 1, "metadata": meta, "scope": meta["scope"],
            "basis": basis, "source": context["source"], "as_of": context["as_of"],
            "assumptions": f'Uniform runtime {hours} hours; GB-month = GB * hours / '
                           f'{month_hours}; usage rounded half-even to 12 fractional digits. '
                           f'{text(context["assumptions"], "assumptions")}',
            "exclusions": context["exclusions"] + [
                "Terraform export is not full provider inventory: managed CDP children, usage, "
                "network traffic/NAT/LB, requests, snapshots, disk IOPS/throughput, tax, "
                "support and software/license fees require separate evidence."],
            "resources": rows}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terraform", required=True, help="Existing show -json export (not a state pull)")
    parser.add_argument("--context", required=True)
    parser.add_argument("--workflow", choices=WORKFLOWS, required=True)
    parser.add_argument("--output", required=True, help="New normalized inventory file")
    args = parser.parse_args(argv)
    try:
        inventory = convert(load(args.terraform), load(args.context), args.workflow)
        with Path(args.output).open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(inventory, indent=2) + "\n")
        Path(args.output).chmod(0o600)
    except (InputError, OSError, ValueError, TypeError, KeyError) as exc:
        print(f"terraform-inventory: ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
