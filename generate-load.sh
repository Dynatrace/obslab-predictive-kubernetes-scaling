#!/bin/bash

echo "Which workload would you like to generate load on?"
select namespace in horizontal-scaling vertical-scaling
do
  # Port forward the Kubernetes deployment to port 8080
  echo "Port forwarding to $namespace/anomaly-simulation..."
  kubectl -n $namespace port-forward deployment/anomaly-simulation 8080:8080 > /dev/null 2>&1 &
  portforward_pid=$!

  # Kill the port-forward regardless of how this script exits
  trap '{
      kill $portforward_pid
  }' EXIT

  ## Wait a bit to make sure port 8080 is available
  sleep 3

  # Configure the service to increase resource consumption
  echo "Generating load..."
  curl -X POST [::1]:8080/config --data '{"ResourceConfig":{"Severity":1000,"Count":100}}'

  # Finally send some requests
  for ((i = 100; i > 0; i--)); do
    curl -s -o /dev/null [::1]:8080
    sleep "$(echo "0.05 * $i" | bc -l)"
  done

  echo 'All done! You are ready to run the "Predict Kubernetes Resource Usage" workflow.'
done
