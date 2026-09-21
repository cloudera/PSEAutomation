# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Parallel data-service Ansible logs use default console verbosity (no `-v` / JSON summarization); tailers only prefix `[CDE]`/`[CAI]` and compact skip lines.
- Ansible callback scan warning: stop installing `hol-ansible-log-format.py` as a callback plugin (CLI only; `default.py` loads it from `/usr/local/bin/`).
- CDF was not triggered during parallel data-service provision when selected in Jenkins: config selection is stored in `HOL_ENABLE_DATA_SERVICES` (avoiding a name clash with `hol_enable_data_services()`), legacy `CML` maps to `CAI`, and PollSCM passes `ENABLE_DATA_SERVICES` as a string to downstream deploy jobs.
- CDE tier sizing: CORE → Core 0–25 with initial 1; ALLP → All Purpose 0–25 with initial 1 and Core 0/0/0 (`cdp de enable-service` / `cloudera.cloud.de`). Active-tier initial is always 1 in HoL.
- CDE Core autoscaling defaults and PollSCM params aligned to min 0 / max 25; enable playbook fails when the service does not reach `ClusterCreationCompleted`.

## [1.0.0] - 2026-09-11

### Added
- Jenkins pipelines guide: `OnCloud/JENKINS-PIPELINES.adoc` (shared with AWS; Azure-specific defaults documented).
- Optional in-job Docker image build on deploy jobs: `BUILD_LOCAL_IMAGE`, `BUILD_IMAGE_TAG` (default `testbuildimage`), `IMAGE_BUILD_BRANCH` (default `azure-automation`), `IMAGE_BUILD_TF_QS_VER`.
- `jenkins/assignCdpEnvAdminRoles.sh` — assigns environment admin roles to `psejenkins` and CDP caller before provision/destroy.

### Changed
- Deploy Jenkinsfiles assign CDP env admin roles via shared script instead of inline shell.
- Parallel data-service disable uses `hol_run_ansible_playbook` with per-service log files under `/userconfig/.{workshop}/logs/`.
- CDE enable skips activation when service already exists (including in-progress states); instance type sanitization for Azure SKUs.

### Fixed
- CDF/CDE/CDW disable playbooks aligned with AWS fixes (flow stop, connector teardown, deployment delete).
- `resolve_azure_instance_type` logs to stderr so command-substitution no longer corrupts instance type variables.
- Keycloak IP: per-workshop file under `/userconfig/.{workshop}/keycloak_ip` with Terraform fallback; IDP setup fails fast if user export JSON is missing.
- Partial-failure reruns: skip Keycloak VM apply when resource already in state; skip Keycloak provisioning when IP/state exists; HTTPS readiness before IDP Ansible; stricter CDP user-create errors; fail provision when IDP setup returns non-zero.
- Workshop report: replace existing Keycloak section in `/userconfig/{workshop}.txt` on IDP reruns instead of appending duplicates.
- Keycloak destroy: when CDP terraform context is gone, recover network variables from Keycloak state (or fail) instead of skipping destroy and leaving per-workshop IP/state behind.

## [0.1.0] - 2026-09-10

### Added
- Initial Azure automation folder mirrored from `OnCloud/AWS/build`.
- Azure CDP provisioning via `cdp-tf-quickstarts` Azure modules.
- Azure Keycloak VM, SSH key generation, and storage lifecycle enhancements.
- Azure-specific CDW, CAI, CDE, and CDF playbooks and Jenkins parameters.
- Azure IAM enhancements (CDW/CDE managed identities, CAI NFS).
