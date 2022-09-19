resource "aws_route53_zone" "private" {
  name = var.private_domain

  vpc {
    vpc_id = var.vpc_id
  }
}