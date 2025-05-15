resource "dynatrace_api_token" "manage_workflows" {
  provider = dynatrace.get_tokens
  name     = "Manage Workflow [${var.demo_name} - ${var.codespace_name}]"
  enabled  = true
  scopes = [
    // Manage credentials in the credential Vault
    "credentialVault.read",
    "credentialVault.write",
    // Manage GitHub connections
    "settings.read",
    "settings.write",
  ]
}

resource "dynatrace_api_token" "kubernetes_operator" {
  provider = dynatrace.get_tokens
  name     = "Kubernetes Operator [${var.demo_name} - ${var.codespace_name}]"
  enabled  = true
  scopes = [
    "activeGateTokenManagement.create",
    "entities.read",
    "settings.read",
    "settings.write",
    "DataExport",
    "InstallerDownload"
  ]
}

resource "dynatrace_api_token" "kubernetes_data_ingest" {
  provider = dynatrace.get_tokens
  name     = "Kubernetes Data Ingest [${var.demo_name} - ${var.codespace_name}]"
  enabled  = true
  scopes = [
    "metrics.ingest"
  ]
}
