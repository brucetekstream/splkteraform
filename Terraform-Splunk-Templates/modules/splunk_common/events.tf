/*************************************
* Trigger DeleteOldAMIs Lambda daily *
*************************************/

resource "aws_cloudwatch_event_rule" "delete_amis" {
  name                = "delete_amis"
  description         = "Calls Lambda daily to delete old image builder AMIs."
  schedule_expression = "cron(27 3 * * ? *)" // "random" time to run
  tags = merge(local.common_tags,{ })
}

resource "aws_cloudwatch_event_target" "delete_amis" {
  rule      = aws_cloudwatch_event_rule.delete_amis.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_DeleteOldAMIs.arn
  // TODO - pass in variables for ami_names
  input = <<EOF
    {
        "ami_names": ["splunk-base-ami", "splunk-hec-ami"],
        "num_to_keep": 2
    }
  EOF
}


resource "aws_lambda_permission" "delete_amis" {
  depends_on = [aws_lambda_function.lambda_DeleteOldAMIs]

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_DeleteOldAMIs.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.delete_amis.arn
}
