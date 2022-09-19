resource "aws_sns_topic" "splunk-alarms" {
  name = "splunk-alarms"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.splunk-alarms.arn
  protocol  = "email"
  endpoint  = var.customersplunkops
}