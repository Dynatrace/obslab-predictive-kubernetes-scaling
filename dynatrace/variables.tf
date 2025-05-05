variable "github_token" {
  type      = string
  sensitive = true
}

variable "dynatrace_platform_token" {
  type      = string
  sensitive = true
}

variable "dynatrace_oauth_client_id" {
  type      = string
  sensitive = true
}

variable "dynatrace_oauth_client_secret" {
  type      = string
  sensitive = true
}

variable "dynatrace_oauth_client_account_urn" {
  type      = string
  sensitive = true
}

variable "dynatrace_live_url" {
  type = string
}

variable "dynatrace_apps_url" {
  type = string
}


variable "codespace_name" {
  type = string
}

variable "demo_name" {
  type    = string
  default = "Predictive Kubernetes Scaling"
}

variable "annotation_prefix" {
  type    = string
  default = "predictive-kubernetes-scaling.observability-labs.dynatrace.com"
}