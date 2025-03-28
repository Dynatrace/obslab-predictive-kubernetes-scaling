# Observability Lab: Predictive Auto-Scaling for Kubernetes Workloads

Struggling to keep up with the demands of dynamic Kubernetes environments? Manual scaling is not only time-consuming and
reactive but also prone to errors. In this demo we harness the power of Dynatrace Automations and Davis AI to predict
resource bottlenecks and automatically open pull requests to scale applications. This proactive approach minimizes
downtime, helps you to optimize resource utilization, and ensures your applications perform at their best.

Watch the full companion video on YouTube:

[![Watch it on YouTube](https://img.youtube.com/vi/EMw-MUZi-xk/0.jpg)](https://www.youtube.com/watch?v=EMw-MUZi-xk)

## [Start the hands-on here >>](https://dynatrace.github.io/obslab-predictive-kubernetes-scaling)

### 2.Create a GKE cluster
```shell
ZONE=europe-west3-a
NAME=isitobservable-predectivescaling
gcloud container clusters create ${NAME} --zone=${ZONE} --machine-type=e2-standard-4 --num-nodes=2
```


```shell
export DYNATRACE_ENVIRONMENT_ID=<environment id >
export DYNATRACE_ENVIRONMENT=<dev/prod/staging>
export DYNATRACE_API_TOKEN=<api token>
export DYNATRACE_PLATFORM_TOKEN=<platform token>
export DYNATRACE_OAUTH_CLIENT_ID=<oauth token>
export DYNATRACE_OAUTH_CLIENT_SECRET=<oaout secret>
.devcontainer/post-create.sh --deploymentmode gke
```
