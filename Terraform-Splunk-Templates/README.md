# Pre-Requisites:
1.	Existing VPC with appropriate subnets in different AZs ( I have this on the baseline folder in the repo, but this will be created by <customer>)
2.	Existing Public Hosted Zone in Route53 ( I have this on the baseline folder in the repo, but this will be created by <customer>)
3.	For the terraform datasource queries to work, we need to have the initial AMI to use when there is not one created by the Lambda, already in place, and with a Name tag “splunk-base-ami”, I created this manually, simply a copy of the standard Amazon Linux 2
4.  An S3 Bucket to store the terraform state the naming convention is "{environment}-{account_name}-{region}"-terraform-state"
5.  A SSH Key in the account, the default name used in the scripts is tekstream_<customer> but can be changed using the variable "key_name"
6.  A profile created in the aws credentials. the name of the profile used is configured using the aws_profile variable in the tfvars file. to create it, use <customer> procided tool, i.e for dev account using username juan.becerra
```
 ./aws-login -a <customer>splunkdev -f sms -p <customer>_splunk_dev -r us-east-1 -n Admin -u juan.becerra
```
7.  Update terraform.tfvars and main.tf (backed section) with environment specific values, special attention to the backend bucket and profile values (main.tf) and the profile name (terraform.tfvars) to avoid conflicts running against the wrong environment or state file.

# Running Scripts
TF scripts are environment specific (dev/prd) from the environment folder you can run terraform as follows:

terraform init
terraform plan
terraform apply

NOTE: As instances are created by the Auto Scalling Groups and not by terraform, when making modifications to the scripts that require resource re-creation (i.e. security group names). Terraform will run into an error deleting resources as they are associated with the running instances, Terminate instances when making this changes prior to TF run, Instances will be automatically re-created by the ASGs.

# TODO
* 


The ASGs are created with a module, right now I have the modules for Search Heads and Indexers working, the missing modules for master, deployer and forwarders will be identical to the SH one, with differences in security groups, and bootstrapping parameters, and potentially we can update the modules and configure them to use a single ALB like Karl wanted.

The modules create:
1. Lanch Template with the details for AMI (see AMI Selection below) and instance type to be used 
2. ASG of 1
3. ELB (NLB for indexers, ALB for others)
4. ELS Listeners TLS ones associated with ACM certificate passed as a variable
5. ELS Targets to the ASG 
6. Route 53 Records on the public hosted zone associated with the ELB
7. Security groups to be used for the instance and the ELB

TF AMI selection:

1. TF queries the current account for all AMIs using the tag Name “splunk-base-ami” or the hostname for each compoent 
2. based on the "latest" parameter in the query, it gets the last AMI with those tags, and sets it to the Launch Template. this is so if terraform is run again, it is in line with the functionality done in the Lambda for backups and does not revert back to an earlier AMI.

 Lambda function regulary queries the AMIs using the same Name tag and deletes old AMIs as well as creates new ones based on schedules.


# Backups

 switched approach mid-way we will not need the snapshot policy anymore, instead I have Lambda taking the tag for the hostname and creating an AMI from the instance on a schedule (either hourly or daily). At the same time the lambda cleans up old AMIs based on a variable for retention (number of AMIs to keep)
```
module "splunk_backups" {
  source = "../modules/splunk_backups"
  hourly_backups_tags = ["enterprise-sh","adhoc-sh"]
  hourly_backups_retention = 5
  daily_backups_tags = ["splunk-indexer-01",”splunk-master”]
  daily_backups_retention = 2
  
  common_tags = local.common_tags
}
```
# Dynamic DNS

The Dynamic DNS code is in this module, it creates the private hosted zone and configures the Lambda and SNS topics used by the ASGs to update the DNS when an instance is launched, the second part of it is the bootstrap of the launch instances which read the hostname from the tags and sets in at the OS level.
module "route53_dns" {
  source = "../modules/route53_dns"
  public_zone_id    = var.public_zone_id
  a_records = []
  private_domain = "splunkintenal.com"
  vpc_id = var.vpc_id
  
  common_tags = local.common_tags
}

# Search Heads/Forwarders/Deployer/Master


