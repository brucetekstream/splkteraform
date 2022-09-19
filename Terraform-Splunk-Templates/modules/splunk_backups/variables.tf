
variable "common_tags" {
  type = map(string)

  default = {
    Module = "splunk_backups"
  }
}

variable "hourly_backups_tags" {
  type = list(string)
  default = []
}

variable "daily_backups_tags" {
  type = list(string)
  default = []
}

variable "hourly_backups_retention" {
  default = 1
}
variable "daily_backups_retention" {
  default = 1
}