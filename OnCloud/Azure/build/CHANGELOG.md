# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Azure data services now start concurrently without the previous cumulative 25-second stagger. Built-in CAI/CDE instance defaults bypass slow Azure SKU discovery; explicit instance overrides still receive availability validation and fallback.
- CDW playbook waits use single live retry checks for cluster deletion, activation, and database-catalog startup, avoiding pre-expanded/stale attempt output.
- Ansible waits now show retry attempts, retries remaining, current resource status/output, and async poll progress at normal verbosity so long-running playbooks do not appear stuck.
- `REFRESH_JENKINSFILE` is now the first parameter in every AWS/Azure Jenkinsfile; PollSCM jobs also support the same refresh-and-exit behavior.
- Parallel data-service heartbeat output now displays separate, counted `IN PROGRESS`, `SUCCEEDED`, and `FAILED` rows for easier Jenkins log scanning.
- Default `AZURE_REGION` for Jenkins deploy/test/PollSCM and `configuration/configfile.example` is `westus2` (subscription must support PostgreSQL Flexible Server; `eastus` may return empty SKU lists).
- Jenkins `DATALAKE_VERSION` parameter descriptions and `configfile.example` / `JENKINS-PIPELINES.adoc` clarify region (PostgreSQL SKU preflight) vs runtime version selection.

### Added
- `provision_cdp`: preflight `az postgres flexible-server list-skus` for `AZURE_REGION` before CDP Terraform with a clear fail message when SKU list is empty.
- Shell logging colors (AWS/Azure): `hol_color_enabled` default-on for `hol_ok` / `hol_warn` / `hol_step` and related helpers in non-TTY Jenkins docker logs (same opt-outs as Ansible); `assignCdpEnvAdminRoles.sh` sources `hol-output.sh` when available for green/red role lines.
- Parallel data-service wait (AWS/Azure): `hol_wait_parallel_data_services` logs each service as it finishes and periodic heartbeats while others run (`HOL_DS_WAIT_HEARTBEAT_SEC`, default 45s) so Jenkins console does not look hung after one playbook’s PLAY RECAP.
- Terraform console colors (AWS/Azure): `hol_terraform` / `hol_apply_terraform_env` mirror `hol_color_enabled` (`TF_IN_AUTOMATION=false`, `-color=true`; opt-out via `NO_COLOR`, `HOL_ANSIBLE_COLOR=false`, or `TF_CLI_ARGS=-no-color`); Keycloak, CDP, and enhancement apply/destroy in `hol-functions.sh` use the wrapper.
- Parallel Ansible playbook logs (AWS/Azure): `hol_run_ansible_playbook` sets `ANSIBLE_FORCE_COLOR=1` when stdout is a TTY, `HOL_ANSIBLE_COLOR=true`, or Jenkins/CI env (`BUILD_URL`, `JENKINS_URL`, `CI=true`); DeployHoL `docker run` passes `-e BUILD_URL`; tailers pass ANSI through unchanged; playbook failure excerpts strip escape codes before `fatal:` / `PLAY RECAP` grep.
- CDE/CDW/CDF disable playbooks (AWS/Azure): user-visible success `debug` messages on teardown completion (and when CDF is already absent), aligned with CAI `Successfully deleted/disabled … in environment …` wording.
- CDE/CDW/CDF enable playbooks (AWS/Azure): user-visible success `debug` messages on completion (and when CDF is already healthy), aligned with CAI `Successfully provisioned … in environment …` wording.

