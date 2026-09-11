# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [0.1.0] - 2026-09-10

### Added
- Initial Azure automation folder mirrored from `OnCloud/AWS/build`.
- Azure CDP provisioning via `cdp-tf-quickstarts` Azure modules.
- Azure Keycloak VM, SSH key generation, and storage lifecycle enhancements.
- Azure-specific CDW, CAI, CDE, and CDF playbooks and Jenkins parameters.
- Azure IAM enhancements (CDW/CDE managed identities, CAI NFS).
