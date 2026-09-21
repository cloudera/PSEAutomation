# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Ansible playbook failures fail Jenkins: `hol_run_ansible_playbook` returns the playbook exit code and echoes `fatal:` / `PLAY RECAP` lines; enable CDW/CDE/CAI/CDF propagate that status; `hol_enable_data_services` returns it so the provision container exits non-zero and the Docker stage fails.
- Jenkins **Check Logs for Failures** calls `error()` only for Ansible signals (`fatal: … FAILED!`/`UNREACHABLE!`, `failed=[1-9]`, `unreachable=[1-9]`, playbook-failed banners). Other log lines do not fail the build.
- Failure `post` still sends `emailext` on `FAILURE`, and backfills `docker logs` when the Docker stage stops before the log file is written.
- CDF enable: replace silent single-task `until` retries with explicit per-attempt debug, async `df_service` (`env_crn`, `wait: false`) plus `async_status` polling (600s HTTP cap), and `df_service_info` health poll unchanged — CDF.log updates each attempt instead of ~5min gaps during authorizing [500] retries.
- CDF enable fail message: when pre-enable checks show env-scoped DFAdmin on the CDP caller, fail text points to CDP DataFlow control-plane / authorization [500] (workshop-group `resourceAssignments` are unrelated).
- Jenkins `BUILD_LOCAL_IMAGE`: pass `HOL_GIT_REVISION` (`git rev-parse HEAD`) into Docker build so HoL COPY layers (playbooks, entrypoint, assign script) rebuild when the checkout commit changes; full `CACHED` on rebuild of the same commit is expected and still correct.
- CDF enable fail message: when pre-enable checks show env-scoped DFAdmin on the CDP caller, playbook no longer blames missing IAM; logs caller identity and points to CDP DataFlow control-plane / transient authorization [500] (workshop-group resourceAssignments are unrelated).
- CDF enable on first workshop provision: Jenkins pre-container role assignment skipped when the CDP environment did not exist yet, so `psejenkins` lacked environment-scoped `DFAdmin` when `cdp df enable-service` ran (group `resourceAssignments` only show workshop roles like `EnvironmentUser`/`DWAdmin`, not pipeline machine-user roles). Provisioner now runs `assignCdpEnvAdminRoles.sh` after env creation and before data services; script is baked into the Docker image; `sync-all-users` uses `--environment-names`.
- CDF `cdp df enable-service`: Azure `enable-cdf.yml` default `--instance-type` is `Standard_D8s_v5` (was `Standard_D8s_v3`; matches Jenkins, configfile, and `deploy_cdf`). AWS and Azure both enable via `cloudera.cloud.df_service` with the same subnet and node-count mapping as the CLI.
- CDE `cdp de enable-service`: Azure `enable-cde.yml` uses the same Core vs All Purpose sizing facts as AWS (`cloudera.cloud.de`); CLI always passes `--minimum/maximum/initial-instances` and matching `--all-purpose-*` (inactive tier 0/0/0). `deploy_cde` defaults `vc_tier` to `CORE` when unset.
- CDF enable: `jenkins/assignCdpEnvAdminRoles.sh` now assigns `DFAdmin` (required for `cdp df enable-service`; `DFFlowAdmin` alone is insufficient). Enable playbook fail message documents DFAdmin vs transient 500 retries.
- CDF enable: `cloudera.cloud.df_service` can return `failed=false` with an INTERNAL/`[500]` authorization error in `msg`; `enable-cdf.yml` now retries transient "try again later" responses, fails fast before the health poll, and treats error text in `msg` as failure (not only `changed=false`).
- Keycloak IDP provisioning: `hol_cdp_sync_all_users_resilient` on 409 `CONFLICT` logs the CDP error line, distinguishes HTTP request id from user-sync operation id, and snapshots `get-environment-user-sync-state` / `sync-status` / `last-sync-status`. Waits only when state is `SYNC_IN_PROGRESS` or operation status is `REQUESTED`/`RUNNING`; otherwise treats 409 as a transient lock (common right after IAM user creation) with a short backoff (`HOL_CDP_USER_SYNC_STALE_CONFLICT_SLEEP_SEC`, default 5s) instead of always claiming another sync is running.
- Jenkins `CDE_VC_TIER` default is `CORE` (choice order and PollSCM downstream param), matching `enable-cde.yml` and `hol-functions.sh`; cicd143/DeployHoL previously used `ALLP` because it was first in the Jenkins choice list (bc7e1d7).
- CDE `create-vc` no longer receives Jenkins alias `AUTO`: `deploy_cde` resolves via `hol_resolve_cde_spark_version` before Ansible (`spark_version_requested` vs CLI `spark_version`); playbook re-validates, logs the exact `--spark-version` value, and fails fast on `AUTO`/`SPARK3` ( `cdp de enable-service` is unchanged — it does not take a Spark version).
- CDE `create-vc` runtime catalog failures on Datalake 7.3.x: resolve `AUTO`/`SPARK3`/`SPARK3_5` to `SPARK3_5_4` in `enable-cde.yml` (passes `datalake_version` from config); Jenkins/PollSCM default `CDE_SPARK_VERSION` is `AUTO` instead of `SPARK3` (alias maps to Spark 3.2.x, incompatible with CDE 1.26 + DL 7.3.2).
- Parallel data-service Ansible logs use default console verbosity (no `-v` / JSON summarization); tailers only prefix `[CDE]`/`[CAI]` and compact skip lines.
- CDE on Python 3.12: `[CDE] SyntaxWarning: invalid escape sequence '\-'` during `cloudera.cloud.de_info` — patch `cloudera.cloud` `cdp_de.py` service-name error f-string (not `cdpcli.shorthand`) via `hol-patch-python-deps.sh`; still patch `cdpcli.shorthand` and `cdp_service.py` SEMVER; `hol_run_ansible_playbook` sets `PYTHONWARNINGS=ignore::SyntaxWarning` for module subprocesses.
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
