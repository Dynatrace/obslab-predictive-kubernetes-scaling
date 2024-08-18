variable "github_token" {
  type      = string
  sensitive = true
}

variable "dynatrace_platform_token" {
  type      = string
  sensitive = true
}

variable "dynatrace_live_url" {
  type = string
}

variable "dynatrace_environment_id" {
  type = string
}

variable "codespace_name" {
  type = string
}

variable "demo_name" {
  type    = string
  default = "Predictive Kubernetes Scaling"
}

variable "demo_name_kebab" {
  type    = string
  default = "predictive-kubernetes-scaling"
}

variable "annotation_prefix" {
  type    = string
  default = "predictive-kubernetes-scaling.observability-labs.dynatrace.com"
}