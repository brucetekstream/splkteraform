resource "aws_route53_record" "dns_record" {
  zone_id = var.public_zone_id
  name    = "${var.public_name}.${local.public_zone_name}"
  type    = "A"

  alias {
    name                   = aws_alb.load_balancer.dns_name
    zone_id                = aws_alb.load_balancer.zone_id
    evaluate_target_health = true
  }
}


resource "aws_route53_record" "dns_record2" {
  count = var.public_name_2 != "" ? 1 : 0
  zone_id = var.public_zone_id
  name    = "${var.public_name_2}.${local.public_zone_name}"
  type    = "A"

  alias {
    name                   = var.name_component_2 != "" ? aws_alb.mgmt_lb[0].dns_name : aws_alb.load_balancer.dns_name
    zone_id                = var.name_component_2 != "" ? aws_alb.mgmt_lb[0].zone_id : aws_alb.load_balancer.zone_id
    evaluate_target_health = true
  }
}