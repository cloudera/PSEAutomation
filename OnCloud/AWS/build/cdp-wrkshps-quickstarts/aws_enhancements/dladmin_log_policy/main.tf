# Attach CDP log data access policy (s3:PutObject on logs path) to the datalake admin role.
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.65.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_iam_role" "datalake_admin" {
  name = "${var.env_prefix}-dladmin-role"
}

data "aws_iam_policy" "log_data_access" {
  name = "${var.env_prefix}-logs-policy"
}

resource "aws_iam_role_policy_attachment" "datalake_admin_log_policy" {
  role       = data.aws_iam_role.datalake_admin.name
  policy_arn = data.aws_iam_policy.log_data_access.arn
}