### Fixed
- CAII teardown (Azure): delete the CAI workspace before its registry and compute cluster so concurrent cleanup cannot race while removing federated credentials from the same managed identity; propagate failures from every CAII cleanup stage.
- CAII reruns (Azure): preserve pre-existing CDP infrastructure when a Terraform update fails; refresh CAII scripts without nesting stale copies; reuse/wait for healthy or in-progress resources; and recover terminally failed resources by retrying default-cluster initialization or recreating only the failed named compute cluster, AI Registry, or serving app.
- CDW enable (Azure): activate through the Azure-specific `cdp dw create-azure-cluster` operation using the resolved environment CRN, subnet, and managed identity. The collection module cannot be used with this image because `cdpy@main` routes it through legacy `createCluster` and emits the incompatible `computeInstanceTypes` payload.
- CDW failed activation recovery (Azure): delete the failed cluster with the explicit CDP CLI operation instead of accepting the collection module's false `Cluster None already absent` result.
- CDW activation networking (Azure): stop forcing Azure CNI Overlay. The working reference flow uses the default networking mode; overlay clusters repeatedly lost API-server/CoreDNS connectivity to Istio webhook pods and failed chart installation with 504 errors.
- CDW enable (Azure): run `cloudera.cloud.dw_cluster` with strict SDK errors so rejected activation requests fail instead of appearing as green `ok`, and fail explicitly when no cluster reaches a terminal state before the poll timeout.
- CDF enable (Azure): `cdf-enable-api-attempt.yml` only appends `--load-balancer-subnets` when `use_public_load_balancer` is false; passing load-balancer subnets alongside the public load balancer flag returned `400 INVALID_ARGUMENT: No subnet should be specified when using public load balancer`.
- CDW `disable-cdw.yml` (AWS/Azure): list-clusters verify uses `workshop_name` from extra-vars or derives prefix from `cdp_env_name` so destroy no longer fails after cluster poll succeeds.
- Terraform console colors (AWS/Azure): `hol_terraform` no longer passes `-color=true` (unsupported on HoL Terraform); colors-on uses `hol_apply_terraform_env` only (`TF_IN_AUTOMATION=false`), colors-off uses `-no-color` on init/apply/destroy/plan/refresh or `TF_CLI_ARGS=-no-color`; `output`/`state` unchanged.
- Ansible playbook streaming (AWS/Azure): `hol_run_ansible_playbook` calls the `hol_ansible_playbook` shell function directly; `stdbuf` wraps `ansible-playbook` inside the function so Jenkins destroy/provision no longer fails with `hol_ansible_playbook: No such file or directory`.
- Keycloak/IDP Ansible (AWS/Azure): `cdp_idp_setup_user` and `cdp_idp_user_teardown` call `hol_ansible_playbook` so Jenkins console gets the same `hol_ansible_force_color` / `ANSIBLE_FORCE_COLOR` / `PY_COLORS` as data-service playbooks.
- CDF `disable-cdf.yml` (AWS/Azure): set `cdf_service_requires_disable` before `cdf_skip_disable_service` (separate `set_fact` + play default) so Ansible does not reference an undefined sibling fact during derived-flag evaluation.
- CDF enable (AWS/Azure): treat CDP `412 FAILED_PRECONDITION` / `CANCEL_ENABLE` (stale in-flight enable) as poll-only — no repeated enable-service retries; refresh list-services before enable when state was absent; wait for GOOD_HEALTH when list shows ENABLING/DISABLING instead of exiting early; clearer fail text when a stuck enable never becomes healthy (suggest `disable-cdf.yml` or UI cancel).
- Data service enable/disable (AWS/Azure): parallel batches wait for every service playbook even when one fails; aggregate failures list failed services (CDW, CDE, …) and return non-zero so Jenkins fails after all playbooks finish. Destroy propagates disable failures via `hol_destroy_failed`.
- CDF enable (AWS/Azure): build `cdp df enable-service` argv in Ansible (`cdf-enable-api-attempt.yml`) and run via `command` — avoids `{% if %}` Jinja inside multiline `shell` that broke Ansible task parsing on the enable retry loop.
- CDF enable (AWS/Azure): call `cdp df enable-service` via shell (CAI-style CLI) instead of async `cloudera.cloud.df_service`; resolve environment CRN from `describe-environment`; 90s pause after role assignment before enable; retry transient authorizing/[500] every 90s (8 attempts); treat CONFLICT/already-enabling as success. Fail message documents DFAdmin vs IAM propagation. Docker image uses stable `cdpcli` (not beta).
- CDF `disable-cdf.yml` (AWS/Azure): resolve service CRN from list-services; skip `disable-service` only when all list/info/current states are absent/disabled or DISABLING is already in progress.
- CDF `disable-cdf.yml` (AWS/Azure): require both list-services and df_service_info clear before success; treat list-empty/info-present as in-progress (UI disable); remove early end_play that skipped verify polls.
- CDF `enable-cdf.yml` (AWS/Azure): fail fast when DISABLING while Jenkins enable runs (manual UI disable during provision).
- CDF enable/disable playbooks (AWS/Azure): list service state first and skip `enable-service` when the service is healthy or in progress (e.g. ENABLING, GOOD_HEALTH) and skip `disable-service` when absent/disabled or already DISABLING—no second API call on re-run.
- CDF `cdp df enable-service` omits `instance_type` unless `CDF_INSTANCE_TYPE` is set, so CDP chooses the default Kubernetes node type. A custom type requires permission to set custom DataFlow instance types; the previous `m5.2xlarge` / `Standard_D8s_v5` defaults returned `INVALID_ARGUMENT` (and could surface as an authorizing 500) for actors without that entitlement.
- Reverted Ansible playbook IAM pre-checks from `enable-cdf.yml` (`cdp iam get-user`, caller DFAdmin diagnostics). CDE/CDW/CAI playbooks unchanged at `faf0412` baseline. Environment admin roles are assigned only via `assignCdpEnvAdminRoles.sh` / `hol_assign_pipeline_cdp_env_admin_roles` (shell), not Ansible.
- Standalone HoL provisioner (`docker run` + `/userconfig/configfile`): post-Terraform env admin assignment runs in-container without Jenkins — roles go to the active `~/.cdp` API caller; optional `-e BUILD_USER_ID` for a second human (Jenkins sets this automatically).
- CDP env admin roles: `assignCdpEnvAdminRoles.sh` always assigns the full env admin set to pipeline machine user `psejenkins`, then the CDP API caller from `~/.cdp` when not already covered (`cdp iam get-user` or access-key match), then Jenkins `BUILD_USER_ID` when set and distinct from the caller. Summary log: `Assigning admin roles to machine user 'psejenkins' and build user '<id>' on <workshop>-cdp-env`. Runs in-container after Terraform (with `-e BUILD_USER_ID`); Jenkins pre/post stages use the same script when the env exists.
- Jenkins `BUILD_LOCAL_IMAGE`: resolve `DOCKER_IMAGE` in a **Resolve Docker Image** stage from `BUILD_IMAGE_TAG` (default `testmain`) instead of the declarative `environment` block binding `IMAGE_TAG` (often `testmain` from PollSCM while the local build used another tag). Build, pull, and `docker run` now share the same image reference; logs `Building … -> $IMAGE` and `Using locally built image: $IMAGE`.
- Ansible playbook failures fail Jenkins: `hol_run_ansible_playbook` returns the playbook exit code and echoes `fatal:` / `PLAY RECAP` lines; enable CDW/CDE/CAI/CDF propagate that status; `hol_enable_data_services` returns it so the provision container exits non-zero and the Docker stage fails.
- Jenkins **Check Logs for Failures** calls `error()` only for Ansible signals (`fatal: … FAILED!`/`UNREACHABLE!`, `failed=[1-9]`, `unreachable=[1-9]`, playbook-failed banners). Other log lines do not fail the build.
- Failure `post` still sends `emailext` on `FAILURE`, and backfills `docker logs` when the Docker stage stops before the log file is written.
- CDF enable: replace silent single-task `until` retries with explicit per-attempt debug, async `df_service` (`name`, `wait: false`) plus `async_status` polling (600s HTTP cap), and `df_service_info` health poll unchanged — CDF.log updates each attempt instead of ~5min gaps during authorizing [500] retries.
- Jenkins `BUILD_LOCAL_IMAGE`: pass `HOL_GIT_REVISION` (`git rev-parse HEAD`) into Docker build so HoL COPY layers (playbooks, entrypoint, assign script) rebuild when the checkout commit changes; full `CACHED` on rebuild of the same commit is expected and still correct.
- CDF enable on first workshop provision: Jenkins pre-container role assignment skipped when the CDP environment did not exist yet, so `psejenkins` lacked environment-scoped `DFAdmin` when `cdp df enable-service` ran (group `resourceAssignments` only show workshop roles like `EnvironmentUser`/`DWAdmin`, not pipeline machine-user roles). Provisioner now runs `assignCdpEnvAdminRoles.sh` after env creation and before data services; script is baked into the Docker image; `sync-all-users` uses `--environment-names`.
- CDF enable: AWS and Azure use `cloudera.cloud.df_service` with the same subnet and node-count mapping as the CLI; `instance_type` is omitted unless `CDF_INSTANCE_TYPE` is set (supersedes earlier default `Standard_D8s_v5` playbook default).
- CDE `cdp de enable-service`: Azure `enable-cde.yml` uses the same Core vs All Purpose sizing facts as AWS (`cloudera.cloud.de`); CLI always passes `--minimum/maximum/initial-instances` and matching `--all-purpose-*` (inactive tier 0/0/0). `deploy_cde` defaults `vc_tier` to `CORE` when unset.
- CDF enable: `jenkins/assignCdpEnvAdminRoles.sh` now assigns `DFAdmin` (required for `cdp df enable-service`; `DFFlowAdmin` alone is insufficient). Enable playbook fail message documents DFAdmin vs transient 500 retries.
- CDF enable: `cloudera.cloud.df_service` can return `failed=false` with an INTERNAL/`[500]` authorization error in `msg`; `enable-cdf.yml` now retries transient "try again later" responses, fails fast before the health poll, and treats error text in `msg` as failure (not only `changed=false`).
- Keycloak IDP provisioning: on 409, parse the running `usersync:<uuid>` from the conflict body and wait on that operation (a different COMPLETED sync-status is not "no active sync"); log `User sync already running (<uuid>) — waiting` and `CDP user sync retry N/12`. Full CDP error only on final failure or `HOL_CDP_USER_SYNC_DEBUG=1`.
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
- Optional in-job Docker image build on deploy jobs: `BUILD_LOCAL_IMAGE`, `BUILD_IMAGE_TAG` (default `testbuildimage`), `IMAGE_BUILD_BRANCH` (default `main`), `IMAGE_BUILD_TF_QS_VER`.
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
