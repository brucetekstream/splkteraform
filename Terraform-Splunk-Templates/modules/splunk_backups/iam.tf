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




resource "aws_iam_role" "lambda_backups" {
  name = "lambda_backups"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

}
resource "aws_iam_role_policy" "lambda_backups" {
  name = "lambda_backups"
  role = aws_iam_role.lambda_backups.name

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
        "ec2:*"
      ],
      "Effect":"Allow",
      "Resource":"*"
    }
  ]
}
EOF

}
