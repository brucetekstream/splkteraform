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

variable "key_name" {
  description = "ssh key for instances"
}

variable "common_tags" {
  type = map(string)

  default = {
    Module = "hec"
  }
}

variable "name_prefix" {}

variable "name_component" {
  description = "the name of this instance, e.g. 'utility'"
}

variable "instance_type" {} # c5.4xlarge


variable "ddns_topic" {}

variable "ddns_role" {}
variable "private_zone_id" {}


variable "public_zone_id"{
  
}


variable "cert_arn" {}

variable "instance_profile" {}

variable "hostname" {}

variable "volume_size" {}


variable "vpc_internal_cidrs" {
  description = "list of cidrs for private subnets in VPC"
  type        = list(string)
}

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

variable "cnt_minimum" {
  description = "The mininmum number of HEC forwarders allowed in the ASG."
}

variable "cnt_desired" {
  description = "The desired number of HEC forwarders in the ASG."
}

variable "cnt_maximum" {
  description = "The maximum number of HEC forwarders allowed in the ASG."
}

variable "splunk_alarms_topic" {
  description = "The ARN of the SNS topic to send alarms to."
}
