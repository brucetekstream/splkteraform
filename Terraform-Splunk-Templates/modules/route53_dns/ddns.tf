

data "aws_iam_policy_document" "asg_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}



resource "aws_sns_topic" "ddns_handling" {
  name = "ddns_handling"
}

resource "aws_iam_role" "ddns_handling" {
  name = "ddns_handling"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

}
resource "aws_iam_role_policy" "ddns_handling" {
  name = "ddns_handling"
  role = aws_iam_role.ddns_handling.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Action":[
        "autoscaling:DescribeTags",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:CompleteLifecycleAction",
        "ec2:DescribeInstances",
        "route53:GetHostedZone",
        "ec2:CreateTags"
      ],
      "Effect":"Allow",
      "Resource":"*"
    },
    {
      "Action":[
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Effect":"Allow",
      "Resource":"arn:aws:route53:::hostedzone/${aws_route53_zone.private.zone_id}"
    }
  ]
}
EOF

}





resource "aws_iam_role" "ddns_lifecycle" {
  name               = "ddns_lifecycle"
  assume_role_policy = data.aws_iam_policy_document.asg_assume.json
}



resource "aws_iam_role_policy" "ddns_lifecycle" {
  name   = "ddns_lifecycle"
  role   = aws_iam_role.ddns_lifecycle.id
  policy = data.aws_iam_policy_document.ddns_lifecycle.json
}

data "aws_iam_policy_document" "ddns_lifecycle" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish", "autoscaling:CompleteLifecycleAction"]
    resources = [aws_sns_topic.ddns_handling.arn]
  }
}

data "archive_file" "ddns_handling" {
  type        = "zip"
  source_file = "${path.module}/lambda/ddns_handling.py"
  output_path = "${path.module}/lambda/dist/ddns_handling.zip"
}

resource "aws_lambda_function" "ddns_handling" {
  depends_on = [aws_sns_topic.ddns_handling]

  filename         = data.archive_file.ddns_handling.output_path
  function_name    = "ddns_handling"
  role             = aws_iam_role.ddns_handling.arn
  handler          = "ddns_handling.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.ddns_handling.output_path)
  description      = "Handles DNS for autoscaling groups by receiving autoscaling notifications and setting/deleting records from route53"
}

resource "aws_lambda_permission" "ddns_handling" {
  depends_on = [aws_lambda_function.ddns_handling]

  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ddns_handling.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ddns_handling.arn
}

resource "aws_sns_topic_subscription" "ddns_handling" {
  depends_on = [aws_lambda_permission.ddns_handling]

  topic_arn = aws_sns_topic.ddns_handling.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ddns_handling.arn
}