# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Parallel data-service wait (AWS/Azure): `hol_wait_parallel_data_services` logs each service as it finishes and periodic heartbeats while others run (`HOL_DS_WAIT_HEARTBEAT_SEC`, default 45s) so Jenkins console does not look hung after one playbook’s PLAY RECAP.
- Parallel Ansible playbook logs (AWS/Azure): `hol_run_ansible_playbook` sets `ANSIBLE_FORCE_COLOR=1` when Jenkins/console stdout is a TTY or `HOL_ANSIBLE_COLOR=true` (default callback: green ok, yellow changed, red failed); tailers pass ANSI through unchanged; playbook failure excerpts strip escape codes before `fatal:` / `PLAY RECAP` grep.
- CDE/CDW/CDF disable playbooks (AWS/Azure): user-visible success `debug` messages on teardown completion (and when CDF is already absent), aligned with CAI `Successfully deleted/disabled … in environment …` wording.
- CDE/CDW/CDF enable playbooks (AWS/Azure): user-visible success `debug` messages on completion (and when CDF is already healthy), aligned with CAI `Successfully provisioned … in environment …` wording.

### Fixed
- CDF `disable-cdf.yml` (AWS/Azure): set `cdf_service_requires_disable` before `cdf_skip_disable_service` (separate `set_fact` + play default) so Ansible does not reference an undefined sibling fact during derived-flag evaluation.
- CDF enable (AWS/Azure): treat CDP `412 FAILED_PRECONDITION` / `CANCEL_ENABLE` (stale in-flight enable) as poll-only — no repeated enable-service retries; refresh list-services before enable when state was absent; wait for GOOD_HEALTH when list shows ENABLING/DISABLING instead of exiting early; clearer fail text when a stuck enable never becomes healthy (suggest `disable-cdf.yml` or UI cancel).
- Data service enable/disable (AWS/Azure): parallel batches wait for every service playbook even when one fails; aggregate failures list failed services (CDW, CDE, …) and return non-zero so Jenkins fails after all playbooks finish. Destroy propagates disable failures via `hol_destroy_failed`.
- CDF enable (AWS/Azure): build `cdp df enable-service` argv in Ansible (`cdf-enable-api-attempt.yml`) and run via `command` — avoids `{% if %}` Jinja inside multiline `shell` that broke Ansible task parsing on the enable retry loop.
- CDF enable (AWS/Azure): call `cdp df enable-service` via shell (CAI-style CLI) instead of async `cloudera.cloud.df_service`; resolve environment CRN from `describe-environment`; 90s pause after role assignment before enable; retry transient authorizing/[500] every 90s (8 attempts); treat CONFLICT/already-enabling as success. Fail message documents DFAdmin vs IAM propagation. Docker image uses stable `cdpcli` (not beta).
- AWS destroy: run `destroy_aws_enhancements` (detach `${env_prefix}-logs-policy` from `${env_prefix}-dladmin-role`) before CDP quickstart Terraform destroy so `aws_iam_policy` delete is not blocked by HoL’s `aws_iam_role_policy_attachment`.
- AWS destroy: propagate Terraform teardown failures — `destroy_hol_infra` non-zero exit fails the container via `hol_destroy_failed` (aligned with Azure), so Jenkins no longer reports success when CDP Terraform errors.
- CDF `disable-cdf.yml` (AWS/Azure): resolve service CRN from list-services; skip `disable-service` only when all list/info/current states are absent/disabled or DISABLING is already in progress.
- CDF `disable-cdf.yml` (AWS/Azure): set `cdf_disable_in_progress` and related flags in separate `set_fact` tasks so Ansible does not reference undefined sibling facts during derived-flag evaluation.
- CDF enable/disable playbooks (AWS/Azure): list service state first and skip `enable-service` when the service is healthy or in progress (e.g. ENABLING, GOOD_HEALTH) and skip `disable-service` when absent/disabled or already DISABLING—no second API call on re-run.
- CDF `cdp df enable-service` omits `instance_type` unless `CDF_INSTANCE_TYPE` is set, so CDP chooses the default Kubernetes node type. A custom type requires permission to set custom DataFlow instance types; the previous `m5.2xlarge` / `Standard_D8s_v5` defaults returned `INVALID_ARGUMENT` (and could surface as an authorizing 500) for actors without that entitlement.
- Reverted Ansible playbook IAM pre-checks from `enable-cdf.yml` (`cdp iam get-user`, caller DFAdmin diagnostics). CDE/CDW/CAI playbooks unchanged at `faf0412` baseline. Environment admin roles are assigned only via `assignCdpEnvAdminRoles.sh` / `hol_assign_pipeline_cdp_env_admin_roles` (shell), not Ansible.
- Standalone HoL provisioner (`docker run` + `/userconfig/configfile`): post-Terraform env admin assignment runs in-container without Jenkins — roles go to the active `~/.cdp` API caller; optional `-e BUILD_USER_ID` for a second human (Jenkins sets this automatically).
- CDP env admin roles: `assignCdpEnvAdminRoles.sh` always assigns the full env admin set to pipeline machine user `psejenkins`, then the CDP API caller from `~/.cdp` when not already covered (`cdp iam get-user` or access-key match), then Jenkins `BUILD_USER_ID` when set and distinct from the caller. Summary log: `Assigning admin roles to machine user 'psejenkins' and build user '<id>' on <workshop>-cdp-env`. Runs in-container after Terraform (with `-e BUILD_USER_ID`); Jenkins pre/post stages use the same script when the env exists.
- Jenkins `BUILD_LOCAL_IMAGE`: resolve `DOCKER_IMAGE` in a **Resolve Docker Image** stage from `BUILD_IMAGE_TAG` (default `testmain`) instead of the declarative `environment` block binding `IMAGE_TAG` (often `testmain` from PollSCM while the local build used another tag). Build, pull, and `docker run` now share the same image reference; logs `Building … -> $IMAGE` and `Using locally built image: $IMAGE`.
- Ansible playbook failures fail Jenkins: `hol_run_ansible_playbook` returns the playbook exit code and echoes `fatal:` / `PLAY RECAP` lines; enable CDW/CDE/CAI/CDF propagate that status; `hol_enable_data_services` returns it so the provision container exits non-zero and the Docker stage fails.
- Jenkins **Check Logs for Failures** calls `error()` only for Ansible signals (`fatal: … FAILED!`/`UNREACHABLE!`, `failed=[1-9]`, `unreachable=[1-9]`, playbook-failed banners). Other log lines do not fail the build.
- Failure `post` still sends `emailext` on `FAILURE`, and backfills `docker logs` when the Docker stage stops before the log file is written.
- CDF enable: explicit per-attempt debug + async `df_service` enable with HTTP timeout (`cdf-enable-api-attempt.yml`).
- Jenkins `BUILD_LOCAL_IMAGE`: pass `HOL_GIT_REVISION` (`git rev-parse HEAD`) into Docker build so HoL COPY layers (playbooks, entrypoint, assign script) rebuild when the checkout commit changes; full `CACHED` on rebuild of the same commit is expected and still correct.
- CDF enable on first workshop provision: Jenkins pre-container role assignment skipped when the CDP environment did not exist yet, so `psejenkins` lacked environment-scoped `DFAdmin` when `cdp df enable-service` ran (group `resourceAssignments` only show workshop roles like `EnvironmentUser`/`DWAdmin`, not pipeline machine-user roles). Provisioner now runs `assignCdpEnvAdminRoles.sh` after env creation and before data services; script is baked into the Docker image; `sync-all-users` uses `--environment-names`.
- CDF enable: both clouds use `cloudera.cloud.df_service` with Terraform subnet outputs (`nodes_min`/`nodes_max`, `public_loadbalancer`, `cluster_subnets`, `loadbalancer_subnets`); `instance_type` is omitted unless `CDF_INSTANCE_TYPE` is set (supersedes earlier default instance-type behavior).
- CDE enable: removed Azure-only `Standard_*` instance-type sanitization from AWS `enable-cde.yml`; `deploy_cde` defaults `vc_tier` to `CORE` when unset (matches Azure).
- CDF enable: `jenkins/assignCdpEnvAdminRoles.sh` now assigns `DFAdmin` (required for `cdp df enable-service`; `DFFlowAdmin` alone is insufficient). Enable playbook fail message documents DFAdmin vs transient 500 retries.
- CDF enable: `cloudera.cloud.df_service` can return `failed=false` with an INTERNAL/`[500]` authorization error in `msg`; `enable-cdf.yml` now retries transient "try again later" responses, fails fast before the health poll, and treats error text in `msg` as failure (not only `changed=false`).
- Keycloak IDP provisioning: on 409, parse the running `usersync:<uuid>` from the conflict body and wait on that operation (a different COMPLETED sync-status is not "no active sync"); log `User sync already running (<uuid>) — waiting` and `CDP user sync retry N/12`. Full CDP error only on final failure or `HOL_CDP_USER_SYNC_DEBUG=1`.
- Jenkins `CDE_VC_TIER` default is `CORE` (choice order and PollSCM downstream param), matching `enable-cde.yml` and `hol-functions.sh`; DeployHoL previously used `ALLP` when it was first in the Jenkins choice list.
- CDE `create-vc` no longer receives Jenkins alias `AUTO`: `deploy_cde` resolves via `hol_resolve_cde_spark_version` before Ansible (`spark_version_requested` vs CLI `spark_version`); playbook re-validates, logs the exact `--spark-version` value, and fails fast on `AUTO`/`SPARK3` ( `cdp de enable-service` is unchanged — it does not take a Spark version).
- CDE `create-vc` runtime catalog failures on Datalake 7.3.x: resolve `AUTO`/`SPARK3`/`SPARK3_5` to `SPARK3_5_4` in `enable-cde.yml` (passes `datalake_version` from config); Jenkins/PollSCM default `CDE_SPARK_VERSION` is `AUTO` instead of `SPARK3` (alias maps to Spark 3.2.x, incompatible with CDE 1.26 + DL 7.3.2).
- Parallel data-service Ansible logs use default console verbosity (no `-v` / JSON summarization); tailers only prefix service tags and compact skip lines.
- CDE on Python 3.12: `[CDE] SyntaxWarning: invalid escape sequence '\-'` during `cloudera.cloud.de_info` — patch `cloudera.cloud` `cdp_de.py` service-name error f-string (not `cdpcli.shorthand`) via `hol-patch-python-deps.sh`; still patch `cdpcli.shorthand` and `cdp_service.py` SEMVER; `hol_run_ansible_playbook` sets `PYTHONWARNINGS=ignore::SyntaxWarning` for module subprocesses.
- Drop `summarize-json` / `hol_summarize_ansible_result_json` and all ok/changed result rewriting in `hol-ansible-log-format.py` (debug `msg` lists no longer collapse to `N item(s)`).
- Ansible callback scan warning: `hol-ansible-log-format.py` is CLI-only (parallel tailers use `format-tagged-line` for skip compaction; no result JSON summarization).
- CDF (and other selected data services) were skipped during parallel provision because the config value and entrypoint function shared the name `enable_data_services`; selection is now stored in `HOL_ENABLE_DATA_SERVICES` and invoked via `hol_enable_data_services()`. Legacy `CML` tokens map to `CAI`. PollSCM passes `ENABLE_DATA_SERVICES` as a string parameter so downstream deploy jobs receive `CDF` reliably.
- CDE enable applies Jenkins min/max/initial only to the active VC tier (Core or All Purpose); the inactive tier is 0/0/0 in Capacity & Costs (fixes ALLP leaving Core at 1/1/1 and CORE leaving All Purpose unsized).
- CDE Core autoscaling defaults and PollSCM params aligned to min 0 / max 25 (was 1/1 on automated runs), so CORE-tier VCs can scale out; playbook fails if the service never reaches `ClusterCreationCompleted` instead of continuing silently.

