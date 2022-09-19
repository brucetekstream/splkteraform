resource "aws_ssm_parameter" "splunk-cw-config" {
  name        = "/AmazonCloudWatch-Splunk"
  description = "AWS Cloudwatch metrics configuration "
  type        = "String"
  value       = file("${path.module}/scripts/config.json")
  overwrite   = true

  tags = merge(
    local.common_tags,
    {
      "Name" = "/AmazonCloudWatch-Splunk"
    },
  )
}