
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu 22.04 AMI ID."
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ssh_cidr" {
  type        = string
  description = "CIDR range allowed to connect through SSH."

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0)) && !endswith(var.ssh_cidr, "/0")
    error_message = "Enter a valid CIDR range that does not allow SSH from everywhere."
  }
}

variable "admin_user" {
  type    = string
  default = "deploy"
}

variable "admin_ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for the admin user."
  default     = []
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}