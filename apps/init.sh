#!/bin/bash

set -e

kubectl create namespace horizontal-scaling
kubectl create namespace vertical-scaling
kubectl create ns otel-demo
kubectl label namespace  default oneagent=false
kubectl label namespace otel-demo  oneagent=false
######################
### metrics-server ###
######################

# https://artifacthub.io/packages/helm/metrics-server/metrics-server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server \
  --version 3.12.1 \
  --namespace horizontal-scaling \
  --values apps/metrics-server.values.yaml \
  --atomic --wait

############
### Apps ###
############
kubectl apply -f  apps/opentelemetry/rbac.yaml
kubectl apply -f apps/openTelemetry-manifest_statefulset.yaml

kubectl apply --filename apps/vertical-scaling/deployment.yaml

kubectl apply --filename apps/horizontal-scaling/deployment.yaml
kubectl apply --filename apps/horizontal-scaling/hpa.yaml

kubectl apply -k apps/otel-demo -n otel-demo