## [3.3.2] - 2026-09-11

### Added
- Jenkins pipelines guide: `OnCloud/JENKINS-PIPELINES.adoc` (job inventory, parameters, stages, workflows).
- Optional in-job Docker image build on deploy jobs: `BUILD_LOCAL_IMAGE`, `BUILD_IMAGE_TAG` (default `testbuildimage`), `IMAGE_BUILD_BRANCH`, `IMAGE_BUILD_TF_QS_VER`.
- `jenkins/assignCdpEnvAdminRoles.sh` — assigns environment admin roles to `psejenkins` and CDP caller before provision/destroy (includes `DFFlowAdmin` for CDF flow stop).

### Changed
- Deploy Jenkinsfiles assign CDP env admin roles via shared script instead of inline shell (pre-run for machine user; post-provision for build user).
- Parallel data-service disable playbooks stream tagged output to per-service log files (`hol_run_ansible_playbook`).

### Fixed
- CDF disable: correct deployment filter, stop flows before delete, `df_deployment` / service disable API usage.
- CDE disable: accurate success messaging; skip re-enable when cluster already exists or is in progress; sanitize Azure instance types.
- CDW disable: delete connectors before cluster removal.
- CDF/CDE enable: sanitize instance type values corrupted by stdout capture from `resolve_azure_instance_type`.
- AWS `aws_prereq`: skip VPC quota check when CDP environment already exists (partial-failure reruns).
- Keycloak IP: store per workshop at `/userconfig/.{workshop}/keycloak_ip` with Terraform `elastic_ip` fallback (avoids parallel Jenkins jobs clobbering shared `/userconfig/keycloak_ip`); fail clearly when user JSON export is missing after fetch.
- Partial-failure reruns: skip Keycloak Terraform apply when instance already in state; skip full Keycloak EC2 setup when per-workshop IP/state exists; wait for Keycloak HTTPS before IDP Ansible; treat non-`ALREADY_EXISTS` CDP `create-user` errors as fatal; fail provision when IDP setup returns non-zero (e.g. stale IP after failed destroy).
- Workshop report: replace existing Keycloak section in `/userconfig/{workshop}.txt` on IDP reruns instead of appending duplicates.

