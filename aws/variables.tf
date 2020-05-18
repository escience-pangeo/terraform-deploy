variable "region" {
  default = "us-west-2"
}

variable "profile" {
  default = "escience-bot"
}

variable "cluster_name" {
  default = "dssg2020-eicompare"
}

variable "vpc_name" {
  default = "dssg2020-eicompare"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)
  default = [ ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
  ]
}

variable "grafana_admin" {
  default = "admin"
}

variable "grafana_password" {
  default = ""
}

variable "namespace_prod" {
  default = "production"
}

variable "namespace_staging" {
  default = "staging"
}
