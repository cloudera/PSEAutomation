# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Keycloak IDP provisioning: `cdp environments sync-all-users` retries on 409 `CONFLICT` when another user sync is already running; logs a plain-English wait/retry message (optional request id) instead of only the raw CLI error (waits via `get-environment-user-sync-state` / `sync-status`, then backoff; tunable via `HOL_CDP_USER_SYNC_*` env vars).
- Jenkins `CDE_VC_TIER` default is `ALLP` (choice order and PollSCM downstream param); `CORE` remains available for HoL 1-1 Core pool sizing.
- CDE `create-vc` no longer receives Jenkins alias `AUTO`: `deploy_cde` resolves via `hol_resolve_cde_spark_version` before Ansible (`spark_version_requested` vs CLI `spark_version`); playbook re-validates, logs the exact `--spark-version` value, and fails fast on `AUTO`/`SPARK3` ( `cdp de enable-service` is unchanged — it does not take a Spark version).
- CDE `create-vc` runtime catalog failures on Datalake 7.3.x: resolve `AUTO`/`SPARK3`/`SPARK3_5` to `SPARK3_5_4` in `enable-cde.yml` (passes `datalake_version` from config); Jenkins/PollSCM default `CDE_SPARK_VERSION` is `AUTO` instead of `SPARK3` (alias maps to Spark 3.2.x, incompatible with CDE 1.26 + DL 7.3.2).
- Parallel data-service Ansible logs use default console verbosity (no `-v` / JSON summarization); tailers only prefix `[CDE]`/`[CAI]` and compact skip lines.
- CDE on Python 3.12: patch `cdpcli.shorthand` via `hol-patch-python-deps.sh` (locate file without importing shorthand, drop stale `.pyc`) at entrypoint, `hol_enable_data_services`, and each `hol_run_ansible_playbook`.
- Drop `summarize-json` / `hol_summarize_ansible_result_json` and all ok/changed result rewriting in `hol-ansible-log-format.py` (debug `msg` lists no longer collapse to `N item(s)`).
- Ansible callback scan warning: `hol-ansible-log-format.py` is CLI-only (parallel tailers use `format-tagged-line` for skip compaction; no result JSON summarization).
- CDF was not triggered during parallel data-service provision when selected in Jenkins: config selection is stored in `HOL_ENABLE_DATA_SERVICES` (avoiding a name clash with `hol_enable_data_services()`), legacy `CML` maps to `CAI`, and PollSCM passes `ENABLE_DATA_SERVICES` as a string to downstream deploy jobs.
- CDE enable applies Jenkins min/max/initial only to the active VC tier via `cdp de enable-service`; inactive tier (Core or All Purpose) is 0/0/0 (ALLP no longer leaves Core at 1/1/1; CORE explicitly zeros All Purpose).
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