## [3.3.1] - 2026-09-08

### Changed
- Jenkins `OWNER` parameter default is `pse-apac@cloudera.com`; when `PROVISION_CAII=YES`, `LOCAL_MACHINE_IP` cannot be `0.0.0.0/0` (use Jenkins agent IP or Cloudera VPN `208.127.31.110/32` / `208.127.31.11/32`).
- Script output uses emoji, ANSI colors, section dividers, and a startup ASCII banner via shared `hol-output.sh` helpers for clearer Jenkins/console logs.
- Renamed CML data service to CAI (Cloudera AI) across pipeline, playbooks, and workspace naming.
- CDW, CDE, CAI, and CDF data service playbooks now run in parallel when multiple services are selected.
- CAII provisioning runs in parallel with other selected data services to reduce total provision time.
- CDW enable/disable playbooks now create or remove virtual warehouses and data visualizations in parallel using Ansible async tasks.
- CDE enable/disable playbooks now create or remove virtual clusters in parallel using Ansible async tasks.

### Added
- CDF (Cloudera Data Flow) data service support with enable/disable playbooks, Jenkins parameters, and `DFFlowUser`/`DFFlowDeveloper` resource roles for workshop users.

### Fixed
- Jenkins failure emails now include parsed Ansible/Terraform fatal errors from provisioner logs.
- Failure emails now summarize CDP/AWS quota errors such as SAML provider, IAM user/group, VPC, EIP, and S3 limits.
- IAM role assignment in Jenkins treats `ALREADY_EXISTS` / already-assigned roles as success instead of failing the build.
- CDW disable playbook now skips teardown gracefully when the cluster or virtual warehouses do not exist, instead of retrying indefinitely.
- CDW enable playbook now treats existing virtual warehouses as success and fails only on real create errors.
- AI Registry teardown now deletes registries in any status (not only `installation:finished`) and stops infinite retry loops with a bounded verification timeout.
- Renamed `owner` env tag to `pse-owner` to avoid conflict with CDP account default tags.
- Fixed rollback shell error (`[: -eq: unary operator expected`) in `destroy_cdp` and `destroy_hol_infra`.

