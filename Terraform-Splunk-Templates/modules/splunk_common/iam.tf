/* Splunk instance role and policy */

data "aws_iam_policy_document" "splunk-instance-profile" {
  statement {
    sid = "allowTagsread"
    actions = [
              "ec2:DescribeTags",
              "s3:ListAllMyBuckets",
              "s3:ListBucket"
    ]
    resources = ["*"]
  }

  statement {
    sid = "allowputcwalarms"
    actions = [
              "cloudwatch:PutMetricAlarm"
    ]
    resources = ["*"]
  }

  statement {
    sid = "allowS3accesss"
    actions = [
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:DeleteObject*",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
        aws_s3_bucket.smartstore.arn, 
        "${aws_s3_bucket.smartstore.arn}/*",
        aws_s3_bucket.config.arn, 
        "${aws_s3_bucket.config.arn}/*",
        aws_s3_bucket.inits.arn,
        "${aws_s3_bucket.inits.arn}/*",
        aws_s3_bucket.customer_archive.arn,
        "${aws_s3_bucket.customer_archive.arn}/*",
        aws_s3_bucket.pos_archive.arn,
        "${aws_s3_bucket.pos_archive.arn}/*",
        aws_s3_bucket.alb_logs.arn,
        "${aws_s3_bucket.alb_logs.arn}/*"
        ]
  }

  statement {
    sid = "allowS3listaccesss"
    actions = [
      "s3:ListAllMyBuckets", 
            "s3:GetBucketLocation" 
    ]
    resources = [
      "arn:aws:s3:::*"
    ]
  }

  statement {
    sid = "allowListAccountAliases"
    actions = [
      "iam:ListAccountAliases"
    ]
    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "splunk-instance-profile" {

  name        = "${local.name_prefix}-instance-policy"
  description = "Default instance profile for splunk servers"

  policy = data.aws_iam_policy_document.splunk-instance-profile.json
}

resource "aws_iam_role" "splunk-instance-profile" {
  #count = var.create_ssm_roles ? 1 : 0
  name    = "${local.name_prefix}-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "splunk-instance-profile" {
  name    = "${local.name_prefix}-ec2-role"
  role = aws_iam_role.splunk-instance-profile.name
}

locals{
  splunk_role_attachment = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
                            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
                            aws_iam_policy.splunk-instance-profile.arn                           ]
}
resource "aws_iam_role_policy_attachment" "splunk-instance-profile" {
  count      = length(local.splunk_role_attachment)
  role       = aws_iam_role.splunk-instance-profile.name
  policy_arn = local.splunk_role_attachment[count.index]
}


/* Splunk first-time setup role and policy */
/* Basically, inherit what the splunk-ec2-role has, plus more */

data "aws_iam_policy_document" "splunk-instance-setup-profile" {
  statement {
    sid = "replaceIAMRole"
    actions = [
      "ec2:ReplaceIamInstanceProfileAssociation"
    ]
    resources = [ 
      "arn:aws:ec2:*:*:instance/*"
    ]
  }

  statement {
    sid = "passRole"
    actions = [ 
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::*:role/${local.name_prefix}-ec2-role"
    ]
  }

  statement {
    sid = "allowInitialSetup"
    actions = [ 
      "ec2:CreateVolume",
      "ec2:AttachVolume",
      "ec2:ModifyVolume",
      "ec2:CreateTags",
      "secretsmanager:GetSecretValue",
    ]
    resources = [ 
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:instance/*",
      "arn:aws:secretsmanager:*:*:secret:splunk.secret-*", # Add -* to the end since Secrets MManager adds 6 digits to end of ARN
    ]
  }

  statement {
    sid = "describeObjects"
    actions = [ 
      "ec2:DescribeIamInstanceProfileAssociations",
      "ec2:DescribeSnapshots"
    ]
    resources = [ "*" ]
  }

}

resource "aws_iam_policy" "splunk-instance-setup-profile" {

  name        = "${local.name_prefix}-instance-setup-policy"
  description = "Initial instance profile for splunk servers"

  policy = data.aws_iam_policy_document.splunk-instance-setup-profile.json
}

resource "aws_iam_role" "splunk-instance-setup-profile" {
  #count = var.create_ssm_roles ? 1 : 0
  name    = "${local.name_prefix}-ec2-setup-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "splunk-instance-setup-profile" {
  name    = "${local.name_prefix}-ec2-setup-role"
  role = aws_iam_role.splunk-instance-setup-profile.name
}

locals{
  splunk_setup_role_attachment = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
                            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
                            aws_iam_policy.splunk-instance-profile.arn,
                            aws_iam_policy.splunk-instance-setup-profile.arn 
                            ]
}
resource "aws_iam_role_policy_attachment" "splunk-instance-setup-profile" {
  count      = length(local.splunk_setup_role_attachment)
  role       = aws_iam_role.splunk-instance-setup-profile.name
  policy_arn = local.splunk_setup_role_attachment[count.index]
}




/****************************
* CloudwatchAWSAlert Lambda *
****************************/

data "aws_iam_policy_document" "lambda_cloudwatch_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_CloudWatchAWSAlert" {
  name = "lambda_CloudWatchAWSAlert"
  assume_role_policy = data.aws_iam_policy_document.lambda_cloudwatch_assume.json

}

resource "aws_iam_role_policy" "lambda_CloudWatchAWSAlert" {
  name = "lambda_CloudWatchAWSAlert"
  role = aws_iam_role.lambda_CloudWatchAWSAlert.name

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
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:secretsmanager:*:*:secret:<customer>TeamsWebHookSecret*"
    },
    {
      "Action": [
        "cloudwatch:ListTagsForResource"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:cloudwatch:*:*:alarm:*"
    }
  ]
}
EOF

}


/***********************
* DeleteOldAMIs Lambda *
***********************/

data "aws_iam_policy_document" "lambda_deleteami_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_DeleteOldAMIs" {
  name = "lambda_DeleteOldAMIs"
  assume_role_policy = data.aws_iam_policy_document.lambda_deleteami_assume.json

}

resource "aws_iam_role_policy" "lambda_DeleteOldAMIs" {
  name = "lambda_DeleteOldAMIs"
  role = aws_iam_role.lambda_DeleteOldAMIs.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:DescribeImages",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "ec2:DeregisterImage",
                "ec2:DeleteSnapshot",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*",
                "arn:aws:ec2:*::snapshot/*",
                "arn:aws:ec2:*::image/*"
            ]
        }
    ]
}
EOF

}


/****************************
* SetMaintenanceMode Lambda *
****************************/

data "aws_iam_policy_document" "lambda_SetMaintenanceMode" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_SetMaintenanceMode" {
  name = "lambda_SetMaintenanceMode"
  assume_role_policy = data.aws_iam_policy_document.lambda_SetMaintenanceMode.json

}

resource "aws_iam_role_policy" "lambda_SetMaintenanceMode" {
  name = "lambda_SetMaintenanceMode"
  role = aws_iam_role.lambda_SetMaintenanceMode.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "arn:aws:secretsmanager:*:*:secret:adminUser-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
              "ec2:CreateNetworkInterface",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DeleteNetworkInterface"
            ],
            "Resource": [
              "*"
            ]
        }
    ]
}
EOF

}
