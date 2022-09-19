/* Pull down the SSL private key from Secrets Manager and put into S3 for the instance to use */

data "aws_secretsmanager_secret_version" "ssl_key" {
  count = length(var.indexers)
  secret_id = var.indexers[count.index].pem_file_name
}

resource "aws_s3_object" "initial_configs" {
  count = length(var.indexers)
  bucket    = var.s3_config_bucket
  key       = "${var.indexers[count.index].hostname}/etc/auth/certs/${var.indexers[count.index].pem_file_name}"
  content = data.aws_secretsmanager_secret_version.ssl_key[count.index].secret_binary
}

/* Create the user-seed.conf files */
resource "aws_s3_object" "userseed" {
  count = length(var.indexers)
  bucket    = var.s3_config_bucket
  key       = "${var.indexers[count.index].hostname}/etc/system/local/user-seed.conf"
  content = "[user_info]\nUSERNAME = ${var.admin_user}\nHASHED_PASSWORD = ${var.admin_password}"
}