## [3.3.0] - 2026-09-08

### Added
- Added support for tagging deployed AWS resources via the configuration file.

### Changed
- Removed the password reset requirement on first login for Keycloak users.
- Reduced S3 logs retention period to 3 days

## [3.2.2] - 2025-08-13

### Fixed
- Increased the timeout and added a check for AI regsitry.

## [3.2.1] - 2025-07-16

### Added
- Added new AWS region support for Keycloak server deployment.

### Fixed
- Logging enhancements and error handling for keycloak deployment.

## [3.2.0] - 2025-08-01

### Added
- Added a new feature to provision and destroy CAII service

## [3.1.2] - 2025-04-16

### Fixed
- Fixed the 'Warning: Invalid Attribute Combination' in the s3 lifecycle policy.

## [3.1.1] - 2025-03-28

### Fixed

- Updated S3 lifecycle policy rules

## [3.1.0] - 2025-03-26

### Changed
- Updated the README documentation with the latest screenshot of the output file i.e. .txt
- Improved the formatting of logging statements.

### Fixed
- Fixed CDW deployment definition to ensure it correctly includes three subnets from the public and private subnets.

## [3.0.0] - 2025-02-28

### Added
- Enabled HTTPS/SSL for Keycloak server deployment with Route53 domain integration.
- Enabled S3 bucket lifecycle policy for logs cleanup.
- Added a new parameter vc_tier for CDE service virtual cluster deployment.
- Added a new folder for AWS_Enhancements.

