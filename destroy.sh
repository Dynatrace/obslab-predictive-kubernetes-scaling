#!/bin/bash

set -e

######################
### Infrastructure ###
######################

cd dynatrace || exit

# Get Dynatrace URLs
environment="$DYNATRACE_ENVIRONMENT"
typeset -l environment
if [ "$environment" == "live" ]; then
  export DYNATRACE_LIVE_URL="https://$DYNATRACE_ENVIRONMENT_ID.live.dynatrace.com"
else
  export DYNATRACE_LIVE_URL="https://$DYNATRACE_ENVIRONMENT_ID.$environment.dynatracelabs.com"
fi

# Prepare environment for Terraform
export TF_VAR_github_token=$GITHUB_TOKEN
export TF_VAR_dynatrace_platform_token=$DYNATRACE_PLATFORM_TOKEN
export TF_VAR_dynatrace_live_url=$DYNATRACE_LIVE_URL
export TF_VAR_dynatrace_environment_id=$DYNATRACE_ENVIRONMENT_ID

export DYNATRACE_AUTOMATION_CLIENT_ID=$DYNATRACE_OAUTH_CLIENT_ID
export DYNATRACE_AUTOMATION_CLIENT_SECRET=$DYNATRACE_OAUTH_CLIENT_SECRET

# Destroy infrastructure
terraform destroy -auto-approve

cd ..

##########################
### Kubernetes Cluster ###
##########################

kubectl delete --namespace dynatrace edgeconnect $CODESPACE_NAME-hpa-reader

kind delete cluster --name predictive-kubernetes-scaling-demo