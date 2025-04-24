# ----------------------------------------------------------------------------------------------------------------------
# KMS
# ----------------------------------------------------------------------------------------------------------------------

# Key ------------------------------------------------------------------------------------------------------------------

resource "aws_kms_key" "this" {
  count = local.kms_key_create ? 1 : 0

  description = "Key used to encrypt bucket objects"

  tags = var.tags
}

# Alias ----------------------------------------------------------------------------------------------------------------

resource "aws_kms_alias" "this" {
  count = local.kms_key_create ? 1 : 0

  name          = "alias/${var.identifier}"
  target_key_id = one(aws_kms_key.this[*].key_id)
}

# Policy ---------------------------------------------------------------------------------------------------------------

resource "aws_kms_key_policy" "this" {
  count = local.kms_key_create ? 1 : 0

  key_id = one(aws_kms_key.this[*].id)
  policy = data.aws_iam_policy_document.kms.json
}

data "aws_iam_policy_document" "kms" {
  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

# Locals ---------------------------------------------------------------------------------------------------------------

locals {
  kms_key_arn    = try(coalesce(var.kms_key_arn, one(aws_kms_key.this[*].arn)), null)
  kms_key_create = var.s3_kms_encryption_enabled && var.kms_key_arn == null
}

# ----------------------------------------------------------------------------------------------------------------------
