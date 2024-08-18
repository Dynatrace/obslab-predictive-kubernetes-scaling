output "kubernetes_operator_token" {
  value     = dynatrace_api_token.kubernetes_operator.token
  sensitive = true
}

output "kubernetes_data_ingest_token" {
  value     = dynatrace_api_token.kubernetes_data_ingest.token
  sensitive = true
}