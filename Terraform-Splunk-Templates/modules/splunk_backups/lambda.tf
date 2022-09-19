


data "archive_file" "lambda_create_amis" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_create_amis.py"
  output_path = "${path.module}/lambda/dist/lambda_create_amis.zip"
}

resource "aws_lambda_function" "lambda_create_amis" {
  filename         = data.archive_file.lambda_create_amis.output_path
  function_name    = "splunk_backups_create_amis"
  role             = aws_iam_role.lambda_backups.arn
  handler          = "lambda_create_amis.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.lambda_create_amis.output_path)
  description      = "Looks up splunk instances and creates AMIs"
  timeout = 600
}

