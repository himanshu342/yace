variable "name" {
  type = "string"
  default = "yace-comments"
  description = "A name for your yace instance. This is primarily necessary if you want to run multiple instances alongside one another."
}

variable "enable_auto_backup" {
  default = false
  description = "Whether to automatically create backups of your data. Note that this will incur additional charges."
}

variable "service_url" {
  default = ""
  description = "The URL to run the service at, necessary for token URLs. No trailing slash. Uses the default API Gateway invoke URL if left empty."
}

variable "token_sender" {
  description = "The email address to list as the sender of the token emails."
}
variable "token_recipients" {
  description = "A comma-separated list of recipients for the token emails."
}

variable "smtp_host" {
  description = "The SMTP host to use to deliver token emails for new comments."
}
variable "smtp_port" {
  default = 465
  description = "The SMTP port to use to deliver token emails for new comments."
}
variable "smtp_secure" {
  default = "true"
  description = "Whether to connect securely to the SMTP host to use to deliver token emails for new comments. From the nodemail docs: 'if true, the connection will use TLS when connecting to server. If false, TLS is used if server supports the STARTTLS extension. In most cases set this value to true if you are connecting to port 465. For port 587 or 25 keep it false'."
}
variable "smtp_user" {
  description = "The SMTP user to use to deliver token emails for new comments."
}
variable "smtp_password" {
  description = "The SMTP user's password to use to deliver token emails for new comments."
}
