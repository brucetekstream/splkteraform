aws_profile = "<customer>_splunk_prod"
region = "us-east-1"
ELB_account_id = "12xxx"

vpc_id = "vpc-0f9axxxd71a"
app_subnets_ids = [
     "subnet-04e3xxxfb8",
      "subnet-02bxx57b7",
      "subnet-0e8dxx93e"
    ]
data_subnets_ids = [
      "subnet-092fxx369",
      "subnet-0fbdxxbf3",
      "subnet-03fxx85"
    ]
public_subnets_ids = [
      "subnet-005xxa6e1",
      "subnet-09b0xxaafa",
      "subnet-0axx5efd",
    ]
availability_zones = ["us-east-1a","us-east-1b","us-east-1c"]

vpc_internal_cidrs = ["10.1.0.0/20","10.1.16.0/20","10.1.32.0/20"]

public_zone_id = "Z07xx9QDK"

private_routes_ids = ["rtb-0cxx1171","",""]

key_name = "splunk-prod"

account_name = "<customer>splunkprod"

public_domain_name = "splunk.<customer>home.com"

alarm_email = "<customer>splunkops@tekstream.com"

# Following IP addresses/ranges are for <customer> resources to make API calls into Splunk to run searches (such as Demisto).
# 54.xxx is for iGlass synthetic transactions.
waf_allowed_cidrs = ["",""]

num_indexer_dns_entries = 15
