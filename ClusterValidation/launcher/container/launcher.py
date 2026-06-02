#!/usr/bin/env python3
"""Ephemeral EC2 runner launcher.

Reads configuration from the environment, validates the target VPC/subnet,
discovers the Cloudera security group(s) attached to ``CM_HOST``, creates a
one-shot IAM role + instance profile with ``AmazonSSMManagedInstanceCore``,
launches a ``t3.micro`` AL2023 instance, and waits for the SSM agent to come
Online.

On success a single JSON "handoff" document is written to stdout. Log lines go
to stderr. The handoff is the sole contract between the launcher and any
downstream consumer (e.g. smoke-tests); it contains every identifier required
to use the runner and to tear it down later.

On failure the launcher rolls back its own partially-created resources (so no
handoff is emitted) and exits non-zero. Responsibility for tearing down a
*successfully* created runner belongs to the downstream consumer.

Exit codes:
    0 — success, handoff JSON on stdout.
    1 — configuration / pre-flight failure.
    2 — AWS error during launch (rollback attempted).
    3 — credentials unavailable.
"""
from __future__ import annotations

import datetime as dt
import json
import os
import sys
import time
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import (
    ClientError,
    NoCredentialsError,
    TokenRetrievalError,
)

EXIT_OK = 0
EXIT_CONFIG = 1
EXIT_AWS = 2
EXIT_CREDENTIALS = 3

HANDOFF_VERSION = 1
SSM_MANAGED_POLICY = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
INSTANCE_TYPE_DEFAULT = "t3.micro"
SSM_ONLINE_TIMEOUT_S = 480
IAM_PROPAGATION_TIMEOUT_S = 120


def log(msg: str) -> None:
    """Write a timestamped log line to stderr."""
    ts = dt.datetime.now(dt.UTC).strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", file=sys.stderr, flush=True)


def require_env(name: str) -> str:
    """Return ``os.environ[name]`` or exit with a config error."""
    val = os.environ.get(name)
    if not val:
        print(f"ERROR: required env var {name} is not set", file=sys.stderr)
        sys.exit(EXIT_CONFIG)
    return val


