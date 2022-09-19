/* Pull down the SSL private key from Secrets Manager and put into S3 for the instance to use */

data "aws_secretsmanager_secret_version" "ssl_key" {
  count = var.pem_file_name != "" ? 1 : 0
  secret_id = var.pem_file_name
}

resource "aws_s3_object" "initial_configs" {
  count = var.pem_file_name != "" ? 1 : 0
  bucket    = var.s3_config_bucket
  key       = "${var.hostname}/etc/auth/certs/${var.pem_file_name}"
  content = data.aws_secretsmanager_secret_version.ssl_key[0].secret_binary
}

/* Create the user-seed.conf files */
resource "aws_s3_object" "userseed" {
  bucket    = var.s3_config_bucket
  key       = "${var.hostname}/etc/system/local/user-seed.conf"
  content = "[user_info]\nUSERNAME = ${var.admin_user}\nHASHED_PASSWORD = ${var.admin_password}"
}
