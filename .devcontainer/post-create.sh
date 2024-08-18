#!/bin/bash

set -e

if [[ -z "$DYNATRACE_ENVIRONMENT_ID" ]]; then
  echo "Error: DYNATRACE_ENVIRONMENT_ID not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_ENVIRONMENT" ]]; then
  echo "Error: DYNATRACE_ENVIRONMENT not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_API_TOKEN" ]]; then
  echo "Error: DYNATRACE_API_TOKEN not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_PLATFORM_TOKEN" ]]; then
  echo "Error: DYNATRACE_PLATFORM_TOKEN not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_OAUTH_CLIENT_ID" ]]; then
  echo "Error: DYNATRACE_OAUTH_CLIENT_ID not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

if [[ -z "$DYNATRACE_OAUTH_CLIENT_SECRET" ]]; then
  echo "Error: DYNATRACE_OAUTH_CLIENT_SECRET not set. See TODO for instructions on how to start the dev container."
  exit 1
fi

kind create cluster --config .devcontainer/kind-cluster.yaml --wait 300s
kubectl cluster-info --context kind-predictive-kubernetes-scaling-demo

dynatrace/init.sh
apps/init.sh
