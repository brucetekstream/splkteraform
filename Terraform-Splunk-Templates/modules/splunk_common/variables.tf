//variable "domain" {}


variable "name_prefix" {
  description = "name_prefix for naming conventions"
  default     = ""
}

variable "vpc_id" {
  description = "id for VPC private zone"
}

variable "s3_prefix" {
  description = "prefix for S3 naming"
}


variable "private_routes_ids" {
  description = "route table ids to associate with the end-point"
  type        = list(string)
}
variable "common_tags" {
  type = map(string)

  default = {
    Module = "UXC"
  }
}

variable "customersplunkops" {
  description = "Email address to send alerts to."
}

variable "ELB_account_id" {
  description = "Set this based on the region. See the table at https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions."
}

variable "waf_allowed_cidrs" {
  description = "Array of CIDR ranges allowed to bypass WAF rules."
}

variable "image_builder_subnet" {
  description = "Subnet ID to use for temporary Image Builder images"
}

variable "app_subnet_ids" {
  type        = list(string)
  description = "Ids of the application subnets in VPC (where the Splunk servers are)"
}

variable "vpc_internal_cidrs" {
  description = "list of cidrs for private subnets in VPC"
  type        = list(string)
}
