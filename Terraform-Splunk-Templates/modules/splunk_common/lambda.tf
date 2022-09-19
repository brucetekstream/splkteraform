/*********************
* CloudWatchAWSAlert *
*********************/

data "archive_file" "lambda_CloudWatchAWSAlert" {
  type        = "zip"
  source_file = "${path.module}/lambda/CloudWatchAWSAlert.py"
  output_path = "${path.module}/lambda/dist/CloudAWSAlert.zip"
}

resource "aws_lambda_layer_version" "pymsteams" {
  filename = "${path.module}/lambda/pymsteams.zip"
  layer_name = "pymsteams"
  compatible_runtimes = ["python3.9"]
}

resource "aws_lambda_function" "lambda_CloudWatchAWSAlert" {
  filename         = data.archive_file.lambda_CloudWatchAWSAlert.output_path
  function_name    = "splunk_common_CloudWatchAWSAlert"
  role             = aws_iam_role.lambda_CloudWatchAWSAlert.arn
  handler          = "CloudWatchAWSAlert.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256(data.archive_file.lambda_CloudWatchAWSAlert.output_path)
  description      = "Sends alerts to CloudWatch WebHook"
  timeout = 600
  layers = [aws_lambda_layer_version.pymsteams.arn]
  tags = merge(local.common_tags,{ } )
}

resource "aws_lambda_permission" "with_sns" {
    statement_id = "AllowExecutionFromSNS"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda_CloudWatchAWSAlert.arn
    principal = "sns.amazonaws.com"
    source_arn = aws_sns_topic.splunk-alarms.arn
}

resource "aws_sns_topic_subscription" "topic_lambda" {
  topic_arn = aws_sns_topic.splunk-alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_CloudWatchAWSAlert.arn
}

/****************
* DeleteOldAMIs *
****************/

data "archive_file" "lambda_DeleteOldAMIs" {
  type        = "zip"
  source_file = "${path.module}/lambda/DeleteOldAMIs.py"
  output_path = "${path.module}/lambda/dist/DeleteOldAMIs.zip"
}

resource "aws_lambda_function" "lambda_DeleteOldAMIs" {
  filename         = data.archive_file.lambda_DeleteOldAMIs.output_path
  function_name    = "splunk_common_DeleteOldAMIs"
  role             = aws_iam_role.lambda_DeleteOldAMIs.arn
  handler          = "DeleteOldAMIs.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256(data.archive_file.lambda_DeleteOldAMIs.output_path)
  description      = "When Image Builder creates a new base AMI, deletes the oldest one."
  timeout = 600
  // layers = [aws_lambda_layer_version.pymsteams.arn]
  tags = merge(local.common_tags,{ } )
}


/*********************
* SetMaintenanceMode *
*********************/

data "archive_file" "lambda_SetMaintenanceMode" {
  type        = "zip"
  source_file = "${path.module}/lambda/SetMaintenanceMode.py"
  output_path = "${path.module}/lambda/dist/SetMaintenanceMode.zip"
}

resource "aws_lambda_layer_version" "requests" {
  filename = "${path.module}/lambda/requests.zip"
  layer_name = "requests"
  compatible_runtimes = ["python3.9"]
}

resource "aws_lambda_function" "lambda_SetMaintenanceMode" {
  filename         = data.archive_file.lambda_SetMaintenanceMode.output_path
  function_name    = "splunk_common_SetMaintenanceMode"
  role             = aws_iam_role.lambda_SetMaintenanceMode.arn
  handler          = "SetMaintenanceMode.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256(data.archive_file.lambda_SetMaintenanceMode.output_path)
  description      = "Calls Splunk REST API to enable/disable indexer cluster maintenance mode."
  timeout = 60
  layers = [aws_lambda_layer_version.requests.arn]
  vpc_config {
    subnet_ids = var.app_subnet_ids
    security_group_ids = [ aws_security_group.lambda_sg.id ]
  }
  tags = merge(local.common_tags,{ } )
}
