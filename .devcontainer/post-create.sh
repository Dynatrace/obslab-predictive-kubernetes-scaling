#!/bin/bash

set -e

if [[ -z "$DYNATRACE_ENVIRONMENT_ID" ]]; then
  echo "Error: DYNATRACE_ENVIRONMENT_ID not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_ENVIRONMENT" ]]; then
  echo "Error: DYNATRACE_ENVIRONMENT not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_API_TOKEN" ]]; then
  echo "Error: DYNATRACE_API_TOKEN not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_PLATFORM_TOKEN" ]]; then
  echo "Error: DYNATRACE_PLATFORM_TOKEN not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_OAUTH_CLIENT_ID" ]]; then
  echo "Error: DYNATRACE_OAUTH_CLIENT_ID not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_OAUTH_CLIENT_SECRET" ]]; then
  echo "Error: DYNATRACE_OAUTH_CLIENT_SECRET not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_OAUTH_CLIENT_ACCOUNT_URN" ]]; then
  echo "Error: DYNATRACE_OAUTH_CLIENT_ACCOUNT_URN not set. See https://dynatrace.github.io/obslab-predictive-kubernetes-scaling/getting-started/#1-prepare-your-environment for instructions on how to start the dev container."
  exit 1
fi

kind create cluster --config .devcontainer/kind-cluster.yaml --wait 300s
kubectl cluster-info --context kind-predictive-kubernetes-scaling-demo

dynatrace/init.sh
apps/init.sh

# Creation Ping
curl -X POST https://grzxx1q7wd.execute-api.us-east-1.amazonaws.com/default/codespace-tracker \
  -H "Content-Type: application/json" \
  -d "{
    \"tenant\": \"$DYNATRACE_ENVIRONMENT_ID\",
    \"repo\": \"$GITHUB_REPOSITORY\",
    \"demo\": \"obslab-predictive-kubernetes-scaling\",
    \"codespace.name\": \"$CODESPACE_NAME\"
  }"
