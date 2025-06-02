resource "dynatrace_credentials" "github_pat" {
  name                       = "GitHub PAT [${var.demo_name} - ${var.codespace_name}]"
  token                      = var.github_token
  allow_contextless_requests = true
  scopes = ["APP_ENGINE"]
}

resource "dynatrace_credentials" "dynatrace_platform_token" {
  name                       = "Davis CoPilot API Token [${var.demo_name} - ${var.codespace_name}]"
  token                      = var.dynatrace_platform_token
  allow_contextless_requests = true
  scopes = ["APP_ENGINE"]
}
