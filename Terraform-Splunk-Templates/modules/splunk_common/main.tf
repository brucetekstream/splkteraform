


locals {
  additional_common_tags = {

    Module = "splunk_common"
    prj_name = "splunk"
    prj_owner = "Karl Cepull"

  }
  name_prefix = var.name_prefix

  common_tags = merge(var.common_tags, local.additional_common_tags)



}


data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


