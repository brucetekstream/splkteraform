#HOURLY BACKUPS
resource "aws_cloudwatch_event_rule" "hourly_backups" {
  name                = "hourly_backups"
  description         = "triggers deletion of new AMIs every one hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "hourly_backups" {
  rule      = aws_cloudwatch_event_rule.hourly_backups.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_create_amis.arn
  input =  <<DOC
  {
      "INSTANCE_TAGS": ${jsonencode(var.hourly_backups_tags)},
      "RETENTION": ${jsonencode(var.hourly_backups_retention)},
      "TYPE": "HOURLY"
  }
  DOC
}


resource "aws_lambda_permission" "hourly_backups" {
  depends_on = [aws_lambda_function.lambda_create_amis]

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_create_amis.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly_backups.arn
}

#DAILY BACKUPS

resource "aws_cloudwatch_event_rule" "daily_backups" {
  name                = "daily_backups"
  description         = "triggers deletion of new AMIs every one hour"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "daily_backups" {
  rule      = aws_cloudwatch_event_rule.daily_backups.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_create_amis.arn
  input =  <<DOC
  {
      "INSTANCE_TAGS": ${jsonencode(var.daily_backups_tags)},
      "RETENTION": ${jsonencode(var.daily_backups_retention)},
      "TYPE": "DAILY"
  }
  DOC
}
resource "aws_lambda_permission" "daily_backups" {
  depends_on = [aws_lambda_function.lambda_create_amis]

  statement_id  = "AllowExecutionFromCloudWatch2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_create_amis.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_backups.arn
}
