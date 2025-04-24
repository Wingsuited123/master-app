# ----------------------------------------------------------------------------------------------------------------------
# CloudFront
# ----------------------------------------------------------------------------------------------------------------------

# Distribution ---------------------------------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "this" {

  aliases             = var.cf_aliases
  default_root_object = var.cf_default_root_object
  price_class         = var.cf_price_class
  http_version        = var.cf_http_version
  is_ipv6_enabled     = var.cf_ipv6_enabled
  web_acl_id          = var.cf_web_acl_arn
  enabled             = true
  wait_for_deployment = false

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = var.cf_origin_id
  }

  default_cache_behavior {
    allowed_methods        = local.cache_behavior_default.allowed_methods
    cached_methods         = local.cache_behavior_default.cached_methods
    target_origin_id       = local.cache_behavior_default.target_origin_id
    viewer_protocol_policy = local.cache_behavior_default.viewer_protocol_policy
    compress               = local.cache_behavior_default.compress

    cache_policy_id            = try(coalesce(one(aws_cloudfront_cache_policy.default[*].id), local.cache_behavior_default.cache_policy_id), null)
    origin_request_policy_id   = try(coalesce(one(aws_cloudfront_origin_request_policy.default[*].id), local.cache_behavior_default.origin_request_policy_id), null)
    response_headers_policy_id = try(coalesce(one(aws_cloudfront_response_headers_policy.default[*].id), local.cache_behavior_default.response_headers_policy_id), null)

    dynamic "lambda_function_association" {
      for_each = [for type, func in local.cache_behavior_default.lambda_functions : merge(func, { event_type = type, name = "${var.identifier}-${type}" }) if func != null]

      content {
        event_type   = replace(lambda_function_association.value.event_type, "_", "-")
        lambda_arn   = aws_lambda_function.this[lambda_function_association.value.name].qualified_arn
        include_body = lambda_function_association.value.include_body
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.cache_behaviors_ordered

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      compress               = ordered_cache_behavior.value.compress

      cache_policy_id            = try(aws_cloudfront_cache_policy.ordered[ordered_cache_behavior.value.path_pattern].id, ordered_cache_behavior.value.cache_policy_id)
      origin_request_policy_id   = try(aws_cloudfront_origin_request_policy.ordered[ordered_cache_behavior.value.path_pattern].id, ordered_cache_behavior.value.origin_request_policy_id)
      response_headers_policy_id = try(aws_cloudfront_response_headers_policy.ordered[ordered_cache_behavior.value.path_pattern].id, ordered_cache_behavior.value.response_headers_policy_id)

      dynamic "lambda_function_association" {
        for_each = [for type, func in ordered_cache_behavior.value.lambda_functions : merge(func, { event_type = type, name = "${var.identifier}-${replace(replace(ordered_cache_behavior.value.path_pattern, "/", "_"), "/[^a-zA-Z0-9-_]/", "")}-${type}" }) if func != null]

        content {
          event_type   = replace(lambda_function_association.value.event_type, "_", "-")
          lambda_arn   = aws_lambda_function.this[lambda_function_association.value.name].qualified_arn
          include_body = lambda_function_association.value.include_body
        }
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cf_restrictions.geo_restriction.restriction_type
      locations        = var.cf_restrictions.geo_restriction.locations
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.acm_certificate_arn
    minimum_protocol_version = var.cf_certificate_minimum_protocol_version
    ssl_support_method       = var.cf_certificate_ssl_support_method
  }

  dynamic "custom_error_response" {
    for_each = var.cf_custom_error_responses
    content {
      error_caching_min_ttl = coalesce(custom_error_response.value.error_caching_min_ttl, 0)
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
    }
  }

  tags = var.tags
}

# Origin Access Control ------------------------------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "S3-${var.identifier}"
  description                       = "Sign all requests to S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Policies -------------------------------------------------------------------------------------------------------------

# Cache

resource "aws_cloudfront_cache_policy" "default" {
  count = local.cache_behavior_default.cache_policy != null ? 1 : 0

  name    = "${var.identifier}-origin-request-policy-default"
  comment = "Default cache policy for ${var.identifier}"

  min_ttl     = local.cache_behavior_default.cache_policy.min_ttl
  max_ttl     = local.cache_behavior_default.cache_policy.max_ttl
  default_ttl = local.cache_behavior_default.cache_policy.default_ttl

  dynamic "parameters_in_cache_key_and_forwarded_to_origin" {
    for_each = [for value in [local.cache_behavior_default.cache_policy.parameters_in_cache_key_and_forwarded_to_origin] : value if value != null]
    content {
      dynamic "cookies_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.cookies_config] : value if value != null]
        content {
          cookie_behavior = lookup(cookies_config.value, "cookie_behavior", null)

          dynamic "cookies" {
            for_each = [for value in [lookup(cookies_config.value, "cookies", null)] : value if value != null]
            content {
              items = lookup(cookies.value, "items", null)
            }
          }
        }
      }

      dynamic "headers_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.headers_config] : value if value != null]
        content {
          header_behavior = lookup(headers_config.value, "header_behavior", null)

          dynamic "headers" {
            for_each = [for value in [lookup(headers_config.value, "headers", null)] : value if value != null]
            content {
              items = lookup(headers.value, "items", null)
            }
          }
        }
      }

      dynamic "query_strings_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.query_strings_config] : value if value != null]
        content {
          query_string_behavior = lookup(query_strings_config.value, "query_string_behavior", null)

          dynamic "query_strings" {
            for_each = [for value in [lookup(query_strings_config.value, "query_strings", null)] : value if value != null]
            content {
              items = lookup(query_strings.value, "items", null)
            }
          }
        }
      }
      enable_accept_encoding_brotli = parameters_in_cache_key_and_forwarded_to_origin.value.enable_accept_encoding_brotli
      enable_accept_encoding_gzip   = parameters_in_cache_key_and_forwarded_to_origin.value.enable_accept_encoding_gzip
    }
  }
}

