output "cert_arn" {
  value = aws_acm_certificate.cert.arn
}
output "private_zone_id" {
  value = aws_route53_zone.private.id 
}
output "ddns_topic" {
  value = aws_sns_topic.ddns_handling.arn
}

output "ddns_role" {
  value = aws_iam_role.ddns_lifecycle.arn
}

