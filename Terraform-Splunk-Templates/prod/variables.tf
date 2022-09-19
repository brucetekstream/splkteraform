# ---- use variables defined in env-vars file
variable "aws_profile" {
}

variable "region" {
}

variable "ELB_account_id" {
  description = "Set this based on the region. See the table at https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions."
}

#From Baseline TF

variable "vpc_id" {
  description = "Id of the VPC"
}

variable "app_subnets_ids" {
  type        = list(string)
  description = "Ids of the application subnets in VPC"
}

variable "public_subnets_ids" {
  type        = list(string)
  description = "Ids of the public subnets in VPC"
}

variable "data_subnets_ids" {
  type        = list(string)
  description = "Ids of the data subnets in VPC"
}
variable "availability_zones" {
  type        = list(string)
  description = "availability zones used to divide the VPC subnets"
}


variable "private_routes_ids" {
  description = "route table ids to associate with the end-point"
  type        = list(string)
}


variable "public_zone_id"{
}

variable "vpc_internal_cidrs" {
  description = "list of cidrs for private subnets in VPC"
  type        = list(string)
}

variable "key_name" {
}

variable "account_name" {}

variable "public_domain_name" {
  description = "Public DNS domain name for the indexers. Used to set the name of the SSL private keys."
}

variable "alarm_email" {
  description = "Email address to send alarms to."
}

variable "waf_allowed_cidrs" {
  description = "Array of CIDRs to allow to bypass the WAF rules (except loginType rule)"
}

variable "num_indexer_dns_entries" {
  description = "The number of 'idx#' DNS entries to create in Route53 that will round-robin all of the indexers. Use this instead of the actual indexers in outputs.conf."
}