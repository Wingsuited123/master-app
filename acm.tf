# ----------------------------------------------------------------------------------------------------------------------
# ACM
# ----------------------------------------------------------------------------------------------------------------------

# Certificate ----------------------------------------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  count = local.acm_certificate_create ? 1 : 0

  provider = aws.us_east_1

  domain_name               = var.cf_aliases[0]
  subject_alternative_names = var.cf_aliases
  validation_method         = "DNS"


  tags = var.tags
}

# Validation -----------------------------------------------------------------------------------------------------------

resource "aws_acm_certificate_validation" "this" {
  count = local.acm_certificate_create ? 1 : 0

  provider = aws.us_east_1

  certificate_arn = one(aws_acm_certificate.this[*].arn)

  validation_record_fqdns = [for record in aws_route53_record.this : record.fqdn]
}

# Records --------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "this" {
  for_each = local.acm_certificate_create ? { for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
    name    = dvo.resource_record_name
    type    = dvo.resource_record_type
    record  = dvo.resource_record_value
    zone_id = local.acm_domains_zone[dvo.domain_name]
    }
  } : {}

  provider = aws.us_east_1

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = each.value.zone_id
  ttl             = 60
  records         = [each.value.record]
}

# Zones ----------------------------------------------------------------------------------------------------------------

data "aws_route53_zones" "this" {
  count = local.acm_certificate_create ? 1 : 0
}

data "aws_route53_zone" "this" {
  for_each = toset(flatten(data.aws_route53_zones.this[*].ids))

  zone_id = each.key
}

# Locals ---------------------------------------------------------------------------------------------------------------

locals {
  acm_certificate_arn    = coalesce(var.acm_certificate_arn, one(aws_acm_certificate.this[*].arn))
  acm_certificate_create = var.acm_certificate_arn == null
  # abc.cde.fgh => [abc, cde, fgh]
  acm_domains_split = {
    for dvo in aws_acm_certificate.this : dvo.domain_name => (split(".", dvo.domain_name))
  }
  # abc.cde.fgh => [abc, cde, fgh] -> acb.cde.fgh => [abc.cde.fgh, cde.fgh, fgh]
  acm_domains_expanded = {
    for k, v in local.acm_domains_split : k => [
      for i in range(length(v)) :
      join(".", slice(v, i, length(v)))
    ]
  }
  # abc.cde.fgh => [abc.cde.fgh, cde.fgh, fgh] -> abc.cde.fgh => [cde.fgh, fgh]
  acm_domains_zones = {
    for k, v in local.acm_domains_expanded : k => flatten([
      for e in v : [
        for zone in data.aws_route53_zone.this : zone.id if e == zone.name
      ]
    ])
  }
  # abc.cde.fgh => [cde.fgh, fgh] -> abc.cde.fgh => cde.fgh
  acm_domains_zone = {
    for k, v in local.acm_domains_zones : k => length(v) > 0 ? v[0] : null
  }
}

# Error ----------------------------------------------------------------------------------------------------------------

resource "terraform_data" "acm_error_on_missing_zone" {
  for_each = { for k, v in local.acm_domains_zone : k => v if v == null }

  input = {
    error = "No hosted zone found for the domain ${each.key}. Either create one or provide the ARN of an existing ACM certificate."
  }

  provisioner "local-exec" {
    command = "echo \"${self.output.error}\" && exit 1"
  }
}

# ----------------------------------------------------------------------------------------------------------------------
