<!-- BEGIN_TF_DOCS -->
# Cognito at Edge CloudFront Module

Terraform module which creates AWS resources that provision a CloudFront distribution with optional Cognito authentication at the edge.

## Usage

### Minimal deployment with Auth disabled
```hcl
module "cognito_at_edge_app" {
  source = "./modules/cognito-at-edge-app"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  # Module
  identifier = "cognito-at-edge-app"
  # CloudFront
  cf_aliases = ["yourdomain.com"]
  # S3
  s3_bucket_name = "<your-s3-bucket-name>"
  
}
```

### Minimal deployment with Auth enabled
```hcl
module "cognito_at_edge_app" {
  source = "./modules/cognito-at-edge-app"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  # Module
  identifier = "cognito-at-edge-app"
  # CloudFront
  cf_aliases = ["yourdomain.com"]
  # Cognito
  cognito_auth_enabled = true
  cognito_secrets_arn  = "<arn-of-secret-from-cognito-module>"
  cognito_key_arn      = "<arn-of-key-from-cognito-module>"
  # S3
  s3_bucket_name = "<your-s3-bucket-name>"
  
}
```

### Full deployment
```hcl
module "cognito_at_edge_app" {
  source = "./modules/cognito-at-edge-app"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  # Module
  identifier = "cognito-at-edge-app"
  tags = { "Project" = "Cognito at Edge" }
  # ACM
  acm_certificate_arn = "<your-acm-certificate-arn>" # created in us-east-1
  # CloudFront
  cf_aliases                = ["yourdomain.com"]
  cf_default_root_object    = "index.html"
  cf_origin_id              = "S3"
  cf_price_class            = "PriceClass_All"
  cf_http_version           = "http2"
  cf_ipv6_enabled           = true
  cf_web_acl_arn            = "<your-web-acl-arn>"
  cf_custom_error_responses = [{
    error_code            = 403
    response_page_path    = "/index.html"
    response_code         = 200
    error_caching_min_ttl = 0
  }]
  cf_restrictions = {
    geo_restriction = {
      restriction_type = "Whitelist"
      locations        = ["DE", "AT", "CH"]
    }
  }
  cf_certificate_minimum_protocol_version = "TLSv1.2_2021"
  cf_certificate_ssl_support_method       = "sni-only"
  cf_cache_behavior_default = {
    target_origin_id       = "S3"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    lambda_functions       = {
      viewer_request = {
        handler              = "index.handler"
        runtime              = "nodejs18.x"
        source_dir           = "<path-to-your-lambda>"
        include_body         = true
        install_dependencies = true
        config_file          = "config.json"
        config_content       = jsonencode({your = "json"})
      }
      viewer_response = {
        handler              = "index.handler"
        runtime              = "nodejs18.x"
        source_dir           = "<path-to-your-lambda>"
        include_body         = false
        install_dependencies = true
        config_file          = "config.json"
        config_content       = jsonencode({your = "json"})
      }
      origin_request = {
        handler              = "index.handler"
        runtime              = "nodejs18.x"
        source_dir           = "<path-to-your-lambda>"
        include_body         = true
        install_dependencies = true
        config_file          = "config.json"
        config_content       = jsonencode({your = "json"})
      }
      viewer_response = {
        handler              = "index.handler"
        runtime              = "nodejs18.x"
        source_dir           = "<path-to-your-lambda>"
        include_body         = true
        install_dependencies = true
        config_file          = "config.json"
        config_content       = jsonencode({your = "json"})
      }
    }
    cache_policy_id = "<your-cache-policy-id>"
    cache_policy    = {
      min_ttl     = 0
      max_ttl     = 31536000
      default_ttl = 86400
      parameters_in_cache_key_and_forwarded_to_origin = {
        cookies_config = {
            cookie_behavior = "Whitelist"
            cookies         = {
              items = ["cookie1", "cookie2"]
            }
        }
        headers_config = {
            header_behavior = "Whitelist"
            headers         = {
              items = ["header1", "header2"]
            }
        }
        query_strings_config = {
            query_string_behavior = "Whitelist"
            query_strings         = {
              items = ["query1", "query2"]
            }
        }
      }
    }
    origin_request_policy_id = "<your-origin-request-policy-id>"
    origin_request_policy = {
        cookies_config = {
            cookie_behavior = "Whitelist"
            cookies         = {
            items = ["cookie1", "cookie2"]
            }
        }
        headers_config = {
            header_behavior = "Whitelist"
            headers         = {
            items = ["header1", "header2"]
            }
        }
        query_strings_config = {
            query_string_behavior = "Whitelist"
            query_strings         = {
            items = ["query1", "query2"]
            }
        }
    }
    response_headers_policy_id = "<your-response-headers-policy-id>"
    response_headers_policy = {
      cors_config = {
        access_control_allow_credentials =  true
        access_control_max_age_sec       = 3600
        origin_override                  = true
        access_control_allow_headers = {
          items = ["test"]
        }
        access_control_allow_methods = {
          items = ["GET"]
        }
        access_control_allow_origins = {
          items = ["test.example.comtest"]
        }
        access_control_expose_headers = {
          items = ["Header-Name"]
        }
      }
      custom_headers_config = {
        items = [
          {
            header   = "X-Test"
            override = true
            value    = "none"
          },
          {
            header   = "X-Permitted-Cross-Domain-Policies"
            override = true
            value    = "none"
          }
        ]
      }
      remove_headers_config = {
        items = [
          {
            header = "X-Powered-By"
          },
          {
            header = "X-Frame-Options"
          }
        ]
      }
      security_headers_config = {
        content_security_policy = {
          content_security_policy = "frame-ancestors 'none'; default-src 'none'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'"
          override = true
        }
        content_type_options = {
          override = true
        }
        frame_options = {
          override     = true
          frame_option = "DENY"
        }
        referrer_policy = {
          referrer_policy = "same-origin"
          override = true
        }
        strict_transport_security = {
          access_control_max_age_sec = 63072000
          include_subdomains         = true
          override                   = true
          preload                    = true
        }
        xss_protection = {
          mode_block = true
          protection = true
          override   = true
        }
      }
      server_timing_headers_config = {
        enabled       = true
        sampling_rate = 50
      }
    }
  }
  cache_behaviors_ordered = [
    {
      path_pattern = "/your-path"
      # Same options as cf_cache_behavior_default
    },
    {
      path_pattern = "/your-other-path"
      # Same options as cf_cache_behavior_default
    }
  ]
  # Cognito
  cognito_auth_enabled = true
  cognito_groups       = ["administrator", "developers"]
  cognito_whitelist    = ["127.0.0.1/32"]
  cognito_login_path   = "/your-custom-login-path"
  cognito_refresh_path = "/your-custom-refresh-path"
  cognito_secrets_arn  = "<arn-of-secret-from-cognito-module>"
  cognito_key_arn      = "<arn-of-key-from-cognito-module>"
  # Lambda
  lambda_deployment_package_path     = "/your-custom-lambda-deployment-package-path"
  lambda_deployment_bash_interpreter = ["/path-to-your-bash-interpreter", "your-bash-args"]
  lambda_deployment_npm_path         = "/path-to-your-npm-executable"
  lambda_role_policies               = [
    "<policy-to-attach-to-lambda-role-as-json-string-1>",
    "<policy-to-attach-to-lambda-role-as-json-string-2>"
  ]
  # KMS
  kms_key_arn = "<your-kms-key-arn>"
  # S3
  s3_bucket_name               = "<your-s3-bucket-name>"
  s3_bucket_force_destroy      = true  
  s3_kms_encryption_enabled    = true  
  s3_versioning_enabled        = true  
  s3_lifecycle_enabled         = true
  s3_lifecycle_expiration_days = 30
  
}
```
      

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |
| <a name="provider_aws.us_east_1"></a> [aws.us\_east\_1](#provider\_aws.us\_east\_1) | ~> 5.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [archive_file.lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/resources/file) | resource |
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudfront_cache_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_cache_policy.ordered](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_origin_request_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy) | resource |
| [aws_cloudfront_origin_request_policy.ordered](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy) | resource |
| [aws_cloudfront_response_headers_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_cloudfront_response_headers_policy.ordered](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.acm_error_on_missing_zone](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.lambda](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route53_zones.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ACM Certificate to use with CloudFront. Leave this empty for the module to provision the certificate itself | `string` | `null` | no |
| <a name="input_cf_aliases"></a> [cf\_aliases](#input\_cf\_aliases) | Domains to add to the CloudFront distribution | `list(string)` | n/a | yes |
| <a name="input_cf_cache_behavior_default"></a> [cf\_cache\_behavior\_default](#input\_cf\_cache\_behavior\_default) | Default CloudFront cache behavior | <pre>object({<br/>    allowed_methods        = optional(list(string), ["GET", "HEAD"])<br/>    cached_methods         = optional(list(string), ["GET", "HEAD"])<br/>    target_origin_id       = optional(string, "S3")<br/>    viewer_protocol_policy = optional(string, "redirect-to-https")<br/>    compress               = optional(bool, false)<br/>    # Lambda Functions<br/>    lambda_functions = optional(object({<br/>      viewer_request = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      viewer_response = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      origin_request = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      origin_response = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>    }), {})<br/>    # Cache Policy<br/>    cache_policy_id = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6") # CachingOptimized<br/>    cache_policy = optional(object({<br/>      min_ttl     = optional(number, 0)<br/>      max_ttl     = optional(number, 31536000)<br/>      default_ttl = optional(number, 86400)<br/>      parameters_in_cache_key_and_forwarded_to_origin = optional(object({<br/>        cookies_config                = optional(any)<br/>        headers_config                = optional(any)<br/>        query_strings_config          = optional(any)<br/>        enable_accept_encoding_brotli = optional(bool, false)<br/>        enable_accept_encoding_gzip   = optional(bool, false)<br/>      }))<br/>    }))<br/>    # Origin Request Policy<br/>    origin_request_policy_id = optional(string)<br/>    origin_request_policy = optional(object({<br/>      cookies_config       = optional(any)<br/>      headers_config       = optional(any)<br/>      query_strings_config = optional(any)<br/>    }))<br/>    # Response Headers Policy<br/>    response_headers_policy_id = optional(string)<br/>    response_headers_policy = optional(object({<br/>      cors_config                  = optional(any)<br/>      custom_headers_config        = optional(any)<br/>      remove_headers_config        = optional(any)<br/>      security_headers_config      = optional(any)<br/>      server_timing_headers_config = optional(any)<br/>    }))<br/>  })</pre> | `{}` | no |
| <a name="input_cf_cache_behaviors_ordered"></a> [cf\_cache\_behaviors\_ordered](#input\_cf\_cache\_behaviors\_ordered) | Ordered CloudFront cache behaviors | <pre>list(object({<br/>    path_pattern           = string<br/>    allowed_methods        = optional(list(string), ["GET", "HEAD"])<br/>    cached_methods         = optional(list(string), ["GET", "HEAD"])<br/>    target_origin_id       = optional(string, "S3")<br/>    viewer_protocol_policy = optional(string, "redirect-to-https")<br/>    compress               = optional(bool, false)<br/>    # Lambda Functions<br/>    lambda_functions = optional(object({<br/>      viewer_request = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      viewer_response = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      origin_request = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>      origin_response = optional(object({<br/>        handler              = optional(string, "index.handler")<br/>        runtime              = optional(string, "nodejs18.x")<br/>        source_dir           = string<br/>        include_body         = optional(bool, false)<br/>        install_dependencies = optional(bool, false)<br/>        config_file          = optional(string, "config.json")<br/>        config_content       = optional(string, "{}")<br/>      }))<br/>    }), {})<br/>    # Cache Policy<br/>    cache_policy_id = optional(string)<br/>    cache_policy = optional(object({<br/>      min_ttl     = optional(number, 0)<br/>      max_ttl     = optional(number, 31536000)<br/>      default_ttl = optional(number, 86400)<br/>      parameters_in_cache_key_and_forwarded_to_origin = optional(object({<br/>        cookies_config                = optional(any)<br/>        headers_config                = optional(any)<br/>        query_strings_config          = optional(any)<br/>        enable_accept_encoding_brotli = optional(bool, false)<br/>        enable_accept_encoding_gzip   = optional(bool, false)<br/>      }))<br/>    }))<br/>    # Origin Request Policy<br/>    origin_request_policy_id = optional(string)<br/>    origin_request_policy = optional(object({<br/>      cookies_config       = optional(any)<br/>      headers_config       = optional(any)<br/>      query_strings_config = optional(any)<br/>    }))<br/>    # Response Headers Policy<br/>    response_headers_policy_id = optional(string)<br/>    response_headers_policy = optional(object({<br/>      cors_config                  = optional(any)<br/>      custom_headers_config        = optional(any)<br/>      remove_headers_config        = optional(any)<br/>      security_headers_config      = optional(any)<br/>      server_timing_headers_config = optional(any)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_cf_certificate_minimum_protocol_version"></a> [cf\_certificate\_minimum\_protocol\_version](#input\_cf\_certificate\_minimum\_protocol\_version) | Minimum TLS version of the SSL certificate | `string` | `"TLSv1.2_2021"` | no |
| <a name="input_cf_certificate_ssl_support_method"></a> [cf\_certificate\_ssl\_support\_method](#input\_cf\_certificate\_ssl\_support\_method) | Method used to serve HTTPs requests | `string` | `"sni-only"` | no |
| <a name="input_cf_custom_error_responses"></a> [cf\_custom\_error\_responses](#input\_cf\_custom\_error\_responses) | List of error responses for the CloudFront distribution | <pre>list(object({<br/>    error_caching_min_ttl = optional(number)<br/>    error_code            = number<br/>    response_code         = optional(string)<br/>    response_page_path    = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_cf_default_root_object"></a> [cf\_default\_root\_object](#input\_cf\_default\_root\_object) | CloudFront origin default object | `string` | `"index.html"` | no |
| <a name="input_cf_http_version"></a> [cf\_http\_version](#input\_cf\_http\_version) | HTTP version for the CloudFront distribution | `string` | `"http2"` | no |
| <a name="input_cf_ipv6_enabled"></a> [cf\_ipv6\_enabled](#input\_cf\_ipv6\_enabled) | If IPv6 should be enabled for the CloudFront distribution | `bool` | `true` | no |
| <a name="input_cf_origin_id"></a> [cf\_origin\_id](#input\_cf\_origin\_id) | Origin ID to use for the CloudFront distribution | `string` | `"S3"` | no |
| <a name="input_cf_price_class"></a> [cf\_price\_class](#input\_cf\_price\_class) | Price class for the CloudFront distribution | `string` | `"PriceClass_All"` | no |
| <a name="input_cf_restrictions"></a> [cf\_restrictions](#input\_cf\_restrictions) | Restrictions to apply to the CloudFront distribution | <pre>object({<br/>    geo_restriction = object({<br/>      restriction_type = string<br/>      locations        = list(string)<br/>    })<br/>  })</pre> | <pre>{<br/>  "geo_restriction": {<br/>    "locations": [],<br/>    "restriction_type": "none"<br/>  }<br/>}</pre> | no |
| <a name="input_cf_web_acl_arn"></a> [cf\_web\_acl\_arn](#input\_cf\_web\_acl\_arn) | WAF Web ACL to associate with the CloudFront distribution | `string` | `null` | no |
| <a name="input_cognito_auth_enabled"></a> [cognito\_auth\_enabled](#input\_cognito\_auth\_enabled) | If Cognito authentication should be enabled | `bool` | `false` | no |
| <a name="input_cognito_groups"></a> [cognito\_groups](#input\_cognito\_groups) | Allowed Cognito groups | `list(string)` | `[]` | no |
| <a name="input_cognito_key_arn"></a> [cognito\_key\_arn](#input\_cognito\_key\_arn) | ARN of the KMS key to use for Cognito | `string` | `null` | no |
| <a name="input_cognito_login_path"></a> [cognito\_login\_path](#input\_cognito\_login\_path) | Path to redirect to after login | `string` | `"/auth-login"` | no |
| <a name="input_cognito_refresh_path"></a> [cognito\_refresh\_path](#input\_cognito\_refresh\_path) | Path to redirect to after refresh | `string` | `"/auth-refresh"` | no |
| <a name="input_cognito_secret_arn"></a> [cognito\_secret\_arn](#input\_cognito\_secret\_arn) | ARN of the Cognito secret | `string` | `null` | no |
| <a name="input_cognito_whitelist"></a> [cognito\_whitelist](#input\_cognito\_whitelist) | IPs to bypass Cognito authentication | `list(string)` | `[]` | no |
| <a name="input_identifier"></a> [identifier](#input\_identifier) | Identifier to add to named resources | `string` | n/a | yes |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Key to use for custom S3 encryption | `string` | `null` | no |
| <a name="input_lambda_deployment_bash_interpreter"></a> [lambda\_deployment\_bash\_interpreter](#input\_lambda\_deployment\_bash\_interpreter) | Path to the Lambda deployment bash script | `list(string)` | <pre>[<br/>  "/bin/bash",<br/>  "-c"<br/>]</pre> | no |
| <a name="input_lambda_deployment_npm_path"></a> [lambda\_deployment\_npm\_path](#input\_lambda\_deployment\_npm\_path) | Path to the Lambda deployment npm script | `string` | `"/usr/bin/npm"` | no |
| <a name="input_lambda_deployment_package_path"></a> [lambda\_deployment\_package\_path](#input\_lambda\_deployment\_package\_path) | Path to the Lambda deployment package | `string` | `"/packages"` | no |
| <a name="input_lambda_role_policies"></a> [lambda\_role\_policies](#input\_lambda\_role\_policies) | Policies to add to the Lambda role | `list(string)` | `[]` | no |
| <a name="input_s3_bucket_force_destroy"></a> [s3\_bucket\_force\_destroy](#input\_s3\_bucket\_force\_destroy) | If the S3 bucket can be destroyed when it's not empty | `bool` | `true` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket | `string` | n/a | yes |
| <a name="input_s3_kms_encryption_enabled"></a> [s3\_kms\_encryption\_enabled](#input\_s3\_kms\_encryption\_enabled) | If a KMS key should be used for bucket encryption. If this is true and no KMS key is passed, one is created by the module | `bool` | `false` | no |
| <a name="input_s3_lifecycle_enabled"></a> [s3\_lifecycle\_enabled](#input\_s3\_lifecycle\_enabled) | If non current bucket object should be deleted after some time | `bool` | `false` | no |
| <a name="input_s3_lifecycle_expiration_days"></a> [s3\_lifecycle\_expiration\_days](#input\_s3\_lifecycle\_expiration\_days) | Number of days after which to delete non current bucket objects | `number` | `30` | no |
| <a name="input_s3_versioning_enabled"></a> [s3\_versioning\_enabled](#input\_s3\_versioning\_enabled) | If bucket objects should remain after being overwritten | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to add to each resource | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->