class Launcher:
    """Owns the create-side lifecycle of an ephemeral EC2 runner.

    The class tracks every AWS resource it creates in ``self._created`` so the
    ``rollback`` method can undo a partial launch on failure.
    """

    def __init__(self) -> None:
        self.env_name = os.environ.get("ENV_NAME", "unknown")
        self.region = require_env("AWS_REGION")
        self.vpc_id = require_env("VPC_ID")
        self.subnet_id = require_env("SUBNET_ID")
        self.cm_host = require_env("CM_HOST")
        self.instance_type = os.environ.get(
            "INSTANCE_TYPE", INSTANCE_TYPE_DEFAULT
        )

        self.ts = dt.datetime.now(dt.UTC).strftime("%Y%m%d-%H%M%S")
        self.name_prefix = f"smoke-runner-{self.env_name}-{self.ts}"
        self.tags = [
            {"Key": "ManagedBy", "Value": "smoke-runner"},
            {"Key": "Env", "Value": self.env_name},
            {"Key": "Ephemeral", "Value": "true"},
            {"Key": "RunTs", "Value": self.ts},
        ]
        self._created: Dict[str, Optional[str]] = {
            "instance": None,
            "sg": None,
            "role": None,
            "profile": None,
        }
        self._aws_init()

    def _aws_init(self) -> None:
        """Create boto3 clients and validate credentials up front."""
        try:
            session = boto3.Session(region_name=self.region)
            self.ec2 = session.client("ec2")
            self.iam = session.client("iam")
            self.ssm = session.client("ssm")
            self.sts = session.client("sts")
            self.identity = self.sts.get_caller_identity()
        except (NoCredentialsError, TokenRetrievalError) as exc:
            print(
                f"UNKNOWN - AWS credentials unavailable: {exc}\n"
                "Run 'aws sso login --profile <profile>' on the host, "
                "then re-run.",
                file=sys.stderr,
            )
            sys.exit(EXIT_CREDENTIALS)
        log(
            f"Account {self.identity['Account']} — "
            f"{self.identity['Arn'].split('/')[-1]}"
        )

    # ------------------------------------------------------------------
    # Phase 1: pre-flight
    # ------------------------------------------------------------------
    def preflight(self) -> Dict[str, Any]:
        """Validate inputs, select an AMI, discover Cloudera SGs.

        Returns:
            Dict with keys ``vpc``, ``subnet``, ``ami_id``, ``cloudera_sgs``.

        Raises:
            SystemExit: if the subnet is not in the VPC or AWS APIs fail.
        """
        log("=== Phase 1: pre-flight ===")
        vpc = self.ec2.describe_vpcs(VpcIds=[self.vpc_id])["Vpcs"][0]
        subnet = self.ec2.describe_subnets(SubnetIds=[self.subnet_id])[
            "Subnets"
        ][0]
        if subnet["VpcId"] != self.vpc_id:
            raise SystemExit(
                f"CRITICAL - subnet {self.subnet_id} not in VPC "
                f"{self.vpc_id}"
            )

        images = self.ec2.describe_images(
            Owners=["amazon"],
            Filters=[
                {
                    "Name": "name",
                    "Values": ["al2023-ami-2023.*-kernel-*-x86_64"],
                },
                {"Name": "state", "Values": ["available"]},
            ],
        )["Images"]
        if not images:
            raise SystemExit("CRITICAL - no AL2023 AMIs available")
        ami = sorted(images, key=lambda i: i["CreationDate"])[-1]

        log(
            f"VPC {self.vpc_id} CIDR={vpc['CidrBlock']}  "
            f"Subnet={self.subnet_id} AZ={subnet['AvailabilityZone']}"
        )
        log(f"AMI (AL2023) {ami['ImageId']}")

        cloudera_sgs: List[str] = []
        result = self.ec2.describe_instances(
            Filters=[
                {"Name": "vpc-id", "Values": [self.vpc_id]},
                {"Name": "private-ip-address", "Values": [self.cm_host]},
            ],
        )
        for reservation in result["Reservations"]:
            for inst in reservation["Instances"]:
                cloudera_sgs = [g["GroupId"] for g in inst["SecurityGroups"]]
        log(f"Cloudera SGs to attach to runner: {cloudera_sgs}")

        return {
            "vpc": vpc,
            "subnet": subnet,
            "ami_id": ami["ImageId"],
            "cloudera_sgs": cloudera_sgs,
        }

    # ------------------------------------------------------------------
    # Phase 2: create IAM + SG + instance
    # ------------------------------------------------------------------
    def _create_iam(self) -> None:
        """Create the ephemeral role and instance profile."""
        trust = json.dumps(
            {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {"Service": "ec2.amazonaws.com"},
                        "Action": "sts:AssumeRole",
                    }
                ],
            }
        )
        self.iam.create_role(
            RoleName=self.name_prefix,
            AssumeRolePolicyDocument=trust,
            Tags=[{"Key": t["Key"], "Value": t["Value"]} for t in self.tags],
        )
        self._created["role"] = self.name_prefix
        self.iam.attach_role_policy(
            RoleName=self.name_prefix, PolicyArn=SSM_MANAGED_POLICY
        )
        self.iam.create_instance_profile(
            InstanceProfileName=self.name_prefix
        )
        self._created["profile"] = self.name_prefix
        self.iam.add_role_to_instance_profile(
            InstanceProfileName=self.name_prefix, RoleName=self.name_prefix
        )

    def _create_security_group(self) -> str:
        """Create the ephemeral security group and return its id."""
        sg_id = self.ec2.create_security_group(
            GroupName=f"{self.name_prefix}-sg",
            Description="Ephemeral smoke runner SG",
            VpcId=self.vpc_id,
            TagSpecifications=[
                {"ResourceType": "security-group", "Tags": self.tags}
            ],
        )["GroupId"]
        self._created["sg"] = sg_id
        return sg_id

    def _run_instance(self, pf: Dict[str, Any], sg_id: str) -> str:
        """Launch the instance, retrying through IAM propagation delay."""
        user_data = (
            "#!/bin/bash\n"
            "set -e\n"
            "exec > /var/log/user-data.log 2>&1\n"
            "dnf install -y --skip-broken python3 python3-pip "
            "nmap-ncat bind-utils jq\n"
            "pip3 install --quiet requests\n"
            "touch /tmp/userdata.done\n"
        )
        run_args = dict(
            ImageId=pf["ami_id"],
            InstanceType=self.instance_type,
            MinCount=1,
            MaxCount=1,
            SubnetId=self.subnet_id,
            SecurityGroupIds=[sg_id] + pf["cloudera_sgs"],
            IamInstanceProfile={"Name": self.name_prefix},
            UserData=user_data,
            MetadataOptions={
                "HttpTokens": "required",
                "HttpEndpoint": "enabled",
            },
            TagSpecifications=[
                {
                    "ResourceType": "instance",
                    "Tags": self.tags
                    + [{"Key": "Name", "Value": self.name_prefix}],
                }
            ],
        )

        delay = 5
        deadline = time.time() + IAM_PROPAGATION_TIMEOUT_S
        while True:
            try:
                inst = self.ec2.run_instances(**run_args)["Instances"][0]
                break
            except ClientError as exc:
                code = exc.response.get("Error", {}).get("Code", "")
                msg = exc.response.get("Error", {}).get("Message", "")
                transient = (
                    code
                    in (
                        "InvalidParameterValue",
                        "InvalidInstanceProfile.NotFound",
                    )
                    and "IAM Instance Profile" in msg
                )
                if transient and time.time() < deadline:
                    log(
                        "waiting for IAM instance profile propagation "
                        f"({delay}s): {msg}"
                    )
                    time.sleep(delay)
                    delay = min(delay * 2, 20)
                    continue
                raise

        iid = inst["InstanceId"]
        self._created["instance"] = iid
        log(f"launched {iid}, waiting for SSM Online")
        return iid

    def _wait_ssm_online(self, iid: str) -> None:
        """Block until the instance reports SSM ``Online``, else raise."""
        deadline = time.time() + SSM_ONLINE_TIMEOUT_S
        while time.time() < deadline:
            info = self.ssm.describe_instance_information(
                Filters=[{"Key": "InstanceIds", "Values": [iid]}]
            )
            items = info["InstanceInformationList"]
            if items and items[0]["PingStatus"] == "Online":
                log(f"{iid} SSM Online")
                return
            time.sleep(15)
        raise SystemExit(
            f"CRITICAL - {iid} did not become SSM Online in time"
        )

    def launch(self, pf: Dict[str, Any]) -> str:
        """Execute the full create-side lifecycle."""
        log("=== Phase 2: launch runner ===")
        self._create_iam()
        sg_id = self._create_security_group()
        log(f"sg={sg_id} role/profile={self.name_prefix}")
        iid = self._run_instance(pf, sg_id)
        self._wait_ssm_online(iid)
        return iid

    # ------------------------------------------------------------------
    # Rollback (on creation failure only). Successful creations are torn
    # down by the downstream consumer, not by the launcher.
    # ------------------------------------------------------------------
    def rollback(self) -> None:
        """Best-effort cleanup of partially-created resources on failure."""
        log("=== Rollback (partial-create cleanup) ===")
        iid = self._created.get("instance")
        if iid:
            try:
                self.ec2.terminate_instances(InstanceIds=[iid])
                self.ec2.get_waiter("instance_terminated").wait(
                    InstanceIds=[iid]
                )
                log(f"terminated {iid}")
            except ClientError as exc:
                log(f"terminate err: {exc}")
        prof = self._created.get("profile")
        if prof:
            try:
                self.iam.remove_role_from_instance_profile(
                    InstanceProfileName=prof, RoleName=prof
                )
            except ClientError:
                pass
            try:
                self.iam.delete_instance_profile(InstanceProfileName=prof)
                log(f"deleted instance profile {prof}")
            except ClientError as exc:
                log(f"profile del err: {exc}")
        role = self._created.get("role")
        if role:
            try:
                self.iam.detach_role_policy(
                    RoleName=role, PolicyArn=SSM_MANAGED_POLICY
                )
            except ClientError:
                pass
            try:
                self.iam.delete_role(RoleName=role)
                log(f"deleted role {role}")
            except ClientError as exc:
                log(f"role del err: {exc}")
        sg_id = self._created.get("sg")
        if sg_id:
            for attempt in range(5):
                try:
                    self.ec2.delete_security_group(GroupId=sg_id)
                    log(f"deleted sg {sg_id}")
                    break
                except ClientError as exc:
                    log(f"sg del retry {attempt + 1}: {exc}")
                    time.sleep(15)

    # ------------------------------------------------------------------
    # Handoff
    # ------------------------------------------------------------------
    def handoff(self, pf: Dict[str, Any]) -> Dict[str, Any]:
        """Build the handoff document describing the created runner."""
        return {
            "handoff_version": HANDOFF_VERSION,
            "kind": "ephemeral-ec2-runner",
            "ts": self.ts,
            "env_name": self.env_name,
            "aws": {
                "region": self.region,
                "account": self.identity["Account"],
            },
            "instance": {
                "id": self._created["instance"],
                "type": self.instance_type,
                "ami_id": pf["ami_id"],
                "vpc_id": self.vpc_id,
                "subnet_id": self.subnet_id,
            },
            "iam": {
                "role": self._created["role"],
                "instance_profile": self._created["profile"],
                "managed_policy_arn": SSM_MANAGED_POLICY,
            },
            "security_groups": {
                "ephemeral": self._created["sg"],
                "cloudera": pf["cloudera_sgs"],
            },
        }


def main() -> int:
    launcher = Launcher()
    try:
        pf = launcher.preflight()
        launcher.launch(pf)
    except SystemExit as exc:
        log(f"launch aborted: {exc}")
        launcher.rollback()
        return EXIT_AWS
    except ClientError as exc:
        log(f"AWS error: {exc}")
        launcher.rollback()
        return EXIT_AWS
    except Exception as exc:  # noqa: BLE001 — last-chance cleanup
        log(f"unexpected error: {exc}")
        launcher.rollback()
        return EXIT_AWS

    json.dump(launcher.handoff(pf), sys.stdout)
    sys.stdout.write("\n")
    sys.stdout.flush()
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
