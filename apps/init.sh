#!/bin/bash

set -e

kubectl create namespace horizontal-scaling
kubectl create namespace vertical-scaling

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

kubectl apply --filename apps/vertical-scaling/deployment.yaml

kubectl apply --filename apps/horizontal-scaling/deployment.yaml
kubectl apply --filename apps/horizontal-scaling/hpa.yaml