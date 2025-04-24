# ----------------------------------------------------------------------------------------------------------------------
# IAM
# ----------------------------------------------------------------------------------------------------------------------

# Role -----------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = "${var.identifier}-lambda-edge-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# Policies -------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "this" {
  for_each = { for i in range(length(local.lambda_role_policies)) : i => local.lambda_role_policies[i] }

  role   = aws_iam_role.this.id
  policy = each.value
}

locals {
  lambda_role_policies = concat(var.lambda_role_policies, [ for policy in local.lambda_role_policies_templates : policy.template if policy.condition ])
  lambda_role_policies_templates = [
    {
      condition  = local.lambda_authentication_enabled
      template   = one(data.aws_iam_policy_document.authentication[*].json)
    }
  ]
}

# Documents ------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "authentication" {
  count = local.lambda_authentication_enabled ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [var.cognito_secret_arn]
  }

  statement {
    actions = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.cognito_key_arn]
  }
}

# ----------------------------------------------------------------------------------------------------------------------
