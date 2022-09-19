resource "aws_kms_key" "splunk" {
  deletion_window_in_days = 30
  enable_key_rotation = true
  description             = "Key for Splunk SmartStore SSE-C in S3"

  tags = merge(

    local.common_tags,
    {
      "Name" = "${local.name_prefix}-sse-splunk"
    },
  )

  policy = <<Policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow EC2 Role to use key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.splunk-instance-profile.arn}"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
Policy
}

resource "aws_kms_alias" "splunk" {
  name          = "alias/sse-splunk"
  target_key_id = aws_kms_key.splunk.id
}

/**************
*  SmartStore *
**************/

resource "aws_s3_bucket" "smartstore" {
  bucket = "${var.s3_prefix}-splunk-smartstore"
  
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-smartstore"
    },
  )
}

resource "aws_s3_bucket_acl" "smartstore" {
  bucket = aws_s3_bucket.smartstore.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "smartstore" {
  bucket = aws_s3_bucket.smartstore.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


/***********************
* Configuration Backup *
***********************/

resource "aws_s3_bucket" "config" {
  bucket = "${var.s3_prefix}-splunk-configuration-backup"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-configuration-backup"
    },
  )
}

resource "aws_s3_bucket_acl" "config" {
  bucket = aws_s3_bucket.config.id
  acl = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
    bucket = aws_s3_bucket.config.id 
    rule {
      id = "expired_after_90"
      status = "Enabled"

      filter {
        prefix = ""
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
      noncurrent_version_expiration {
        noncurrent_days = 30
      }
    }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


/******************
* Initial Configs *
******************/

resource "aws_s3_bucket" "inits" {
  bucket = "${var.s3_prefix}-splunk-initial-configs"
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-initial-configs"
    },
  )
}

resource "aws_s3_bucket_acl" "inits" {
  bucket = aws_s3_bucket.inits.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "inits" {
  bucket = aws_s3_bucket.inits.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Get files from both the dev/prod 'root' folders, as well as the splunk_common one
locals {
  init_files_raw_env = fileset("${path.root}/init_files_for_s3/", "**")
  init_files_raw_common = fileset("${path.module}/init_files_for_s3/", "**")
  init_files_env = toset([
    for f in local.init_files_raw_env:
      f if substr(f,-9,9) != ".DS_Store"
  ])
  init_files_common = toset([
    for f in local.init_files_raw_common:
      f if substr(f,-9,9) != ".DS_Store"
  ])
}

resource "aws_s3_object" "initial_configs_env" {
  for_each  = local.init_files_env
  bucket    = aws_s3_bucket.inits.id
  key       = each.value
  source    = "${path.root}/init_files_for_s3/${each.value}"
  source_hash      = filemd5("${path.root}/init_files_for_s3/${each.value}") # don't use eTag as it doesn't work for the splunk*.tgz file
}

resource "aws_s3_object" "initial_configs_common" {
  for_each  = local.init_files_common
  bucket    = aws_s3_bucket.inits.id
  key       = each.value
  source    = "${path.module}/init_files_for_s3/${each.value}"
  source_hash      = filemd5("${path.module}/init_files_for_s3/${each.value}") # don't use eTag as it doesn't work for the splunk*.tgz file
}


/*******************
* Customer Archive *
*******************/

resource "aws_s3_bucket" "customer_archive" {
  bucket = "${var.s3_prefix}-splunk-customer-archive"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-customer-archive"
    },
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "customer_archive" {
  bucket = aws_s3_bucket.customer_archive.id
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "customer_archive" {
    bucket = aws_s3_bucket.customer_archive.id 
    rule {
      id = "expired_after_365"
      status = "Enabled"

      filter {
        prefix = ""
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
      expiration {
        days = 365
      }
    }
}

resource "aws_s3_bucket_acl" "customer_archive" {
  bucket = aws_s3_bucket.customer_archive.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "customer_archive" {
  bucket = aws_s3_bucket.customer_archive.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


/**************
* POS Archive *
**************/

resource "aws_s3_bucket" "pos_archive" {
  bucket = "${var.s3_prefix}-splunk-pos-archive"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-pos-archive"
    },
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pos_archive" {
  bucket = aws_s3_bucket.pos_archive.id
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pos_archive" {
    bucket = aws_s3_bucket.pos_archive.id 
    rule {
      id = "expired_after_365"
      status = "Enabled"

      filter {
        prefix = ""
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
      expiration {
        days = 365
      }
    }
}

resource "aws_s3_bucket_acl" "pos_archive" {
  bucket = aws_s3_bucket.pos_archive.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "pos_archive" {
  bucket = aws_s3_bucket.pos_archive.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


/***********
* ALB Logs *
***********/

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.s3_prefix}-splunk-alb-logs"
  
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-alb-logs"
    },
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
    bucket = aws_s3_bucket.alb_logs.id 
    rule {
      id = "expired_after_45"
      status = "Enabled"

      filter {
        prefix = ""
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
      expiration {
        days = 45
      }
    }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
   policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.ELB_account_id}:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.s3_prefix}-splunk-alb-logs/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.s3_prefix}-splunk-alb-logs/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${var.s3_prefix}-splunk-alb-logs"
    }
  ]
}
EOF
}

resource "aws_s3_bucket_acl" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}



/*********************
* Image Builder Logs *
*********************/

resource "aws_s3_bucket" "imagebuilder_logs" {
  bucket = "${var.s3_prefix}-splunk-image-builder-logs"
  
  tags = merge(
    local.common_tags,
    {
      "Name" = "${var.s3_prefix}-splunk-image-builder-logs"
    },
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "imagebuilder_logs" {
    bucket = aws_s3_bucket.imagebuilder_logs.id 
    rule {
      id = "expired_after_30"
      status = "Enabled"

      filter {
        prefix = ""
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
      expiration {
        days = 30
      }
    }
}

resource "aws_s3_bucket_acl" "imagebuilder_logs" {
  bucket = aws_s3_bucket.imagebuilder_logs.id
  acl = "private"
}

resource "aws_s3_bucket_public_access_block" "imagebuilder_logs" {
  bucket = aws_s3_bucket.imagebuilder_logs.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
