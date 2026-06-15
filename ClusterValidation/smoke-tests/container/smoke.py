#!/usr/bin/env python3
"""Cloudera CDP smoke-test driver.

Consumes a *handoff* JSON document produced by the ephemeral-ec2-launcher
(see the launcher project) which describes a running EC2 runner inside the
cluster VPC. This module:

  1. Ships ``remote_probe.py`` and a JSON env blob to the runner via SSM.
  2. Runs the probe and parses the framed JSON result from its stdout.
  3. Writes Nagios + Prometheus + JSON + HTML reports.
  4. Tears down the runner's AWS resources — always, even on failure.
  5. Prints the Nagios one-liner to stdout and exits with a Nagios code.

The handoff is the sole input channel from upstream; the Cloudera Manager
credentials and the cluster name are read from this module's own env.

Exit code: Nagios convention — 0=OK, 1=WARN, 2=CRIT, 3=UNKNOWN.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import gzip
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional

import boto3
from botocore.exceptions import (
    ClientError,
    NoCredentialsError,
    TokenRetrievalError,
)

import report

NAGIOS_OK = 0
NAGIOS_WARN = 1
NAGIOS_CRIT = 2
NAGIOS_UNKNOWN = 3

HANDOFF_VERSION_SUPPORTED = 1
SSM_MANAGED_POLICY = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
PROBE_GZ_START = "---PROBE-JSON-GZ-START---"
PROBE_GZ_END = "---PROBE-JSON-GZ-END---"
PROBE_TIMEOUT_S = 1800
USERDATA_WAIT_LOOPS = 40

# Read-only mount path for the optional cluster SSH key (set by run.sh).
SSH_KEY_MOUNT = Path("/run/ssh_key")


def log(msg: str) -> None:
    """Write a timestamped log line to stderr."""
    ts = dt.datetime.now(dt.UTC).strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", file=sys.stderr, flush=True)


def load_ssh_key() -> Optional[bytes]:
    """Return the cluster SSH private key bytes, or None if not mounted."""
    if not SSH_KEY_MOUNT.is_file() or not os.access(SSH_KEY_MOUNT, os.R_OK):
        return None
    return SSH_KEY_MOUNT.read_bytes()


def require_env(name: str) -> str:
    """Return ``os.environ[name]`` or exit UNKNOWN with a clear message."""
    val = os.environ.get(name)
    if not val:
        print(
            f"UNKNOWN - required env var {name} is not set",
            file=sys.stderr,
        )
        sys.exit(NAGIOS_UNKNOWN)
    return val


def load_cm_pass() -> str:
    """Return the CM password from env or the mounted file, else exit."""
    val = os.environ.get("CM_PASS")
    if val:
        return val
    mount = Path("/run/cm_pass")
    if mount.is_file() and os.access(mount, os.R_OK):
        return mount.read_text().rstrip("\n")
    print(
        "UNKNOWN - CM_PASS not provided (set env var or mount a readable "
        "/run/cm_pass)",
        file=sys.stderr,
    )
    sys.exit(NAGIOS_UNKNOWN)


def parse_args() -> argparse.Namespace:
    """Parse command-line flags.

    Returns:
        Namespace with ``handoff`` — a path to the handoff JSON, or ``-``
        meaning stdin.
    """
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--handoff",
        default="-",
        help=(
            "Path to the launcher handoff JSON, or '-' to read from stdin "
            "(default: stdin)."
        ),
    )
    return p.parse_args()


def read_handoff(path: str) -> Dict[str, Any]:
    """Read and validate the handoff document."""
    if path == "-":
        raw = sys.stdin.read()
    else:
        raw = Path(path).read_text()
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"UNKNOWN - handoff is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(NAGIOS_UNKNOWN)
    if doc.get("kind") != "ephemeral-ec2-runner":
        print(
            f"UNKNOWN - unexpected handoff kind: {doc.get('kind')!r}",
            file=sys.stderr,
        )
        sys.exit(NAGIOS_UNKNOWN)
    if doc.get("handoff_version") != HANDOFF_VERSION_SUPPORTED:
        print(
            "UNKNOWN - handoff_version "
            f"{doc.get('handoff_version')!r} not supported "
            f"(expected {HANDOFF_VERSION_SUPPORTED})",
            file=sys.stderr,
        )
        sys.exit(NAGIOS_UNKNOWN)
    return doc


class SmokeDriver:
    """Runs the probe and owns teardown of the upstream-created runner."""

    def __init__(self, handoff: Dict[str, Any]) -> None:
        self.handoff = handoff
        self.env_name = handoff.get("env_name", "unknown")
        self.ts = handoff.get(
            "ts", dt.datetime.now(dt.UTC).strftime("%Y%m%d-%H%M%S")
        )
        self.region = handoff["aws"]["region"]
        self.account = handoff["aws"]["account"]
        self.instance_id = handoff["instance"]["id"]
        self.iam_role = handoff["iam"]["role"]
        self.iam_profile = handoff["iam"]["instance_profile"]
        self.sg_id = handoff["security_groups"]["ephemeral"]

        self.cm_host = require_env("CM_HOST")
        self.cm_port = int(os.environ.get("CM_PORT", "7183"))
        self.cm_user = os.environ.get("CM_USER", "admin")
        self.cm_pass = load_cm_pass()
        self.cluster_name = require_env("CLUSTER_NAME")
        self.services_to_test = os.environ.get("SERVICES_TO_TEST", "all")
        self.data_services_cluster = os.environ.get("DATA_SERVICES_CLUSTER", "")
        self.output_dir = Path(os.environ.get("OUTPUT_DIR", "/output"))
        formats = os.environ.get("OUTPUT_FORMATS", "nagios,prom,json,html")
        self.output_formats = {
            f.strip() for f in formats.split(",") if f.strip()
        }
        self._aws_init()

    def _aws_init(self) -> None:
        try:
            session = boto3.Session(region_name=self.region)
            self.ec2 = session.client("ec2")
            self.iam = session.client("iam")
            self.ssm = session.client("ssm")
            self.sts = session.client("sts")
            self.sts.get_caller_identity()
        except (NoCredentialsError, TokenRetrievalError) as exc:
            print(
                f"UNKNOWN - AWS credentials unavailable: {exc}\n"
                "Run 'aws sso login --profile <profile>' on the host, "
                "then re-run.",
                file=sys.stderr,
            )
            sys.exit(NAGIOS_UNKNOWN)

    # ------------------------------------------------------------------
    # Probe execution
    # ------------------------------------------------------------------
    def run_probe(self) -> Dict[str, Any]:
        """Ship the probe to the runner via SSM, collect and parse results."""
        log("=== Remote probe via SSM ===")
        probe_b64 = base64.b64encode(
            Path("/app/remote_probe.py").read_bytes()
        ).decode()

        probe_env = {
            "CM_HOST": self.cm_host,
            "CM_PORT": str(self.cm_port),
            "CM_USER": self.cm_user,
            "CM_PASS": self.cm_pass,
            "CLUSTER_NAME": self.cluster_name,
            "SERVICES_TO_TEST": self.services_to_test,
            "SSH_USER": os.environ.get("SSH_USER", "ec2-user"),
            "DATA_SERVICES_CLUSTER": self.data_services_cluster,
        }
        _ds_candidates = (
           [c.strip() for c in self.data_services_cluster.split(",") if c.strip()]
           if self.data_services_cluster
            else ["ECSCluster1", "default-ecs"]
        )
        log(
            f"data_services_cluster: env='{self.data_services_cluster or '(not set)'}' "
            f"→ candidates={_ds_candidates}"
        )
        ssh_key = load_ssh_key()
        if ssh_key:
            probe_env["SSH_KEY"] = base64.b64encode(ssh_key).decode()
            log(f"ssh: forwarded cluster SSH key ({len(ssh_key)} bytes) "
                f"as {probe_env['SSH_USER']}")
        else:
            log("ssh: no /run/ssh_key mounted; df -hT section will be SKIP")
        env_b64 = base64.b64encode(
            json.dumps(probe_env).encode()
        ).decode()

        cmd = (
            "set -e; "
            f"echo {probe_b64} | base64 -d > /tmp/probe.py; "
            f"echo {env_b64}   | base64 -d > /tmp/probe_env.json; "
            "for i in $(seq 1 "
            f"{USERDATA_WAIT_LOOPS}"
            "); do [ -f /tmp/userdata.done ] && break; sleep 5; done; "
            "python3 /tmp/probe.py < /tmp/probe_env.json"
        )

        resp = self.ssm.send_command(
            InstanceIds=[self.instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": [cmd]},
            TimeoutSeconds=PROBE_TIMEOUT_S,
            Comment=f"smoke-probe {self.ts}",
        )
        cid = resp["Command"]["CommandId"]
        log(f"command {cid} sent; polling every 10s (heartbeat every 60s)")

        deadline = time.time() + PROBE_TIMEOUT_S
        inv: Dict[str, Any] = {}
        last_status: Optional[str] = None
        started = time.time()
        poll = 0
        while time.time() < deadline:
            time.sleep(10)
            poll += 1
            try:
                inv = self.ssm.get_command_invocation(
                    CommandId=cid, InstanceId=self.instance_id
                )
            except ClientError:
                continue
            status = inv.get("Status", "Unknown")
            if status != last_status:
                log(f"probe status: {status}")
                last_status = status
            elif poll % 6 == 0:
                elapsed = int(time.time() - started)
                log(f"probe still {status} (t+{elapsed}s)")
            if status not in ("Pending", "InProgress", "Delayed"):
                break

        out = inv.get("StandardOutputContent", "")
        err = inv.get("StandardErrorContent", "")
        if inv.get("Status") != "Success":
            log(f"probe status={inv.get('Status')}")
            if err:
                log(f"stderr tail: {err[-500:]}")

        start = out.find(PROBE_GZ_START)
        end = out.find(PROBE_GZ_END)
        if start < 0 or end < 0:
            raise SystemExit(
                "CRITICAL - probe did not emit result JSON "
                f"(markers not found; SSM truncates stdout at ~24,000 chars, "
                f"got {len(out)}). stdout tail:\n{out[-1000:]}"
            )
        # Strip whitespace/newlines that the 76-col wrap (or SSM transport)
        # introduced inside the payload before base64-decoding.
        b64 = re.sub(r"\s+", "", out[start + len(PROBE_GZ_START) : end])
        try:
            payload = gzip.decompress(base64.b64decode(b64))
            result = json.loads(payload)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            raise SystemExit(
                "CRITICAL - probe emitted markers but payload could not be "
                f"decoded ({exc}). b64 length={len(b64)}; stdout tail:\n"
                f"{out[-1000:]}"
            )
        result["ssm_command_id"] = cid
        result["ssm_status"] = inv.get("Status")
        return result

    # ------------------------------------------------------------------
    # Teardown
    # ------------------------------------------------------------------
    def teardown(self) -> None:
        """Destroy every resource listed in the handoff. Always safe to call."""
        log("=== Teardown ===")
        if self.instance_id:
            try:
                self.ec2.terminate_instances(InstanceIds=[self.instance_id])
                self.ec2.get_waiter("instance_terminated").wait(
                    InstanceIds=[self.instance_id]
                )
                log(f"terminated {self.instance_id}")
            except ClientError as exc:
                log(f"terminate err: {exc}")
        if self.iam_profile:
            try:
                self.iam.remove_role_from_instance_profile(
                    InstanceProfileName=self.iam_profile,
                    RoleName=self.iam_role,
                )
            except ClientError:
                pass
            try:
                self.iam.delete_instance_profile(
                    InstanceProfileName=self.iam_profile
                )
                log(f"deleted instance profile {self.iam_profile}")
            except ClientError as exc:
                log(f"profile del err: {exc}")
        if self.iam_role:
            try:
                self.iam.detach_role_policy(
                    RoleName=self.iam_role, PolicyArn=SSM_MANAGED_POLICY
                )
            except ClientError:
                pass
            try:
                self.iam.delete_role(RoleName=self.iam_role)
                log(f"deleted role {self.iam_role}")
            except ClientError as exc:
                log(f"role del err: {exc}")
        if self.sg_id:
            # ENI detachment is eventually consistent — retry up to 5x.
            for attempt in range(5):
                try:
                    self.ec2.delete_security_group(GroupId=self.sg_id)
                    log(f"deleted sg {self.sg_id}")
                    break
                except ClientError as exc:
                    log(f"sg del retry {attempt + 1}: {exc}")
                    time.sleep(15)

    # ------------------------------------------------------------------
    # Report writing
    # ------------------------------------------------------------------
    def write_reports(self, result: Dict[str, Any]) -> tuple[int, str]:
        """Write configured report formats; return Nagios (code, line)."""
        result["run"] = {
            "ts": self.ts,
            "env": self.env_name,
            "cluster": self.cluster_name,
            "aws_region": self.region,
            "aws_account": self.account,
            "cm_host": self.cm_host,
            "cm_port": self.cm_port,
        }

        self.output_dir.mkdir(parents=True, exist_ok=True)
        base = self.output_dir / f"smoke-{self.env_name}-{self.ts}"
        nagios_code, nagios_line = report.nagios(result)

        if "json" in self.output_formats:
            base.with_suffix(".json").write_text(
                json.dumps(result, indent=2)
            )
            log(f"wrote {base}.json")
        if "prom" in self.output_formats:
            base.with_suffix(".prom").write_text(report.prometheus(result))
            log(f"wrote {base}.prom")
        if "html" in self.output_formats:
            base.with_suffix(".html").write_text(report.html_report(result))
            log(f"wrote {base}.html")
        if "nagios" in self.output_formats:
            base.with_suffix(".nagios").write_text(nagios_line + "\n")
            log(f"wrote {base}.nagios")

        return nagios_code, nagios_line


def main() -> int:
    args = parse_args()
    handoff = read_handoff(args.handoff)
    driver = SmokeDriver(handoff)

    try:
        result = driver.run_probe()
    except SystemExit:
        driver.teardown()
        raise
    except Exception as exc:  # noqa: BLE001 — last-chance teardown
        log(f"ERROR: {exc}")
        driver.teardown()
        print(f"UNKNOWN - driver exception: {exc}")
        return NAGIOS_UNKNOWN

    try:
        code, line = driver.write_reports(result)
    finally:
        driver.teardown()

    print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
