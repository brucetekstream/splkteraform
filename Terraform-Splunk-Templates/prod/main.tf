terraform {
  backend "s3" {
    encrypt = "true"
    bucket  = "prod-<customer>splunkprod-us-east-1-terraform-state"
    key     = "<customer>splunk/terraform.tfstate"
    region     = "us-east-1"
    profile = "<customer>_splunk_prod"
  }
  required_providers{
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region
}


locals {
  environment = "prod"
  account_name = var.account_name
  common_tags = {
    environment = local.environment
    application_name = "splunk"
    Managed_by = "terraform"
  }
  name_prefix = "${local.environment}-splunk"
}

module "route53_dns" {
  source = "../modules/route53_dns"
  public_zone_id    = var.public_zone_id
  a_records = []
  private_domain = "splunkinternal.com"
  vpc_id = var.vpc_id
  
  common_tags = local.common_tags
}

module "common" {
  source = "../modules/splunk_common"
  vpc_id = var.vpc_id
  name_prefix = local.name_prefix
  s3_prefix = "${local.environment}-${local.account_name}-${var.region}"
  private_routes_ids = var.private_routes_ids
  common_tags = local.common_tags
  <customer>splunkops = var.alarm_email
  ELB_account_id = var.ELB_account_id
  waf_allowed_cidrs = var.waf_allowed_cidrs
}

module "splunk_backups" {
  source = "../modules/splunk_backups"
  hourly_backups_tags = ["splunk-search-security","splunk-search-customer","splunk-search-enterprise","splunk-master","splunk-deployment","splunk-forwarder","splunk-forwarder2","splunk-monitor"]
  hourly_backups_retention = 1
  daily_backups_tags = ["splunk-search-security","splunk-search-customer","splunk-search-enterprise","splunk-master","splunk-deployment","splunk-forwarder","splunk-forwarder2","splunk-monitor"]
  daily_backups_retention = 6
  
  common_tags = local.common_tags
}

/* Pull down the admin user and encrypted password from Secrets Manager to create the user-seed.conf files */
data "aws_secretsmanager_secret_version" "admin_account" {
  secret_id = "adminUser"
}

locals {
  admin_user_info = jsondecode(data.aws_secretsmanager_secret_version.admin_account.secret_string)
}

module "Security_SH" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids # TODO - restrict all of these to 1 subnet!!!
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
 
  #Unique per SH
  # Following IP addresses/ranges are for <customer> resources to make API calls into Splunk to run searches (such as Demisto).
  # 99.7.132.194/32 is Karl Cepull's home IP address. Added that on 12/28/2021 for testing.
  _8089_cidrs = var.waf_allowed_cidrs
  hostname = "splunk-search-security"
  public_name = "security"
  name_component = "security"
  instance_type = "c5.9xlarge"
  volume_size = 300
}

module "Enterprise_SH" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
  
  #Unique per SH
  hostname = "splunk-search-enterprise"
  public_name = "enterprise"
  name_component = "enterprise"
  instance_type = "c5.xlarge"
  volume_size = 300
}

module "Customer_SH" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  // TEMPORARY while testing
  s3_alb_logs = module.common.s3_alb_logs 
  
  #Unique per SH
  hostname = "splunk-search-customer"
  public_name = "customer"
  name_component = "customer"
  instance_type = "c5.2xlarge"
  volume_size = 300
}

module "forwarder" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
  
  #Unique per SH
  hostname = "splunk-forwarder"
  public_name = "forwarder"
  name_component = "forwarder"
  instance_type = "c5.4xlarge"
  volume_size = 100
}

/*
module "forwarder2" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.iam_role_name
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
  
  #Unique per SH
  hostname = "splunk-forwarder2"
  public_name = "forwarder2"
  name_component = "forwarder2"
  instance_type = "c5.2xlarge"
  volume_size = 100
}
*/

module "monitoring_console" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
  
  #Unique per SH
  hostname = "splunk-monitor"
  public_name = "monitor"
  name_component = "monitor"
  instance_type = "c5.xlarge"
  volume_size = 100
}


/*
module "test" {
  source             = "../modules/splunk-resource"
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.iam_role_name
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  
  #Unique per SH
  hostname = "splunk-test"
  public_name = "test"
  name_component = "test"
  instance_type = "t3.medium"
  volume_size = 100
}
*/

module "master" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  pem_file_name = "master-mgmt.${var.public_domain_name}.pem"
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing
  
  #Unique per Resource
  hostname = "splunk-master"
  public_name = "master"
  public_name_2 = "master-mgmt" #for 8089
  name_component = "master"
  name_component_2 = "master-mgmt"
  instance_type = "c5.xlarge"
  volume_size = 100
}