resource "aws_cloudfront_cache_policy" "ordered" {
  for_each = { for behavior in local.cache_behaviors_ordered : behavior.path_pattern => behavior if behavior.cache_policy != null }

  name    = "${var.identifier}-origin-request-policy-ordered-${each.value.path_pattern}"
  comment = "Cache policy for ${var.identifier} with path pattern ${each.value.path_pattern}"

  min_ttl     = each.value.cache_policy.min_ttl
  max_ttl     = each.value.cache_policy.max_ttl
  default_ttl = each.value.cache_policy.default_ttl

  dynamic "parameters_in_cache_key_and_forwarded_to_origin" {
    for_each = [for value in [each.value.cache_policy.parameters_in_cache_key_and_forwarded_to_origin] : value if value != null]
    content {
      dynamic "cookies_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.cookies_config] : value if value != null]
        content {
          cookie_behavior = lookup(cookies_config.value, "cookie_behavior", null)

          dynamic "cookies" {
            for_each = [for value in [lookup(cookies_config.value, "cookies", null)] : value if value != null]
            content {
              items = lookup(cookies.value, "items", null)
            }
          }
        }
      }

      dynamic "headers_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.headers_config] : value if value != null]
        content {
          header_behavior = lookup(headers_config.value, "header_behavior", null)

          dynamic "headers" {
            for_each = [for value in [lookup(headers_config.value, "headers", null)] : value if value != null]
            content {
              items = lookup(headers.value, "items", null)
            }
          }
        }
      }

      dynamic "query_strings_config" {
        for_each = [for value in [parameters_in_cache_key_and_forwarded_to_origin.value.query_strings_config] : value if value != null]
        content {
          query_string_behavior = lookup(query_strings_config.value, "query_string_behavior", null)

          dynamic "query_strings" {
            for_each = [for value in [lookup(query_strings_config.value, "query_strings", null)] : value if value != null]
            content {
              items = lookup(query_strings.value, "items", null)
            }
          }
        }
      }
      enable_accept_encoding_brotli = parameters_in_cache_key_and_forwarded_to_origin.value.enable_accept_encoding_brotli
      enable_accept_encoding_gzip   = parameters_in_cache_key_and_forwarded_to_origin.value.enable_accept_encoding_gzip
    }
  }
}

# Origin Request

