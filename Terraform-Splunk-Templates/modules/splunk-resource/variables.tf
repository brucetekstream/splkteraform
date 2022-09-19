variable "vpc_id" {
  description = "Id of the VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "availability zones used to divide the VPC subnets"
}

variable "app_subnets" {
  type        = list(string)
  description = "Ids of the application subnets in VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "Ids of the public subnets in VPC"
}

variable "data_subnets" {
  type        = list(string)
  description = "Ids of the data subnets in VPC"
}

variable "volume_size" {
  description = "root volume size to use for servers"
}

variable "key_name" {
  description = "ssh key for instances"
}

variable "name_prefix" {}

variable "name_component" {
  description = "the name of this instance, e.g. 'utility'"
}

variable "name_component_2" {
  description = "if set, creates an NLB for port 8089 traffic"
  default = ""
}

variable "common_tags" {
  type = map(string)

  default = {
    Module = "splunk-sh"
  }
}

variable "instance_type" {} # c5.4xlarge


variable "ddns_topic" {}

variable "ddns_role" {}

variable "private_zone_id" {}

variable "hostname" {}

variable "public_zone_id" {

}

variable "public_name" {
  description = "the hostname to use for DNS, e.g. 'utility'"
}

variable "public_name_2" {
  default     = ""
  description = "if set, will create a secondary DNS entry pointing to port 8089 with this name, e.g. 'utility-mgmt'"
}

variable "cert_arn" {
  description = "the ARN to the ACM certificate to use for load-balancers"
}

variable "instance_profile" {}

variable "bastion_sg" {
  default = ""
}

variable "vpc_internal_cidrs" {
  description = "list of cidrs for private subnets in VPC"
  type        = list(string)
}

variable "_8089_cidrs" {
  description = "list of cidrs for private subnets in VPC"
  type        = list(string)
  default     = []
}

variable "waf_acl_arn" {}

variable "s3_config_bucket" {
  description = "The bucket ID of the S3 bucket used to store the initial configuration files."
}

variable "public_domain_name" {
  description = "Public DNS domain name for the indexers. Used to set the name of the SSL private keys."
}

variable "pem_file_name" {
  description = "If set, will download the named object from AWS Secrets Manager and put it in the etc/auth/certs folder on the Splunk server."
  default = ""
}

variable "admin_user" {
  description = "Name of the admin user account (e.g. 'admin')."
}

variable "admin_password" {
  description = "The hashed password for the admin account."
}

variable "splunk_alarms_topic" {
  description = "The ARN of the SNS topic to send alarms to."
}

variable "s3_alb_logs" {
  description = "The bucket NAME of the S3 bucket used to store the ALB access logs."
}

variable "splunk_base_ami_id" { # TODO - needed?
  description = "The ID of the AMI to use for the boot drive."
}
