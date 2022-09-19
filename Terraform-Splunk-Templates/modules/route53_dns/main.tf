
data "aws_route53_zone" "public_zone" {
  zone_id = var.public_zone_id
 }


locals {
  additional_common_tags = {

    Module = "route53_dns"
    prj_name = "splunk"
    prj_owner = "Karl Cepull"

  }

  common_tags = merge(var.common_tags, local.additional_common_tags)

  public_zone_name= replace(data.aws_route53_zone.public_zone.name, "/[.]$/", "")


}