module "deployment" {
  source             = "../modules/splunk-resource"
  depends_on = [module.common.initial_configs]
  #Common Variables
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid_deployment"]
  admin_password = local.admin_user_info["admin_password_deployment_encrypted"]
  pem_file_name = "deployment-mgmt.${var.public_domain_name}.pem"
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn
  s3_alb_logs = module.common.s3_alb_logs // TEMPORARY while testing

  #Unique per Resource
  hostname = "splunk-deployment"
  public_name = "deployment"
  public_name_2 = "deployment-mgmt" #for 8089
  name_component = "deployment"
  name_component_2 = "deployment-mgmt"
  instance_type = "m5.large"
  volume_size = 150
}


module "indexers" {
  source             = "../modules/splunk-indexers"
  depends_on = [module.common.initial_configs]
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.instance_setup_profile
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  name_prefix = local.name_prefix
  key_name = var.key_name
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  #Unique per Resource
  hostname_ami = "splunk-indexer"
  instance_type = "c5.4xlarge"
  volume_size = 300
  volume_2_size = 5120
  volume_2_name = "/dev/sdg"
  num_indexer_dns_entries = var.num_indexer_dns_entries

  indexers = [
    {
      hostname = "splunk-indexer-01"
      name_component = "indexer-01"
      availability_zone = var.availability_zones[0]
      priv_subnet_id = var.app_subnets_ids[0]
      pub_subnet_id = var.public_subnets_ids[0]
      pem_file_name = "indexer-01.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-02"
      name_component = "indexer-02"
      availability_zone = var.availability_zones[1]
      priv_subnet_id = var.app_subnets_ids[1]
      pub_subnet_id = var.public_subnets_ids[1]
      pem_file_name = "indexer-02.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-03"
      name_component = "indexer-03"
      availability_zone = var.availability_zones[2]
      priv_subnet_id = var.app_subnets_ids[2]
      pub_subnet_id = var.public_subnets_ids[2]
      pem_file_name = "indexer-03.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-04"
      name_component = "indexer-04"
      availability_zone = var.availability_zones[0]
      priv_subnet_id = var.app_subnets_ids[0]
      pub_subnet_id = var.public_subnets_ids[0]
      pem_file_name = "indexer-04.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-05"
      name_component = "indexer-05"
      availability_zone = var.availability_zones[1]
      priv_subnet_id = var.app_subnets_ids[1]
      pub_subnet_id = var.public_subnets_ids[1]
      pem_file_name = "indexer-05.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-06"
      name_component = "indexer-06"
      availability_zone = var.availability_zones[2]
      priv_subnet_id = var.app_subnets_ids[2]
      pub_subnet_id = var.public_subnets_ids[2]
      pem_file_name = "indexer-06.${var.public_domain_name}.pem"
    },
    {
      hostname = "splunk-indexer-07"
      name_component = "indexer-07"
      availability_zone = var.availability_zones[0]
      priv_subnet_id = var.app_subnets_ids[0]
      pub_subnet_id = var.public_subnets_ids[0]
      pem_file_name = "indexer-07.${var.public_domain_name}.pem"
    }
  ]
  
}


module "hec" {
  source             = "../modules/splunk-hec"
  depends_on = [module.common.initial_configs]
  vpc_id        = var.vpc_id
  app_subnets        = var.app_subnets_ids
  data_subnets       = var.data_subnets_ids
  public_subnets     = var.public_subnets_ids
  availability_zones = var.availability_zones
  ddns_topic = module.route53_dns.ddns_topic
  ddns_role = module.route53_dns.ddns_role
  private_zone_id = module.route53_dns.private_zone_id
  public_zone_id = var.public_zone_id
  instance_profile = module.common.iam_role_name
  cert_arn = module.route53_dns.cert_arn
  common_tags        = local.common_tags
  vpc_internal_cidrs = var.vpc_internal_cidrs
  name_prefix = local.name_prefix
  key_name = var.key_name
  s3_config_bucket = module.common.s3_config_bucket
  public_domain_name = var.public_domain_name
  admin_user = local.admin_user_info["admin_userid"]
  admin_password = local.admin_user_info["admin_password_encrypted"]
  splunk_alarms_topic = module.common.splunk_alarms_topic_arn

  hostname = "splunk-forwarder-hec"
  instance_type = "t3.micro"
  name_component = "hec"
  volume_size = 30
  cnt_minimum = 20
  cnt_desired = 40
  cnt_maximum = 40
}