#!/bin/bash
################################################################################
### Script deploying the Observ-K8s environment
### Parameters:
### clustername : only required if not triggered in a codespace; define the name of the environemnt
### githubtoken : only requried if not triggered in a codespace
### deploymentmode: if empty then it means it has been trigered by a codespace, otherwise you can pass any string : gke, aws, kind
################################################################################

### Pre-flight checks for dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Please install jq before continuing"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Please install git before continuing"
    exit 1
fi


if ! command -v helm >/dev/null 2>&1; then
    echo "Please install helm before continuing"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Please install kubectl before continuing"
    exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
    echo "Please install terraform before continuing"
    exit 1
fi

set -e

echo "parsing arguments"
while [ $# -gt 0 ]; do
  case "$1" in
     --deploymentmode)
      DEPLOY_MODE="$2"
       shift 2
        ;;
    --githubtoken)
        GITHUB_TOKEN="$2"
         shift 2
          ;;
    --clustername)
        CLUSTERNAME="$2"
         shift 2
          ;;
  *)
    echo "Warning: skipping unsupported option: $1"
    shift
    ;;
  esac
done

### checking environment variables
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

if [[ -z "$DEPLOY_MODE" ]]; then
  DEPLOY_MODE="git"
fi

if [[  "$DEPLOY_MODE" == "git" ]]; then
  echo "Creating Cluster"
  kind create cluster --config .devcontainer/kind-cluster.yaml --wait 300s
  kubectl cluster-info --context kind-predictive-kubernetes-scaling-demo
else
  if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN not set."
    exit 1
  fi
  if [[ -z "$CLUSTERNAME" ]]; then
    echo "Error: CLUSTERNAME not set."
    exit 1
  fi

  export GITHUB_TOKEN=$GITHUB_TOKEN
  export CODESPACE_NAME=$CLUSTERNAME
fi

dynatrace/init.sh
apps/init.sh

if [[   "$DEPLOY_MODE" == "git"  ]]; then
  # Creation Ping
  curl -X POST https://grzxx1q7wd.execute-api.us-east-1.amazonaws.com/default/codespace-tracker \
    -H "Content-Type: application/json" \
    -d "{
      \"tenant\": \"$DYNATRACE_ENVIRONMENT_ID\",
      \"repo\": \"$GITHUB_REPOSITORY\",
      \"demo\": \"obslab-predictive-kubernetes-scaling\",
      \"codespace.name\": \"$CODESPACE_NAME\"
    }"
fi
