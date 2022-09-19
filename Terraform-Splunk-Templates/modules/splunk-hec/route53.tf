resource "aws_route53_record" "dns_record" {
  zone_id = var.public_zone_id
  name    = "${var.name_component}.${local.public_zone_name}"
  type    = "A"

  alias {
    name                   = aws_alb.hec_lb.dns_name
    zone_id                = aws_alb.hec_lb.zone_id
    evaluate_target_health = true
  }
}
