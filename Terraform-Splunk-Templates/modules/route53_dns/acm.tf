

resource "aws_acm_certificate" "cert" {
  domain_name       =  "*.${local.public_zone_name}"
  validation_method = "DNS"
  tags = merge(
    var.common_tags,
    {
      "Name" = "Subdomain Cert for ${local.public_zone_name}"
    },
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id = var.public_zone_id

/*

  name    = aws_acm_certificate.cert.domain_validation_options.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = var.public_zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
  */
}



resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  //validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

}