resource "aws_cloudfront_origin_request_policy" "default" {
  count = local.cache_behavior_default.origin_request_policy != null ? 1 : 0

  name    = "${var.identifier}-origin-request-policy-default"
  comment = "Default origin request policy for ${var.identifier}"

  dynamic "cookies_config" {
    for_each = [for value in [local.cache_behavior_default.origin_request_policy.cookies_config] : value if value != null]
    content {
      cookie_behavior = lookup(cookies_config.value, "cookie_behavior", null)

      dynamic "cookies" {
        for_each = [for value in [lookup(cookies_config.value, "cookies", null)] : value if value != null]
        content {
          items = lookup(cookies.value, "items", null)
        }
      }
    }
  }

  dynamic "headers_config" {
    for_each = [for value in [local.cache_behavior_default.origin_request_policy.headers_config] : value if value != null]
    content {
      header_behavior = lookup(headers_config.value, "header_behavior", null)

      dynamic "headers" {
        for_each = [for value in [lookup(headers_config.value, "headers", null)] : value if value != null]
        content {
          items = lookup(headers.value, "items", null)
        }
      }
    }
  }

  dynamic "query_strings_config" {
    for_each = [for value in [local.cache_behavior_default.origin_request_policy.query_strings_config] : value if value != null]
    content {
      query_string_behavior = lookup(query_strings_config.value, "query_string_behavior", null)

      dynamic "query_strings" {
        for_each = [for value in [lookup(query_strings_config.value, "query_strings", null)] : value if value != null]
        content {
          items = lookup(query_strings.value, "items", null)
        }
      }
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "ordered" {
  for_each = { for behavior in local.cache_behaviors_ordered : behavior.path_pattern => behavior if behavior.origin_request_policy != null }

  name    = "${var.identifier}-origin-request-policy-ordered-${each.value.path_pattern}"
  comment = "Origin request policy for ${var.identifier} with path pattern ${each.value.path_pattern}"

  dynamic "cookies_config" {
    for_each = [for value in [each.value.origin_request_policy.cookies_config] : value if value != null]
    content {
      cookie_behavior = lookup(cookies_config.value, "cookie_behavior", null)

      dynamic "cookies" {
        for_each = [for value in [lookup(cookies_config.value, "cookies", null)] : value if value != null]
        content {
          items = lookup(cookies.value, "items", null)
        }
      }
    }
  }

  dynamic "headers_config" {
    for_each = [for value in [each.value.origin_request_policy.headers_config] : value if value != null]
    content {
      header_behavior = lookup(headers_config.value, "header_behavior", null)

      dynamic "headers" {
        for_each = [for value in [lookup(headers_config.value, "headers", null)] : value if value != null]
        content {
          items = lookup(headers.value, "items", null)
        }
      }
    }
  }

  dynamic "query_strings_config" {
    for_each = [for value in [each.value.origin_request_policy.query_strings_config] : value if value != null]
    content {
      query_string_behavior = lookup(query_strings_config.value, "query_string_behavior", null)

      dynamic "query_strings" {
        for_each = [for value in [lookup(query_strings_config.value, "query_strings", null)] : value if value != null]
        content {
          items = lookup(query_strings.value, "items", null)
        }
      }
    }
  }
}

# Response Headers

resource "aws_cloudfront_response_headers_policy" "default" {
  count = local.cache_behavior_default.response_headers_policy != null ? 1 : 0

  name    = "${var.identifier}-response-headers-policy-default"
  comment = "Default response headers policy for ${var.identifier}"

  dynamic "cors_config" {
    for_each = [for value in [local.cache_behavior_default.response_headers_policy.cors_config] : value if value != null]
    content {
      access_control_allow_credentials = lookup(cors_config.value, "access_control_allow_credentials", null)
      access_control_max_age_sec       = lookup(cors_config.value, "access_control_max_age_sec", null)
      origin_override                  = lookup(cors_config.value, "origin_override", null)

      dynamic "access_control_allow_headers" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_headers", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_headers.value, "items", null)
        }
      }

      dynamic "access_control_allow_methods" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_methods", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_methods.value, "items", null)
        }
      }

      dynamic "access_control_allow_origins" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_origins", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_origins.value, "items", null)
        }
      }

      dynamic "access_control_expose_headers" {
        for_each = [for value in [lookup(cors_config.value, "access_control_expose_headers", null)] : value if value != null]
        content {
          items = lookup(access_control_expose_headers.value, "items", null)
        }
      }
    }
  }

  dynamic "custom_headers_config" {
    for_each = [for value in [local.cache_behavior_default.response_headers_policy.custom_headers_config] : value if value != null]
    content {
      dynamic "items" {
        for_each = [for value in lookup(custom_headers_config.value, "items", null) : value if value != null]
        content {
          header   = lookup(items.value, "header", null)
          override = lookup(items.value, "override", null)
          value    = lookup(items.value, "value", null)
        }
      }
    }
  }

  dynamic "remove_headers_config" {
    for_each = [for value in [local.cache_behavior_default.response_headers_policy.remove_headers_config] : value if value != null]
    content {
      dynamic "items" {
        for_each = [for value in lookup(remove_headers_config.value, "items", null) : value if value != null]
        content {
          header = lookup(items.value, "header", null)
        }
      }
    }
  }

  dynamic "security_headers_config" {
    for_each = [for value in [local.cache_behavior_default.response_headers_policy.security_headers_config] : value if value != null]
    content {
      dynamic "content_security_policy" {
        for_each = [for value in [lookup(security_headers_config.value, "content_security_policy", null)] : value if value != null]
        content {
          content_security_policy = lookup(content_security_policy.value, "content_security_policy", null)
          override                = lookup(content_security_policy.value, "override", null)
        }
      }

      dynamic "content_type_options" {
        for_each = [for value in [lookup(security_headers_config.value, "content_type_options", null)] : value if value != null]
        content {
          override = lookup(content_type_options.value, "override", null)
        }
      }

      dynamic "frame_options" {
        for_each = [for value in [lookup(security_headers_config.value, "frame_options", null)] : value if value != null]
        content {
          frame_option = lookup(frame_options.value, "frame_option", null)
          override     = lookup(frame_options.value, "override", null)
        }
      }

      dynamic "referrer_policy" {
        for_each = [for value in [lookup(security_headers_config.value, "referrer_policy", null)] : value if value != null]
        content {
          referrer_policy = lookup(referrer_policy.value, "referrer_policy", null)
          override        = lookup(referrer_policy.value, "override", null)
        }
      }

      dynamic "strict_transport_security" {
        for_each = [for value in [lookup(security_headers_config.value, "strict_transport_security", null)] : value if value != null]
        content {
          access_control_max_age_sec = lookup(strict_transport_security.value, "access_control_max_age_sec", null)
          include_subdomains         = lookup(strict_transport_security.value, "include_subdomains", null)
          override                   = lookup(strict_transport_security.value, "override", null)
          preload                    = lookup(strict_transport_security.value, "preload", null)
        }
      }

      dynamic "xss_protection" {
        for_each = [for value in [lookup(security_headers_config.value, "xss_protection", null)] : value if value != null]
        content {
          mode_block = lookup(xss_protection.value, "mode_block", null)
          override   = lookup(xss_protection.value, "override", null)
          protection = lookup(xss_protection.value, "protection", null)
          report_uri = lookup(xss_protection.value, "report_uri", null)
        }
      }
    }
  }

  dynamic "server_timing_headers_config" {
    for_each = [for value in [local.cache_behavior_default.response_headers_policy.server_timing_headers_config] : value if value != null]
    content {
      enabled       = lookup(server_timing_headers_config.value, "enabled", null)
      sampling_rate = lookup(server_timing_headers_config.value, "sampling_rate", null)
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "ordered" {
  for_each = { for behavior in local.cache_behaviors_ordered : behavior.path_pattern => behavior if behavior.response_headers_policy != null }

  name    = "${var.identifier}-response-headers-policy-ordered-${each.value.path_pattern}"
  comment = "Response headers policy for ${var.identifier} with ${each.value.path_pattern}"

  dynamic "cors_config" {
    for_each = [for value in [each.value.response_headers_policy.cors_config] : value if value != null]
    content {
      access_control_allow_credentials = lookup(cors_config.value, "access_control_allow_credentials", null)
      access_control_max_age_sec       = lookup(cors_config.value, "access_control_max_age_sec", null)
      origin_override                  = lookup(cors_config.value, "origin_override", null)

      dynamic "access_control_allow_headers" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_headers", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_headers.value, "items", null)
        }
      }

      dynamic "access_control_allow_methods" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_methods", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_methods.value, "items", null)
        }
      }

      dynamic "access_control_allow_origins" {
        for_each = [for value in [lookup(cors_config.value, "access_control_allow_origins", null)] : value if value != null]
        content {
          items = lookup(access_control_allow_origins.value, "items", null)
        }
      }

      dynamic "access_control_expose_headers" {
        for_each = [for value in [lookup(cors_config.value, "access_control_expose_headers", null)] : value if value != null]
        content {
          items = lookup(access_control_expose_headers.value, "items", null)
        }
      }
    }
  }

  dynamic "custom_headers_config" {
    for_each = [for value in [each.value.response_headers_policy.custom_headers_config] : value if value != null]
    content {
      dynamic "items" {
        for_each = [for value in [lookup(custom_headers_config.value, "items", null)] : value if value != null]
        content {
          header   = lookup(items.value, "header", null)
          override = lookup(items.value, "override", null)
          value    = lookup(items.value, "value", null)
        }
      }
    }
  }

  dynamic "remove_headers_config" {
    for_each = [for value in [each.value.response_headers_policy.remove_headers_config] : value if value != null]
    content {
      dynamic "items" {
        for_each = [for value in [lookup(remove_headers_config.value, "items", null)] : value if value != null]
        content {
          header = lookup(items.value, "header", null)
        }
      }
    }
  }

  dynamic "security_headers_config" {
    for_each = [for value in [each.value.response_headers_policy.security_headers_config] : value if value != null]
    content {
      dynamic "content_security_policy" {
        for_each = [for value in [lookup(security_headers_config.value, "content_security_policy", null)] : value if value != null]
        content {
          content_security_policy = lookup(content_security_policy.value, "content_security_policy", null)
          override                = lookup(content_security_policy.value, "override", null)
        }
      }

      dynamic "content_type_options" {
        for_each = [for value in [lookup(security_headers_config.value, "content_type_options", null)] : value if value != null]
        content {
          override = lookup(content_type_options.value, "override", null)
        }
      }

      dynamic "frame_options" {
        for_each = [for value in [lookup(security_headers_config.value, "frame_options", null)] : value if value != null]
        content {
          frame_option = lookup(frame_options.value, "frame_option", null)
          override     = lookup(frame_options.value, "override", null)
        }
      }

      dynamic "referrer_policy" {
        for_each = [for value in [lookup(security_headers_config.value, "referrer_policy", null)] : value if value != null]
        content {
          referrer_policy = lookup(referrer_policy.value, "referrer_policy", null)
          override        = lookup(referrer_policy.value, "override", null)
        }
      }

      dynamic "strict_transport_security" {
        for_each = [for value in [lookup(security_headers_config.value, "strict_transport_security", null)] : value if value != null]
        content {
          access_control_max_age_sec = lookup(strict_transport_security.value, "access_control_max_age_sec", null)
          include_subdomains         = lookup(strict_transport_security.value, "include_subdomains", null)
          override                   = lookup(strict_transport_security.value, "override", null)
          preload                    = lookup(strict_transport_security.value, "preload", null)
        }
      }

      dynamic "xss_protection" {
        for_each = [for value in [lookup(security_headers_config.value, "xss_protection", null)] : value if value != null]
        content {
          mode_block = lookup(xss_protection.value, "mode_block", null)
          override   = lookup(xss_protection.value, "override", null)
          protection = lookup(xss_protection.value, "protection", null)
          report_uri = lookup(xss_protection.value, "report_uri", null)
        }
      }
    }
  }

  dynamic "server_timing_headers_config" {
    for_each = [for value in [each.value.response_headers_policy.server_timing_headers_config] : value if value != null]
    content {
      enabled       = lookup(server_timing_headers_config.value, "enabled", null)
      sampling_rate = lookup(server_timing_headers_config.value, "sampling_rate", null)
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