### Changed
- Updated the Dockerfile i.e base image, Terraform, Ansible, Python3, Quickstart versions, layering optimizations.
- Updated Readme documentations.
- Updated sg_name logic for keycloak deployment.
- Enhanced logging statements.

### Fixed
- Fixed CML deployment definition to include only one of default_settings and cpu_settings.

## [2.3.2] - 2025-02-06

### Changed
- Changed the CML service parameters.

### Fixed
- Fixed CML service deployment failure due to parameter definition changes in new CML runtime version.

## [2.3.1] - 2025-01-03

### Changed
- Updated the CDW service parameters as per new CDPCLI version

### Fixed
- Fixed CDW service deployment failure due to parameter changes in new CDPCLI version

## [2.3.0] - 2024-12-30

### Added
- Added a new parameter of datalake_version
- Added a precheck for workshop name length

### Fixed
- Updated the enable_gpu parameter to accept only boolean values


## [2.2.0] - 2024-12-02

### Changed
- Renamed and restructured repo folders
- Updated Keycloak SSO URL as per CDP region
- Updated Readme files

### Added
- Added new readme files for newly created folders


## [2.1.0] - 2024-11-15

### Changed
- Updated code to parameterize the cdp-tf-quickstart version while building the Docker image, could be passed externally as docker build-args

## [2.0.0] - 2024-10-09

### Added
- New feature to parameterise the CDP quota for user,group and identity provider.
  

### Changed
- Changed the authentication method for AWS and CDP
- AWS_KEY_PAIR is now an optional parameter

### Removed
- Removed the need of passing access key and secret key for AWS and CDP via config file.
- Removed the need of Keycloak ServerName and SG Name in config file.



## [1.0.0] - 2024-08-02

### Added
- New feature to parameterise the size of Virtual Warehouses provisioned.
- New feature to parameterise instance type, min and max instance count while activating CDE service and spark version for virtual cluster

### Changed

### Fixed

### Removed
