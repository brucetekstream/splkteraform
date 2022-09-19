resource "aws_route53_record" "dns_record" {
  count = length(var.indexers)
  zone_id = var.public_zone_id
  name    = "${var.indexers[count.index].name_component}.${local.public_zone_name}"
  type    = "A"

  alias {
    name                   = aws_alb.lb.*.dns_name[count.index]
    zone_id                = aws_alb.lb.*.zone_id[count.index]
    evaluate_target_health = true
  }
}
/*
resource "aws_route53_record" "dns_record_hec" {
  zone_id = var.public_zone_id
  name    = "hec.${local.public_zone_name}"
  type    = "A"
  alias {
    name                   = aws_alb.heclb.dns_name
    zone_id                = aws_alb.heclb.zone_id
    evaluate_target_health = true
  }
}
*/

data "aws_network_interface" "eni_idx_nlb" {
  count = length(var.indexers)

  filter {
    name   = "description"
    values = ["ELB ${aws_alb.lb[count.index].arn_suffix}"]
  }
}


resource "aws_route53_record" "dns_record_idx" {
  count = var.num_indexer_dns_entries
  zone_id = var.public_zone_id
  name = "idx${count.index+1}.${local.public_zone_name}"
  type = "A"
  records = data.aws_network_interface.eni_idx_nlb.*.association[*][0].public_ip
  ttl = "300"
}
