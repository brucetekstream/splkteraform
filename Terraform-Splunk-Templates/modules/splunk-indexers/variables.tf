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


variable "indexers" {
  type = list(object({
    hostname = string
    name_component = string
    availability_zone = string
    priv_subnet_id = string
    pub_subnet_id = string
    pem_file_name = string
  }))
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
    Module = "indexer"
  }
}

variable "name_prefix" {}

variable "instance_type" {} # c5.4xlarge


variable "ddns_topic" {}

variable "ddns_role" {}
variable "private_zone_id" {}


variable "public_zone_id"{
  
}


variable "cert_arn" {}

variable "instance_profile" {}

variable "hostname_ami" {}

variable "volume_size" {}
# variable "volume_2_size" {}
# variable "volume_2_name" {}

variable "hec_cidrs" {
  default = ["10.0.0.0/8"]
  type        = list(string)
}

variable "bastion_sg" {
  default = ""
}

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


variable "num_indexer_dns_entries" {
  description = "The number of 'idx#' DNS entries to create in Route53 that will round-robin all of the indexers. Use this instead of the actual indexers in outputs.conf."
}