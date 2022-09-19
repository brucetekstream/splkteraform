
locals {
  additional_common_tags = {

    Module = "splunk_backups"
    prj_name = "splunk"
    prj_owner = "Karl Cepull"

  }

  common_tags = merge(var.common_tags, local.additional_common_tags)


}



