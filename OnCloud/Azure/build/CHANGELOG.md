# Changelog — Azure HoL Automation

All notable changes to the Azure provisioner under `OnCloud/Azure/build`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Trino Virtual Warehouses are created alongside Hive and Impala, using a live-validated CDP instance type; auto-suspend is enabled for all three engines by default and is configurable.

## [1.0.0] - 2026-09-24

### Added
- Complete Azure workshop provisioning and teardown using CDP Terraform quickstarts.
- Azure-specific networking, storage, Keycloak, IAM, managed identity, and NFS automation.
- Automated CDW, CAI, CAII, CDE, and CDF lifecycle management with safe rerun and recovery behavior.
- Concurrent data-service execution with live per-service logs, retry progress, heartbeats, and aggregated failure reporting.
- Environment Data Hub deletion before infrastructure teardown, enabled by default and configurable with `DELETE_DATAHUBS`.
- Safe CAI and CAII cleanup that repairs missing identities and federated credentials, preserves healthy resources, and prevents orphaned Azure resources.
- Reliable Azure CDW activation, failed-cluster recovery, terminal-state validation, and compatible cluster networking.
- Idempotent CDE and CDF provisioning and teardown with compatible defaults, sizing, autoscaling, and transient-error retries.
- Jenkins deploy, test, polling, refresh, local-image build, notification, and failure-detection workflows.
- Automated CDP environment role assignment for pipeline, API, and build users.
- Azure region and PostgreSQL Flexible Server SKU validation before provisioning.
- Colorized Jenkins, Terraform, and Ansible output with clear success and failure summaries.
- Partial-failure recovery for Keycloak, IDP, CDP environments, and data services without unnecessary resource replacement.
