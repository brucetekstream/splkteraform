
output "waf_acl_arn" {
  value = aws_wafv2_web_acl.waf.arn
}

/*output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}*/

output "iam_role_name" {
  value = aws_iam_instance_profile.splunk-instance-profile.name
}

/*
output "Files_copied" {
  value = aws_s3_object.initial_configs
}
*/

output "kms_smartstore_key" {
  value = aws_kms_key.splunk
}

output "s3_config_bucket" {
  value = aws_s3_bucket.inits.id
}

// TEMPORARY for testing
output "s3_alb_logs" {
  value = aws_s3_bucket.alb_logs.bucket
}


output "splunk_alarms_topic_arn" {
  value = aws_sns_topic.splunk-alarms.arn
}

output "splunk_base_ami_id" {
  #value = tolist(aws_imagebuilder_image.splunk-base-ami.output_resources[0].amis)[0].image
  value = "ami-02c7b4fc5ffa8a09e" # TODO - restore this!
}

output "instance_setup_profile" {
  value = aws_iam_role.splunk-instance-setup-profile.name
}