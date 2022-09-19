/* Sets up AWS Backup Manager to back up volumes based on tags */

resource "aws_iam_role" "splunk-backups" {
    name = "${local.name_prefix}-backup-role"
    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "backup.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
    tags = merge(local.common_tags,{ })
}

resource "aws_iam_role_policy_attachment" "backups" {
    role = aws_iam_role.splunk-backups.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "vault" {
    name = "splunk_backup"
    tags = merge(local.common_tags,{ })
}

resource "aws_backup_plan" "splunk_app_daily" {
    name = "splunk_app_volume_daily"

    rule {
        rule_name = "daily_backups"
        target_vault_name = aws_backup_vault.vault.name
        schedule = "cron(0 5 * * ? *)"
        lifecycle {
            delete_after = 7
        }
    }

    tags = merge(local.common_tags,{ })
}

resource "aws_backup_selection" "daily_volumes" {
    name = "daily_volumes"
    plan_id = aws_backup_plan.splunk_app_daily.id
    iam_role_arn = aws_iam_role.splunk-backups.arn
    resources = [ "arn:aws:ec2:*:*:volume/*" ]
    condition {
        string_equals {
            key = "aws:ResourceTag/DailyBackups"
            value = "true"
        }
    }
}

/*
resource "aws_backup_plan" "splunk_app_hourly" {
    name = "splunk_app_volume_hourly"

    rule {
        rule_name = "hourly_backups"
        target_vault_name = aws_backup_vault.vault.name
        schedule = "cron(0 * * * ? *)"
        lifecycle {
            delete_after = 1
        }
    }

    tags = merge(local.common_tags,{ })
}

resource "aws_backup_selection" "hourly_volumes" {
    name = "hourly_volumes"
    plan_id = aws_backup_plan.splunk_app_hourly.id
    iam_role_arn = aws_iam_role.splunk-backups.arn
    resources = [ "arn:aws:ec2:*:*:volume/*" ]
    condition {
        string_equals {
            key = "aws:ResourceTag/HourlyBackups"
            value = "true"
        }
    }
}
*/