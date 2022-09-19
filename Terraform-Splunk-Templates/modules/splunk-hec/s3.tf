/* Pull down the SSL private key from Secrets Manager and put into S3 for the instance to use */

/* Don't think we need this. 
data "aws_secretsmanager_secret_version" "ssl_key" {
  count = length(var.indexers)
  secret_id = var.indexers[count.index].pem_file_name
}

resource "aws_s3_object" "initial_configs" {
  bucket    = var.s3_config_bucket
  key       = "${var.hostname}/etc/auth/certs/${var.pem_file_name}"
  content = data.aws_secretsmanager_secret_version.ssl_key.secret_binary
}
*/

/* Create the user-seed.conf files */
resource "aws_s3_object" "userseed" {
  bucket    = var.s3_config_bucket
  key       = "${var.hostname}/etc/system/local/user-seed.conf"
  content = "[user_info]\nUSERNAME = ${var.admin_user}\nHASHED_PASSWORD = ${var.admin_password}"
}
