# ----------------------------------------------------------------------------------------------------------------------
# Lambda
# ----------------------------------------------------------------------------------------------------------------------

# Function -------------------------------------------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  for_each = { for func in local.lambda_functions : func.name => func }

  provider = aws.us_east_1

  function_name = each.value.name
  handler       = each.value.handler
  runtime       = each.value.runtime
  role          = aws_iam_role.this.arn
  publish       = true

  filename         = archive_file.lambda[each.key].output_path
  source_code_hash = archive_file.lambda[each.key].output_base64sha256

  tags = var.tags
}

# Archive --------------------------------------------------------------------------------------------------------------

resource "archive_file" "lambda" {
  for_each = { for func in local.lambda_functions : func.name => func }

  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.module}${var.lambda_deployment_package_path}/${each.value.name}.zip"

  lifecycle {
    replace_triggered_by = [terraform_data.lambda[each.key]]
  }
}

# Terraform Data -------------------------------------------------------------------------------------------------------

resource "terraform_data" "lambda" {
  for_each = { for func in local.lambda_functions : func.name => func }

  input            = sha256(jsonencode(merge(each.value, { app = filesha256("${each.value.source_dir}/${split(".", each.value.handler)[0]}.js") }, each.value.install_dependencies ? { package = filesha256("${each.value.source_dir}/package.json") } : {})))
  triggers_replace = sha256(jsonencode(merge(each.value, { app = filesha256("${each.value.source_dir}/${split(".", each.value.handler)[0]}.js") }, each.value.install_dependencies ? { package = filesha256("${each.value.source_dir}/package.json") } : {})))

  provisioner "local-exec" {
    interpreter = var.lambda_deployment_bash_interpreter
    command     = "cd \"$SOURCE_DIR\" && \"$INSTALL_CMD\" $INSTALL_ARGS && echo \"$CONFIG_CONTENT\" > $CONFIG_FILE"
    environment = {
      SOURCE_DIR     = each.value.source_dir
      INSTALL_CMD    = each.value.install_dependencies ? var.lambda_deployment_npm_path : "true"
      INSTALL_ARGS   = each.value.install_dependencies ? "install" : "true"
      CONFIG_CONTENT = each.value.config_content
      CONFIG_FILE    = each.value.config_file
    }
  }
}

# Locals ---------------------------------------------------------------------------------------------------------------

locals {
  lambda_functions         = concat(local.lambda_functions_default, local.lambda_functions_ordered)
  lambda_functions_default = [for type, func in local.cache_behavior_default.lambda_functions : merge(func, { name = "${var.identifier}-${type}" }) if func != null]
  lambda_functions_ordered = flatten([for behavior in local.cache_behaviors_ordered : [for type, func in behavior.lambda_functions : merge(func, { name = "${var.identifier}-${replace(replace(behavior.path_pattern, "/", "_"), "/[^a-zA-Z0-9-_]/", "")}-${type}" }) if func != null]])
}

locals {
  cache_behavior_default  = merge(var.cf_cache_behavior_default, local.cache_behavior_default_templates)
  cache_behaviors_ordered = concat(var.cf_cache_behaviors_ordered, [for behavior in local.cache_behaviors_ordered_templates : behavior.template if behavior.condition])

  cache_behavior_default_templates = {
    lambda_functions = merge(var.cf_cache_behavior_default.lambda_functions, {
      viewer_request = local.lambda_authentication_enabled ? local.lambda_authentication : var.cf_cache_behavior_default.lambda_functions.viewer_request
    })
  }

  cache_behaviors_ordered_templates = [
    {
      condition = local.lambda_authentication_enabled
      template  = local.cache_behavior_login
    },
    {
      condition = local.lambda_authentication_enabled
      template  = local.cache_behavior_refresh
    }
  ]
}

# Template -------------------------------------------------------------------------------------------------------------

# Functions

locals {
  lambda_authentication_enabled = var.cognito_auth_enabled || (var.cognito_secret_arn != null && var.cognito_key_arn != null)
  lambda_authentication = {
    handler              = "index.handler"
    runtime              = "nodejs18.x"
    source_dir           = "${path.module}/templates/authentication"
    include_body         = true
    install_dependencies = true
    config_file          = "config.json"
    config_content = jsonencode({
      auth_enabled   = var.cognito_auth_enabled
      cognito_groups = var.cognito_groups
      domain_name    = try(var.cf_aliases[0])
      ip_whitelist   = var.cognito_whitelist
      login_path     = var.cognito_login_path
      refresh_path   = var.cognito_refresh_path
      secret_arn     = var.cognito_secret_arn
    })
  }
  lambda_login = {
    handler              = "index.handler"
    runtime              = "nodejs18.x"
    source_dir           = "${path.module}/templates/login"
    include_body         = true
    install_dependencies = true
    config_file          = "config.json"
    config_content = jsonencode({
      domain_name = try(var.cf_aliases[0])
      login_path  = var.cognito_login_path
      secret_arn  = var.cognito_secret_arn
    })
  }
  lambda_refresh = {
    handler              = "index.handler"
    runtime              = "nodejs18.x"
    source_dir           = "${path.module}/templates/refresh"
    include_body         = true
    install_dependencies = true
    config_file          = "config.json"
    config_content = jsonencode({
      domain_name = try(var.cf_aliases[0])
      secret_arn  = var.cognito_secret_arn
    })
  }
}

# Cache Behaviors

locals {
  cache_behavior_login = merge(local.cache_behavior_base, {
    path_pattern = var.cognito_login_path
    lambda_functions = {
      viewer_request = local.lambda_login
    }
  })
  cache_behavior_refresh = merge(local.cache_behavior_base, {
    path_pattern = var.cognito_refresh_path
    lambda_functions = {
      viewer_request = local.lambda_refresh
    }
  })
}

locals {
  cache_behavior_base = {
    target_origin_id           = var.cf_origin_id
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = false
    lambda_functions           = {}
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    cache_policy               = null
    origin_request_policy_id   = null
    origin_request_policy      = null
    response_headers_policy_id = null
    response_headers_policy    = null
  }
}

# ----------------------------------------------------------------------------------------------------------------------
