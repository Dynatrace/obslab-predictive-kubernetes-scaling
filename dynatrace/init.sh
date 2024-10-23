#!/bin/bash

set -e

cd dynatrace || exit

######################
### Infrastructure ###
######################

# Get Dynatrace URLs
environment="$DYNATRACE_ENVIRONMENT"
typeset -l environment
if [ "$environment" == "live" ]; then
  export DYNATRACE_LIVE_URL="$DYNATRACE_ENVIRONMENT_ID.live.dynatrace.com"
  export DYNATRACE_APPS_URL="$DYNATRACE_ENVIRONMENT_ID.apps.dynatrace.com"
  export DYNATRACE_SSO_URL="sso.dynatrace.com/sso/oauth2/token"
else
  export DYNATRACE_LIVE_URL="$DYNATRACE_ENVIRONMENT_ID.$environment.dynatracelabs.com"
  export DYNATRACE_APPS_URL="$DYNATRACE_ENVIRONMENT_ID.$environment.apps.dynatracelabs.com"
  export DYNATRACE_SSO_URL="sso-$environment.dynatracelabs.com/sso/oauth2/token"
fi

# Prepare environment for Terraform
export TF_VAR_github_token=$GITHUB_TOKEN
export TF_VAR_dynatrace_platform_token=$DYNATRACE_PLATFORM_TOKEN
export TF_VAR_dynatrace_live_url="https://$DYNATRACE_LIVE_URL"
export TF_VAR_dynatrace_environment_id=$DYNATRACE_ENVIRONMENT_ID
export TF_VAR_codespace_name=$CODESPACE_NAME

export DYNATRACE_AUTOMATION_CLIENT_ID=$DYNATRACE_OAUTH_CLIENT_ID
export DYNATRACE_AUTOMATION_CLIENT_SECRET=$DYNATRACE_OAUTH_CLIENT_SECRET

terraform init

#############################
### Kubernetes Monitoring ###
#############################

# Deploy Kubernetes operator tokens
terraform apply -target=dynatrace_api_token.kubernetes_operator -target=dynatrace_api_token.kubernetes_data_ingest -auto-approve

DYNATRACE_KUBERNETES_OPERATOR_TOKEN="$(terraform output kubernetes_operator_token | tr -d '"')"
export DYNATRACE_KUBERNETES_OPERATOR_TOKEN

DYNATRACE_KUBERNETES_DATA_INGEST_TOKEN="$(terraform output kubernetes_data_ingest_token | tr -d '"')"
export DYNATRACE_KUBERNETES_DATA_INGEST_TOKEN

# Install & configure Dynatrace operator
helm install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --version 1.3.1 \
  --create-namespace --namespace dynatrace \
  --values ./kubernetes/operator.values.yaml \
  --atomic --wait

kubectl --namespace dynatrace \
  create secret generic predictive-kubernetes-scaling-demo \
  --from-literal=apiToken="$DYNATRACE_KUBERNETES_OPERATOR_TOKEN" \
  --from-literal=dataIngestToken="$DYNATRACE_KUBERNETES_DATA_INGEST_TOKEN"

sed -i "s|DYNATRACE_LIVE_URL|$DYNATRACE_LIVE_URL|g" kubernetes/dynakube.yaml

kubectl apply --filename kubernetes/dynakube.yaml

###############################
### Kubernetes Edge Connect ###
###############################

kubectl --namespace dynatrace \
  create secret generic "edge-connect-${CODESPACE_NAME:0:40}-credentials" \
  --from-literal=oauth-client-id="$DYNATRACE_OAUTH_CLIENT_ID" \
  --from-literal=oauth-client-secret="$DYNATRACE_OAUTH_CLIENT_SECRET"

sed -i "s|CODESPACE_NAME|${CODESPACE_NAME:0:40}|g" kubernetes/edge-connect.yaml
sed -i "s|DYNATRACE_ENVIRONMENT_ID|$DYNATRACE_ENVIRONMENT_ID|g" kubernetes/edge-connect.yaml
sed -i "s|DYNATRACE_APPS_URL|$DYNATRACE_APPS_URL|g" kubernetes/edge-connect.yaml
sed -i "s|DYNATRACE_SSO_URL|$DYNATRACE_SSO_URL|g" kubernetes/edge-connect.yaml

kubectl apply --filename kubernetes/edge-connect.yaml

# Sleep a bit to allow the Edge Connect to start
sleep 60

######################
### Infrastructure ###
######################

# Finally deploy all infrastructure
terraform apply -auto-approve
