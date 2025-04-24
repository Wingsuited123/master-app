# ----------------------------------------------------------------------------------------------------------------------
# Module
# ----------------------------------------------------------------------------------------------------------------------

variable "identifier" {
  description = "Identifier to add to named resources"
  type        = string
}

variable "tags" {
  description = "Tags to add to each resource"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------------------------------------------------
# ACM
# ----------------------------------------------------------------------------------------------------------------------

# Certificate ----------------------------------------------------------------------------------------------------------

variable "acm_certificate_arn" {
  description = "ACM Certificate to use with CloudFront. Leave this empty for the module to provision the certificate itself"
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------------------------------------------------
# CloudFront
# ----------------------------------------------------------------------------------------------------------------------

# Distribution ---------------------------------------------------------------------------------------------------------

variable "cf_aliases" {
  description = "Domains to add to the CloudFront distribution"
  type        = list(string)
}

variable "cf_default_root_object" {
  description = "CloudFront origin default object"
  type        = string
  default     = "index.html"
}

variable "cf_origin_id" {
  description = "Origin ID to use for the CloudFront distribution"
  type        = string
  default     = "S3"
}

variable "cf_price_class" {
  description = "Price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cf_price_class)
    error_message = "Must be one of PriceClass_100, PriceClass_200, or PriceClass_All"
  }
}

variable "cf_http_version" {
  description = "HTTP version for the CloudFront distribution"
  type        = string
  default     = "http2"

  validation {
    condition     = contains(["http1.1", "http2", "http2and3", "http3"], var.cf_http_version)
    error_message = "Must be one of http1.1, http2, http2and3, or http3"
  }
}

variable "cf_ipv6_enabled" {
  description = "If IPv6 should be enabled for the CloudFront distribution"
  type        = bool
  default     = true
}

variable "cf_web_acl_arn" {
  description = "WAF Web ACL to associate with the CloudFront distribution"
  type        = string
  default     = null
}

variable "cf_custom_error_responses" {
  description = "List of error responses for the CloudFront distribution"
  type = list(object({
    error_caching_min_ttl = optional(number)
    error_code            = number
    response_code         = optional(string)
    response_page_path    = optional(string)
  }))
  default = []
}

variable "cf_restrictions" {
  description = "Restrictions to apply to the CloudFront distribution"
  type = object({
    geo_restriction = object({
      restriction_type = string
      locations        = list(string)
    })
  })
  default = {
    geo_restriction = {
      restriction_type = "none"
      locations        = []
    }
  }
}

# Certificate ----------------------------------------------------------------------------------------------------------

variable "cf_certificate_minimum_protocol_version" {
  description = "Minimum TLS version of the SSL certificate"
  type        = string
  default     = "TLSv1.2_2021"

  validation {
    condition     = contains(["TLSv1", "TLSv1_2016", "TLSv1.1_2016", "TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021", "SSLv3"], var.cf_certificate_minimum_protocol_version)
    error_message = "Must be one of TLSv1, TLSv1_2016, TLSv1.1_2016, TLSv1.2_2018, TLSv1.2_2019, TLSv1.2_2021 or SSLv3"
  }
}

variable "cf_certificate_ssl_support_method" {
  description = "Method used to serve HTTPs requests"
  type        = string
  default     = "sni-only"
}

# Cache Behavior -------------------------------------------------------------------------------------------------------

variable "cf_cache_behavior_default" {
  description = "Default CloudFront cache behavior"
  default     = {}
  type = object({
    allowed_methods        = optional(list(string), ["GET", "HEAD"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    target_origin_id       = optional(string, "S3")
    viewer_protocol_policy = optional(string, "redirect-to-https")
    compress               = optional(bool, false)
    # Lambda Functions
    lambda_functions = optional(object({
      viewer_request = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      viewer_response = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      origin_request = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      origin_response = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
    }), {})
    # Cache Policy
    cache_policy_id = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # CachingOptimized
    cache_policy = optional(object({
      min_ttl     = optional(number, 0)
      max_ttl     = optional(number, 31536000)
      default_ttl = optional(number, 86400)
      parameters_in_cache_key_and_forwarded_to_origin = optional(object({
        cookies_config                = optional(any)
        headers_config                = optional(any)
        query_strings_config          = optional(any)
        enable_accept_encoding_brotli = optional(bool, false)
        enable_accept_encoding_gzip   = optional(bool, false)
      }))
    }))
    # Origin Request Policy
    origin_request_policy_id = optional(string)
    origin_request_policy = optional(object({
      cookies_config       = optional(any)
      headers_config       = optional(any)
      query_strings_config = optional(any)
    }))
    # Response Headers Policy
    response_headers_policy_id = optional(string)
    response_headers_policy = optional(object({
      cors_config                  = optional(any)
      custom_headers_config        = optional(any)
      remove_headers_config        = optional(any)
      security_headers_config      = optional(any)
      server_timing_headers_config = optional(any)
    }))
  })
}

variable "cf_cache_behaviors_ordered" {
  description = "Ordered CloudFront cache behaviors"
  default     = []
  type = list(object({
    path_pattern           = string
    allowed_methods        = optional(list(string), ["GET", "HEAD"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    target_origin_id       = optional(string, "S3")
    viewer_protocol_policy = optional(string, "redirect-to-https")
    compress               = optional(bool, false)
    # Lambda Functions
    lambda_functions = optional(object({
      viewer_request = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      viewer_response = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      origin_request = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
      origin_response = optional(object({
        handler              = optional(string, "index.handler")
        runtime              = optional(string, "nodejs18.x")
        source_dir           = string
        include_body         = optional(bool, false)
        install_dependencies = optional(bool, false)
        config_file          = optional(string, "config.json")
        config_content       = optional(string, "{}")
      }))
    }), {})
    # Cache Policy
    cache_policy_id = optional(string)
    cache_policy = optional(object({
      min_ttl     = optional(number, 0)
      max_ttl     = optional(number, 31536000)
      default_ttl = optional(number, 86400)
      parameters_in_cache_key_and_forwarded_to_origin = optional(object({
        cookies_config                = optional(any)
        headers_config                = optional(any)
        query_strings_config          = optional(any)
        enable_accept_encoding_brotli = optional(bool, false)
        enable_accept_encoding_gzip   = optional(bool, false)
      }))
    }))
    # Origin Request Policy
    origin_request_policy_id = optional(string)
    origin_request_policy = optional(object({
      cookies_config       = optional(any)
      headers_config       = optional(any)
      query_strings_config = optional(any)
    }))
    # Response Headers Policy
    response_headers_policy_id = optional(string)
    response_headers_policy = optional(object({
      cors_config                  = optional(any)
      custom_headers_config        = optional(any)
      remove_headers_config        = optional(any)
      security_headers_config      = optional(any)
      server_timing_headers_config = optional(any)
    }))
  }))
}

# ----------------------------------------------------------------------------------------------------------------------
# Cognito
# ----------------------------------------------------------------------------------------------------------------------

variable "cognito_auth_enabled" {
  description = "If Cognito authentication should be enabled"
  type        = bool
  default     = false
}

variable "cognito_groups" {
  description = "Allowed Cognito groups"
  type        = list(string)
  default     = []
}

variable "cognito_whitelist" {
  description = "IPs to bypass Cognito authentication"
  type        = list(string)
  default     = []
}

variable "cognito_login_path" {
  description = "Path to redirect to after login"
  type        = string
  default     = "/auth-login"
}

variable "cognito_refresh_path" {
  description = "Path to redirect to after refresh"
  type        = string
  default     = "/auth-refresh"
}

variable "cognito_secret_arn" {
  description = "ARN of the Cognito secret"
  type        = string
  default     = null
}

variable "cognito_key_arn" {
  description = "ARN of the KMS key to use for Cognito"
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------------------------------------------------
# Lambda
# ----------------------------------------------------------------------------------------------------------------------

variable "lambda_deployment_package_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = "/packages"

  validation {
    condition     = can(regex("^/", var.lambda_deployment_package_path))
    error_message = "Path must start with /"
  }
}

variable "lambda_deployment_bash_interpreter" {
  description = "Path to the Lambda deployment bash script"
  type        = list(string)
  default     = ["/bin/bash", "-c"]
}

variable "lambda_deployment_npm_path" {
  description = "Path to the Lambda deployment npm script"
  type        = string
  default     = "/usr/bin/npm"
}

variable "lambda_role_policies" {
  description = "Policies to add to the Lambda role"
  type        = list(string)
  default     = []
}

# ----------------------------------------------------------------------------------------------------------------------
# KMS
# ----------------------------------------------------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "Key to use for custom S3 encryption"
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------------------------------------------------
# S3
# ----------------------------------------------------------------------------------------------------------------------

# Bucket ---------------------------------------------------------------------------------------------------------------

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "s3_bucket_force_destroy" {
  description = "If the S3 bucket can be destroyed when it's not empty"
  type        = bool
  default     = true
}

# Encryption -----------------------------------------------------------------------------------------------------------

variable "s3_kms_encryption_enabled" {
  description = "If a KMS key should be used for bucket encryption. If this is true and no KMS key is passed, one is created by the module"
  type        = bool
  default     = false
}

# Versioning -----------------------------------------------------------------------------------------------------------

variable "s3_versioning_enabled" {
  description = "If bucket objects should remain after being overwritten"
  type        = bool
  default     = false
}

# Lifecycle ------------------------------------------------------------------------------------------------------------

variable "s3_lifecycle_enabled" {
  description = "If non current bucket object should be deleted after some time"
  type        = bool
  default     = false
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days after which to delete non current bucket objects"
  type        = number
  default     = 30

  validation {
    condition     = var.s3_lifecycle_enabled ? var.s3_lifecycle_expiration_days > 0 : true
    error_message = "If lifecycle is enabled, expiration days must be greater than 0"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
