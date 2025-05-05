terraform {
  required_providers {
    dynatrace = {
      source = "dynatrace-oss/dynatrace"
      version = "1.79.3"
    }
  }
}

provider "dynatrace" {
  alias = "get_tokens"
  dt_env_url = var.dynatrace_live_url
}

provider "dynatrace" {
  dt_env_url = var.dynatrace_live_url
  dt_api_token = dynatrace_api_token.manage_workflows.token
}