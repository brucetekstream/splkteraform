//variable "domain" {}

variable "public_zone_id" {
    description = "Route53 Hosted Zone for DNS entries"
}


variable "tag_prefix" {
  description = "tag_prefix for naming conventions"
  default     = ""
}

variable "vpc_id" {
  description = "id for VPC private zone"
}

variable "private_domain" {
  description = "private_domain for VPC private zone"
}

variable "common_tags" {
  type = map(string)

  default = {
    Module = "UXC"
  }
}

variable "a_records" {

  type = list(object({
    name = string
    target = string

  }))
  default = []

}