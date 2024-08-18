locals {
  from = "now()-1h"
  to   = "now()"
  notebook = jsonencode({
    "version" = "6"
    "defaultTimeframe" = {
      "from" = local.from
      "to"   = local.to
    }
    "sections" = [
      {
        id       = "ab5431e7-83bb-47c9-a6d0-ad933be56e20"
        type     = "markdown"
        markdown = <<-EOT
          # ${var.demo_name}

          Struggling to keep up with the demands of dynamic Kubernetes environments? Manual scaling is not only time-consuming and reactive but also prone to errors. We're harnessing the power of Dynatrace Automations and Davis AI to predict resource bottlenecks and automatically open pull requests to scale applications. This proactive approach minimizes downtime, helps you to optimize resource utilization, and ensures your applications perform at their best.

          We achieve this by combining predictive AI to forecast resource limitations with generative AI to modify Kubernetes manifests on GitHub by creating pull requests for scaling adjustments. If you'd like a closer look at how this works, check out the following sections.

          > This notebook does not do any scaling. It is just an additional resource that helps you to understand how the actual automation can be done by [Dynatrace Workflows](https://www.dynatrace.com/platform/workflows/). If you want to try this yourself, you can run a full demo in your own Dynatrace tenant by following [this tutorial](TODO)."
      EOT
      },
      {
        id       = "aaabe140-3570-4d58-a56b-af5c06dca5d1"
        type     = "markdown"
        markdown = <<-EOT
          ## 1. Find Workloads to Scale

          To kick things off, we need to identify the Kubernetes workloads our automation workflow will manage. While theoretically we could include all workloads, that might lead to lengthy workflow execution times. Instead, we've opted to focus on Kubernetes workloads where the annotation `observability-labs.dynatrace.com/commit-scaling-suggestions` is set to `true`.

          The following Dynatrace Query Language (DQL) query shows these selected workloads.
        EOT
      },
      {
        id        = "de2945f0-ce42-4fdc-9b20-ca6076cc7d8d"
        type      = "dql"
        showTitle = false
        height    = 250
        state = {
          input = {
            value = chomp(
              <<-EOT
              fetch dt.entity.cloud_application
              | filter kubernetesAnnotations[`predictive-kubernetes-scaling.observability-labs.dynatrace.com/enabled`] == "true"
              | fields k8s.cluster.id = clustered_by[`dt.entity.kubernetes_cluster`], k8s.namespace.name = namespaceName, k8s.workload.name = entity.name, k8s.workload.annotations = kubernetesAnnotations, type = arrayFirst(cloudApplicationDeploymentTypes)
              | join [ fetch dt.entity.kubernetes_cluster ],
                on: { left[k8s.cluster.id] == right[id] },
                fields: { k8s.cluster.name = entity.name }
              | fields type, k8s.cluster.name, k8s.cluster.id, k8s.namespace.name, k8s.workload.name, k8s.workload.annotations
              EOT
            )
            timeframe = {
              from = "-5m"
              to   = local.to
            }
          }
          visualization = "table"
        }
      },
      {
        id       = "af27fbe8-e4b7-4c39-bcaf-247a3b5f5cfa",
        type     = "markdown",
        markdown = <<-EOT
          ## 2. Predict Resource Usage

          With our target workloads identified, we'll utilize Dynatrace Davis AI to forecast their future CPU and memory consumption. This will help us determine if they're likely to exceed their defined Kubernetes resource limits.

          To get a sneak peek of the prediction query that will be used in the workflow, you can execute the following DQL query.

          > **Note**: The query result will include two entries per workload, one for predicted CPU usage and one for predicted memory usage.
        EOT
      },
      {
        id        = "d88e4bb9-d763-4e74-9750-523c4db93dc3"
        type      = "dql"
        showTitle = false
        height    = 600
        state = {
          input = {
            value = chomp(
              <<-EOT
              timeseries {
                memoryUsage = avg(dt.kubernetes.container.memory_working_set),
                cpuUsage = avg(dt.kubernetes.container.cpu_usage)
              },
              by:{k8s.cluster.name, k8s.namespace.name, k8s.workload.kind, k8s.workload.name}
              | filter k8s.cluster.name == "predictive-kubernetes-scaling-demo" and k8s.workload.name == "anomaly-simulation"
              EOT
            )
            timeframe = {
              from = local.from
              to   = local.to
            }
          }
          querySettings = {
            maxResultRecords = 1000
            defaultScanLimitGbytes = 500
            maxResultMegaBytes = 1
            defaultSamplingRatio = 10
            enableSampling = false
          }
          visualization = "davis"
          davis = {
            enabled = true
            componentState = {
              selectedAnalyzerName = "dt.statistics.ui.ForecastAnalyzer"
              inputData = {
                "dt.statistics.ui.ForecastAnalyzer" = {
                  generalParameters = {
                    timeframe = {
                      startTime = local.from
                      endTime   = local.to
                    }
                    resolveDimensionalQueryData = true
                  }
                  forecastHorizon = 100
                  forecastOffset  = 1
                  query = chomp(
                    <<-EOT
                    timeseries {
                      memoryUsage = avg(dt.kubernetes.container.memory_working_set),
                      cpuUsage = avg(dt.kubernetes.container.cpu_usage)
                    },
                    by:{k8s.cluster.name, k8s.namespace.name, k8s.workload.kind, k8s.workload.name}
                    | filter k8s.cluster.name == "predictive-kubernetes-scaling-demo" and k8s.workload.name == "anomaly-simulation"
                    EOT
                  )
                }
              }
            }
          }
        }
      },
      {
        id       = "66c1701b-4883-4ff0-a15d-a978aa8016cf",
        type     = "markdown",
        markdown = <<-EOT
          ### 3. Emit Events

          The final step of the first workflow is to analyze the prediction results and emit a Davis event of type `CUSTOM_INFO` for each workload that needs scaling. This event is associated with the respective Kubernetes workload and includes the scaling prompt and the reasoning behind the decision. By emitting these events, we enable other automations to react and trigger the necessary scaling adjustments.

          To get a preview of these events, execute the following DQL query.
        EOT
      },
      {
        id        = "97e574bd-e2c4-427e-b05a-945a93cf6a52"
        type      = "dql"
        showTitle = false
        height    = 250
        state = {
          input = {
            value = chomp(
              <<-EOT
              fetch events
              | filter event.type == "CUSTOM_INFO" and kubernetes.predictivescaling.type == "DETECT_SCALING"
              | fields
                timestamp,
                event.name,
                event.category,
                event.type,
                kubernetes.predictivescaling.workload.cluster.name,
                kubernetes.predictivescaling.workload.cluster.id,
                kubernetes.predictivescaling.workload.kind,
                kubernetes.predictivescaling.workload.namespace,
                kubernetes.predictivescaling.workload.name,
                kubernetes.predictivescaling.workload.uuid,
                kubernetes.predictivescaling.workload.limits.memory,
                kubernetes.predictivescaling.workload.limits.cpu,
                kubernetes.predictivescaling.prediction.type,
                kubernetes.predictivescaling.prediction.prompt,
                kubernetes.predictivescaling.prediction.description,
                kubernetes.predictivescaling.prediction.suggestions,
                kubernetes.predictivescaling.target.uuid,
                kubernetes.predictivescaling.target.repository
              EOT
            )
            timeframe = {
              from = local.from
              to   = local.to
            }
          }
          visualization = "table"
        }
      },
      {
        id       = "402a7e81-541a-4808-be25-50b717aeaafe",
        type     = "markdown",
        markdown = <<-EOT
          ## 4. Apply Suggestions

          That wraps up the first workflow. In essence, it identifies workloads to scale, predicts their resource usage, and emits events signaling the need for scaling adjustments. These events then trigger a second workflow that takes over the actual scaling process.

          While we can't demonstrate this second workflow through DQL queries here, you can explore it firsthand by following [this tutorial](TODO). Here's what the second workflow does in a nutshell:

          - **Search for the Deployment Manifest on GitHub**: The workflow locates the relevant Kubernetes deployment manifest in your GitHub repository. It identifies the correct repository using the `observability-labs.dynatrace.com/managed-by-repo` annotation and then utilizes the GitHub Search API to find the correct file.
          - **Apply Suggestions with Davis CoPilot**: The workflow uses [Davis CoPilot](TODO) to apply the scaling suggestions to the fetched manifest. This step intelligently modifies the manifest to reflect the required resource adjustments.

          TODO image

          - **Create a Pull Request on GitHub**: Finally, the workflow employs the [GitHub for Workflows app](TODO) to create a pull request on GitHub, proposing the changes to the deployment manifest. This PR can then be reviewed and merged to implement the scaling updates in your Kubernetes environment.

          TODO image
        EOT
      },
      {
        id       = "992ba2eb-1ec3-4d42-a078-0e13568387ce",
        type     = "markdown",
        markdown = <<-EOT
          ## 5. Emit Info Event

          As a final step, the second workflow emits an additional event of type `CUSTOM_INFO`. This event serves as a record of the scaling PR being created and includes details about the associated workload and the changes made. While not triggering any further automations, this event is attached to the relevant workload and can be queried in Dynatrace for auditing and reporting purposes.

          Execute the following DQL query to preview these events:
        EOT
      },
      {
        id        = "97e574bd-e2c4-427e-b05a-945a93cf6a52"
        type      = "dql"
        showTitle = false
        height    = 250
        state = {
          input = {
            value = chomp(
              <<-EOT
              fetch events
              | filter event.type == "CUSTOM_INFO" and kubernetes.predictivescaling.type == "SUGGEST_SCALING"
              | fields
                timestamp,
                event.name,
                event.category,
                event.type,
                kubernetes.predictivescaling.workload.cluster.name,
                kubernetes.predictivescaling.workload.cluster.id,
                kubernetes.predictivescaling.workload.kind,
                kubernetes.predictivescaling.workload.namespace,
                kubernetes.predictivescaling.workload.name,
                kubernetes.predictivescaling.workload.uuid,
                kubernetes.predictivescaling.workload.limits.memory,
                kubernetes.predictivescaling.workload.limits.cpu,
                kubernetes.predictivescaling.prediction.type,
                kubernetes.predictivescaling.prediction.prompt,
                kubernetes.predictivescaling.prediction.description,
                kubernetes.predictivescaling.prediction.suggestions,
                kubernetes.predictivescaling.target.uuid,
                kubernetes.predictivescaling.target.repository,
                kubernetes.predictivescaling.pullrequest.id,
                kubernetes.predictivescaling.pullrequest.url
                EOT
            )
            timeframe = {
              from = local.from
              to   = local.to
            }
          }
          visualization = "table"
        }
      },
    ]
  })
}

resource "dynatrace_document" "notebook" {
  type    = "notebook"
  name    = var.demo_name
  content = local.notebook
}
