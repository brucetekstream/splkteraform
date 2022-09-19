
data "aws_route53_zone" "private_zone" {
  zone_id = var.private_zone_id
 }

 data "aws_route53_zone" "public_zone" {
  zone_id = var.public_zone_id
 }

locals {
  additional_common_tags = {
    Module = "splunk_indexers"
    created_by = "Karl Cepull"

  }
  private_zone_name= replace(data.aws_route53_zone.private_zone.name, "/[.]$/", "")
  public_zone_name= replace(data.aws_route53_zone.public_zone.name, "/[.]$/", "")

  #servername = "${var.indexers[count.index].hostname}.${local.private_zone_name}"

  common_tags = merge(var.common_tags, local.additional_common_tags)
}