To create a search head we call the module like this (the main value to keep in mind is the hostname, as that is used for the naming conventions used for the Lambdas to create/delete AMIs, update ASG templates, and for the Dynamic DNS…(for the other Shs it is just a matter of calling the module again with different parameters)
```
module "Enterprise_SH" {
  source             = "../../modules/splunk-resource"
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
  bastion_sg = module.common.bastion_sg_id
  vpc_internal_cidrs = var.vpc_internal_cidrs
  key_name = var.key_name
  name_prefix = local.name_prefix
  waf_acl_arn = module.common.waf_acl_arn
  
  #Unique per SH
  _8089_cidrs = ["10.0.0.0/8"]  #this value is only used when the resource requires an additional listener on 8089
  public_name_2 = "splunk-master-8089"  #This variable is only used if an additional Route53 DNS entry is required for 8089 port with additional 443 listener
  instance_type = "t3.micro"
  hostname = "enterprise-sh"
  public_name = "enterprise-sh"
  volume_size = 30
}
```

# Indexers
To create indexers, the module is slightly different as we use common SG, and template for all, also the value used by the backup lambda is hostname_ami, as we only one to create AMIs for the first indexer and use it for all the others.
```
module "indexers" {
  source             = "../../modules/splunk-indexers"
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
  bastion_sg = module.common.bastion_sg_id
  vpc_internal_cidrs = var.vpc_internal_cidrs
  name_prefix = local.name_prefix
  key_name = var.key_name
  #Unique per Resource
  instance_type = "t3.micro"
  hostname_ami = "splunk-indexer-01"
  volume_size = 30

  indexers = [
    {
      hostname = "splunk-indexer-01"
      availability_zone = var.availability_zones[0]
      priv_subnet_id = var.app_subnets_ids[0]
      pub_subnet_id = var.public_subnets_ids[0]
    },
    {
      hostname = "splunk-indexer-02"
      availability_zone = var.availability_zones[1]
      priv_subnet_id = var.app_subnets_ids[1]
      pub_subnet_id = var.public_subnets_ids[1]
    },
    {
      hostname = "splunk-indexer-03"
      availability_zone = var.availability_zones[2]
      priv_subnet_id = var.app_subnets_ids[2]
      pub_subnet_id = var.public_subnets_ids[2]
    }
  ]
  
}
```

The splunk-base-ami image is set up as follows:
- Base AWS Linux2 OS
- Create 'splunk' user with: 
    sudo useradd -m -r splunk
- Download Splunk with: 
    wget -O splunk-7.3.7.1-d3f7cf7c5493-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.3.7.1&product=splunk&filename=splunk-7.3.7.1-d3f7cf7c5493-Linux-x86_64.tgz&wget=true'
- Install Splunk v7.3.7.1: 
    tar xzvf splunk-7.3.7.1-d3f7cf7c5493-Linux-x86_64.tgz -C /opt
    chown splunk:splunk -R /opt/splunk
- Copy splunk.secret to /opt/splunk/etc/auth
- Create /opt/splunk/etc/passwd 
- Add .sprun in ~ and make executable
- Add .sprun to ~/.bashrc (splunk user)
- Install CloudWatch agent:
  yum install -y amazon-cloudwatch-agent
  mkdir /usr/share/collectd
  touch /usr/share/collectd/types.db
- Update sudo rights for splunk user by creating /etc/sudoers.d/splunk:
  # Allow splunk to start/stop the service
  splunk	ALL=(root) NOPASSWD: /usr/bin/systemctl * Splunkd*
  splunk  ALL=(root) NOPASSWD: /opt/splunk/bin/splunk
- Follow the instructions at https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/al2-live-patching.html to install and set up live patching of the kernel (all as root):
  yum -y install binutils
  yum -y install yum-plugin-kernel-livepatch
  yum kernel-livcepatch enable -y
  yum install -y kpatch-runtime
  yum update kpatch-runtime
  systemctl enable kpatch.service
  amazon-linux-extras enable livepatch
  yum update
- Install and configure yum-cron:
  sudo yum -y install yum-cron
  # not needed, already is 'default': sudo vi /etc/yum/yum-cron.conf, and set update_cmd=default
  sudo systemctl enable yum-cron.service
  sudo systemctl start yum-cron.service
  sudo systemctl status yum-cron.service


The bootstrap.sh scripts in the various modules will then run Splunk for the first time, etc., when the instance is started.


TODO:
- Move systemd setup, etc. from AMI to bootstrap, since settings are different for SH vs IDX
# Terraform-Splunk-Templates
