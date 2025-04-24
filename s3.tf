# ----------------------------------------------------------------------------------------------------------------------
# S3
# ----------------------------------------------------------------------------------------------------------------------

# Bucket ---------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = var.s3_bucket_name
  force_destroy = var.s3_bucket_force_destroy

  tags = var.tags
}

# Ownership ------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Policy ---------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.this.arn]
      variable = "aws:SourceArn"
    }
  }
}

# Encryption -----------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.s3_kms_encryption_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
  }
}

# Versioning -----------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "this" {
  count = var.s3_versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle ------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.s3_lifecycle_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_expiration_days
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
