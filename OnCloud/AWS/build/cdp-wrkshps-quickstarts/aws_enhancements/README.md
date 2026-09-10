# AWS Enhancements

Post-provision enhancements applied after the CDP environment is created.

## s3_enhancements

Applies a lifecycle policy on the CDP log bucket so objects under `logs/` are removed after **3 days**.

## dladmin_log_policy

Attaches the CDP `${env_prefix}-logs-policy` IAM policy to the `${env_prefix}-dladmin-role`. This grants `s3:PutObject` on the logs location, which the datalake admin role does not receive from the default quickstart role attachments alone.

