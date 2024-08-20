data "http" "get_edge_connect" {
  method = "GET"
  url    = "${var.dynatrace_live_url}/api/v2/settings/objects?schemaIds=app:dynatrace.kubernetes.connector:connection&filter=value.name='${var.codespace_name}'"

  request_headers = {
    Accept        = "application/json"
    Authorization = "Api-Token ${dynatrace_api_token.read_settings_objects.token}"
  }
}

resource "dynatrace_automation_workflow" "predict_resource_usage" {
  title       = "Predict Kubernetes Resource Usage [${var.demo_name}]"
  description = "Predicts how much resources certain Kubernetes workloads will need in the future and emits events in case Kubernetes limits will be exceeded."
  tasks {
    task {
      name        = "find_workloads_to_scale"
      description = "Returns all Kubernetes workloads that should be scaled based on Davis predictions"
      action      = "dynatrace.automations:execute-dql-query"
      active      = true
      input = jsonencode({
        query = chomp(
          <<-EOT
          fetch dt.entity.cloud_application, from:now() - 5m, to:now()
          | filter kubernetesAnnotations[`${var.annotation_prefix}/enabled`] == "true"
          | fields clusterId = clustered_by[`dt.entity.kubernetes_cluster`], namespace = namespaceName, name = entity.name, type = arrayFirst(cloudApplicationDeploymentTypes), annotations = kubernetesAnnotations
          | join [ fetch dt.entity.kubernetes_cluster ],
            on: { left[clusterId] == right[id] },
            fields: { clusterName = entity.name }
          EOT
        )
        failOnEmptyResult = false
      })
      position {
        x = 0
        y = 1
      }
    }
    task {
      name        = "predict_resource_usage"
      description = "Predicts how much resources the given Kubernetes workloads will need"
      action      = "dynatrace.davis.workflow.actions:davis-analyze"
      active      = true
      input = jsonencode({
        analyzerName = "dt.statistics.GenericForecastAnalyzer"
        body = {
          nPaths          = 200
          useModelCache   = true
          forecastOffset  = 0
          forecastHorizon = 100
          generalParameters = {
            timeframe = {
              endTime   = "now",
              startTime = "now-1h"
            }
            logVerbosity                = "WARNING"
            resolveDimensionalQueryData = false
          }
          coverageProbability          = 0.9
          applyZeroLowerBoundHeuristic = true
          timeSeriesData = chomp(
            <<-EOT
            timeseries {
              memoryUsage = avg(dt.kubernetes.container.memory_working_set),
              memoryLimits = max(dt.kubernetes.container.limits_memory),
              cpuUsage = avg(dt.kubernetes.container.cpu_usage),
              cpuLimits = max(dt.kubernetes.container.limits_cpu)
            },
            by:{k8s.cluster.name, k8s.namespace.name, k8s.workload.kind, k8s.workload.name}
            | filter k8s.cluster.name == "{{ _.workload.clusterName }}" and k8s.namespace.name == "{{ _.workload.namespace }}" and k8s.workload.name == "{{ _.workload.name }}"
            | fields
              cluster = k8s.cluster.name,
              clusterId = "{{ _.workload.clusterId }}",
              namespace = k8s.namespace.name,
              kind = k8s.workload.kind,
              name = k8s.workload.name,
              annotations = "{{ _.workload.annotations }}",
              memoryLimit = arrayLast(memoryLimits),
              cpuLimit = arrayLast(cpuLimits),
              timeframe,
              interval,
              memoryUsage,
              cpuUsage
            EOT
          )
        }
      })
      conditions {
        states = {
          find_workloads_to_scale = "OK"
        }
      }
      with_items  = "workload in {{ result(\"find_workloads_to_scale\")[\"records\"] }}"
      concurrency = "1"
      position {
        x = 0
        y = 2
      }
    }
    task {
      name        = "parse_predictions"
      description = "Parses the given Davis predictions and returns all workloads that need adjustments"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {execution} from '@dynatrace-sdk/automation-utils';

          export default async function ({execution_id}) {
            const ex = await execution(execution_id);
            const predictions = await ex.result('predict_resource_usage');

            let workloads = [];

            predictions.forEach(prediction => {
              prediction.result.output
                .filter(output => output.analysisStatus == 'OK' && output.forecastQualityAssessment == 'VALID')
                .forEach(output => {
                  const query = JSON.parse(output.analyzedTimeSeriesQuery.expression);
                  const result = output.timeSeriesDataWithPredictions.records[0];

                  let resource = query.timeSeriesData.records[0].cpuUsage ? 'cpu' : 'memory';
                  const highestPrediction = getHighestPrediction(result.timeframe, result.interval, resource, result['dt.davis.forecast:upper'])
                  workloads = addOrUpdateWorkload(workloads, result, highestPrediction);
                })
            });

            return workloads;
          }

          const getHighestPrediction = (timeframe, interval, resource, values) => {
            const highestValue = Math.max(...values);

            const index = values.indexOf(highestValue);
            const startTime = new Date(timeframe.start).getTime();
            const intervalInMs = interval / 1000000;

            return {
              resource,
              value: highestValue,
              date: new Date(startTime + (index * intervalInMs)),
              predictedUntil: new Date(timeframe.end)
            }
          }

          const addOrUpdateWorkload = (workloads, result, prediction) => {
            const existingWorkload = workloads.find(p =>
              p.cluster === result.cluster
              && p.namespace === result.namespace
              && p.kind === result.kind
              && p.name === result.name
            );

            if (existingWorkload) {
              existingWorkload.predictions.push(prediction);
              return workloads;
            }

            const annotations = JSON.parse(result.annotations.replaceAll(`'`, `"`));
            const hpa = annotations['${var.annotation_prefix}/managed-by-hpa'];

            workloads.push({
              cluster: result.cluster,
              clusterId: result.clusterId,
              namespace: result.namespace,
              kind: result.kind,
              name: result.name,
              repository: annotations['${var.annotation_prefix}/managed-by-repo'],
              uuid: annotations['${var.annotation_prefix}/uuid'],
              predictions: [prediction],
              scalingConfig: {
                horizontalScaling: {
                  enabled: hpa ? true : false,
                  hpa: {
                    name: hpa
                  }
                },
                limits: {
                  memory: result.memoryLimit,
                  cpu: result.cpuLimit,
                },
                targetUtilization: getTargetUtilization(annotations),
                scaleDown: annotations['${var.annotation_prefix}/scale-down'] ?? 'true' === 'true',
              }
            })

            return workloads;
          }

          const getTargetUtilization = (annotations) => {
            const defaultRange = annotations['${var.annotation_prefix}/target-utilization'] ?? '80-90';
            const targetUtilization = {};

            const cpuRange = annotations['${var.annotation_prefix}/target-cpu-utilization'] ?? defaultRange;
            targetUtilization.cpu = getTargetUtilizationFromRange(cpuRange);

            const memoryRange = annotations['${var.annotation_prefix}/target-memory-utilization'] ?? defaultRange;
            targetUtilization.memory = getTargetUtilizationFromRange(memoryRange);

            return targetUtilization;
          }

          const getTargetUtilizationFromRange = (range) => {
            const [min, max] = range.split('-').map(s => parseInt(s) / 100);
            const point = (min + max) / 2;
            return {min, max, point};
          }
          EOT
        )
      })
      position {
        x = 0
        y = 3
      }
      conditions {
        states = {
          predict_resource_usage = "OK"
        }
      }
    }
    task {
      name        = "add_vertical_scaling_suggestions"
      description = "Add scaling suggestions to each workload that needs vertical scaling"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {actionExecution} from "@dynatrace-sdk/automation-utils";
          import {convert, units} from "@dynatrace-sdk/units";

          export default async function ({action_execution_id}) {
            const actionEx = await actionExecution(action_execution_id);
            const workload = actionEx.loopItem.workload;

            const targetUtilization = calculateTargetUtilization(workload.scalingConfig);
            const prompts = [];
            const descriptions = [`Davis AI has detected that the $${workload.kind} \`$${workload.name}\` can be scaled based on predictive AI analysis. Therefore, this PR applies the following actions:\n`];

            workload.predictions.forEach(prediction => {
              let resourceName;
              let newLimit;
              let range;
              let type;
              let exceedsLimit;

              if (prediction.resource === 'cpu') {
                resourceName = 'CPU';
                newLimit = `$${Math.ceil(prediction.value / workload.scalingConfig.targetUtilization.cpu.point)}m`;
                range = `$${workload.scalingConfig.targetUtilization.cpu.min * 100}-$${workload.scalingConfig.targetUtilization.cpu.max * 100}%`;

                if (prediction.value > targetUtilization.cpu.max) {
                  type = 'up';
                } else if (workload.scalingConfig.scaleDown && prediction.value < targetUtilization.cpu.min) {
                  type = 'down';
                }
                exceedsLimit = type === 'up' && prediction.value > workload.scalingConfig.limits.cpu;
              } else if (prediction.resource === "memory") {
                resourceName = 'Memory';
                newLimit = `$${Math.ceil(convert(
                  Math.ceil(prediction.value / workload.scalingConfig.targetUtilization.memory.point),
                  units.data.byte,
                  units.data.mebibyte
                ))}Mi`;
                range = `$${workload.scalingConfig.targetUtilization.memory.min * 100}-$${workload.scalingConfig.targetUtilization.memory.max * 100}%`;
                if (prediction.value > targetUtilization.memory.max) {
                  type = 'up';
                } else if (workload.scalingConfig.scaleDown && prediction.value < targetUtilization.memory.min) {
                  type = 'down';
                }
                exceedsLimit = type === 'up' && prediction.value > workload.scalingConfig.limits.memory;
              }

              const prompt = `Scale the $${resourceName} request & limit of the $${workload.kind} named "$${workload.name}" in this manifest to \`$${newLimit}\`.`;
              let description = type === 'up'
                ? `- ⬆️ **$${resourceName}**: Scale up to \`$${newLimit}\` (predicted to exceed its target range of $${range} at \`$${prediction.date.toString()}\`)`
                : `- ⬇️ **$${resourceName}**: Scale down to \`$${newLimit}\` (predicted to stay below its target range of $${range} until \`$${prediction.predictedUntil.toString()}\`)`
              if (exceedsLimit) {
                description = `- ⚠️ **$${resourceName}**: Scale up to \`$${newLimit}\` (predicted to exceed its $${resourceName} limit at \`$${prediction.date.toString()}\`)`
              }
              descriptions.push(description);

              prompts.push({type, prompt, predictions: [prediction]});
            });

            if (prompts.length > 0) {
              descriptions.push(`\n_This Pull Request was automatically created by Davis CoPilot._`)
              workload.scalingSuggestions = {
                description: descriptions.join('\n'),
                prompts
              };
            }
            return workload;
          }

          const calculateTargetUtilization = (scalingConfig) => {
            return {
              cpu: {
                max: scalingConfig.limits.cpu * scalingConfig.targetUtilization.cpu.max,
                min: scalingConfig.limits.cpu * scalingConfig.targetUtilization.cpu.min,
                point: scalingConfig.limits.cpu * scalingConfig.targetUtilization.cpu.point
              },
              memory: {
                max: scalingConfig.limits.memory * scalingConfig.targetUtilization.memory.max,
                min: scalingConfig.limits.memory * scalingConfig.targetUtilization.memory.min,
                point: scalingConfig.limits.memory * scalingConfig.targetUtilization.memory.point
              }
            };
          }
          EOT
        )
      })
      position {
        x = 1
        y = 4
      }
      conditions {
        states = {
          parse_predictions = "OK"
        }
      }
      with_items = "workload in [{% for workload in result(\"parse_predictions\") %}\n  {% if workload.scalingConfig.horizontalScaling.enabled == false %}\n    {{ workload }},\n  {% endif %}\n{% endfor %}]"
    }
    task {
      name        = "get_hpa_manifests"
      description = "Gets the manifests of the HorizontalPodAutoscalers that are associated to the given workloads"
      action      = "dynatrace.kubernetes.connector:get-resource"
      active      = true
      input = jsonencode({
        name       = "{{ _.workload.name }}"
        namespace  = "{{ _.workload.namespace }}"
        connection = jsondecode(data.http.get_edge_connect.response_body).items[0].objectId,
        resourceType = {
          apiVersion = "autoscaling/v2"
          kind       = "HorizontalPodAutoscaler"
          name       = "horizontalpodautoscalers"
          verbs = ["get", "list"]
          namespaced = true
          shortNames = ["hpa"]
        }
      })
      position {
        x = -1
        y = 4
      }
      conditions {
        states = {
          parse_predictions = "OK"
        }
      }
      with_items = "workload in [{% for workload in result(\"parse_predictions\") %}\n  {% if workload.scalingConfig.horizontalScaling.enabled %}\n    {{ workload }},\n  {% endif %}\n{% endfor %}]"
    }
    task {
      name        = "adjust_limits"
      description = "Adjusts the CPU & Memory limit based on the HorizontalPodAutoscaler specification"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {execution, actionExecution} from "@dynatrace-sdk/automation-utils";

          export default async function ({execution_id, action_execution_id}) {
            const actionEx = await actionExecution(action_execution_id);
            const workload = actionEx.loopItem.workload;

            // Get matching HPA manifest
            const ex = await execution(execution_id);
            const allHpaManifests = await ex.result('get_hpa_manifests');

            const hpaManifest = allHpaManifests.find(manifest =>
              manifest.metadata.name === workload.scalingConfig.horizontalScaling.hpa.name
              && manifest.metadata.namespace === workload.namespace
              && manifest.spec.scaleTargetRef.name === workload.name
            );

            // Adjust limits
            const maxReplicas = hpaManifest.spec.maxReplicas;

            workload.scalingConfig.horizontalScaling.hpa = {
              ...workload.scalingConfig.horizontalScaling.hpa,
              maxReplicas,
              uuid: hpaManifest.metadata.annotations['${var.annotation_prefix}/uuid'],
              limits: {
                cpu: maxReplicas * workload.scalingConfig.limits.cpu,
                memory: maxReplicas * workload.scalingConfig.limits.memory
              }
            };

            return workload;
          }
          EOT
        )
      })
      position {
        x = -1
        y = 5
      }
      conditions {
        states = {
          get_hpa_manifests = "OK"
        }
      }
      with_items = "workload in [{% for workload in result(\"parse_predictions\") %}\n  {% if workload.scalingConfig.horizontalScaling.enabled %}\n    {{ workload }},\n  {% endif %}\n{% endfor %}]"
    }
    task {
      name        = "add_horizontal_scaling_suggestions"
      description = "Add scaling suggestions to each workload that needs horizontal scaling"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {actionExecution} from "@dynatrace-sdk/automation-utils";
          import {convert, units} from "@dynatrace-sdk/units";

          export default async function ({action_execution_id}) {
            const actionEx = await actionExecution(action_execution_id);
            const workload = actionEx.loopItem.workload;

            const targetUtilization = calculateTargetUtilization(workload.scalingConfig);

            let newMaxReplicas = 0;
            const predictionsToApply = [];
            const descriptions = [];
            let exceedsLimits = false;

            workload.predictions.forEach(prediction => {
              let replicas = 0;
              if (prediction.resource === 'cpu' && prediction.value > targetUtilization.cpu.max) {
                predictionsToApply.push(prediction);

                // Calculate new max replicas
                const newLimit = Math.ceil(prediction.value / workload.scalingConfig.targetUtilization.cpu.point);
                replicas = Math.ceil(newLimit / workload.scalingConfig.limits.cpu);

                // Get description
                if (prediction.value > workload.scalingConfig.horizontalScaling.hpa.limits.cpu) {
                  exceedsLimits = true;
                  descriptions.push(`  - ⚠️ **CPU**: Predicted to exceed its CPU limit of \`$${workload.scalingConfig.horizontalScaling.hpa.limits.cpu}m\` (\`$${workload.scalingConfig.limits.cpu}m * $${workload.scalingConfig.horizontalScaling.hpa.maxReplicas}\`) at \`$${prediction.date.toString()}\`)`)
                } else {
                  const range = `$${workload.scalingConfig.targetUtilization.cpu.min * 100}-$${workload.scalingConfig.targetUtilization.cpu.max * 100}%`;
                  descriptions.push(`  - ⬆️ **CPU**: Predicted to exceed its target range of $${range} at \`$${prediction.date.toString()}\`)`)
                }
              } else if (prediction.resource === 'memory' && prediction.value > targetUtilization.memory.max) {
                predictionsToApply.push(prediction);

                // Calculate new max replicas
                const newLimit = Math.ceil(prediction.value / workload.scalingConfig.targetUtilization.memory.point);
                replicas = Math.ceil(newLimit / workload.scalingConfig.limits.memory);

                // Get description
                if (prediction.value > workload.scalingConfig.horizontalScaling.hpa.limits.memory) {
                  exceedsLimits = true;
                  const limit = `$${convert(
                    workload.scalingConfig.limits.memory,
                    units.data.byte,
                    units.data.mebibyte
                  )}`;
                  descriptions.push(`  - ⚠️ **Memory**: Predicted to exceed its Memory limit of \`$${limit * workload.scalingConfig.horizontalScaling.hpa.maxReplicas}Mi\` (\`$${limit}Mi * $${workload.scalingConfig.horizontalScaling.hpa.maxReplicas}\`) at \`$${prediction.date.toString()}\`)`)
                } else {
                  const range = `$${workload.scalingConfig.targetUtilization.memory.min * 100}-$${workload.scalingConfig.targetUtilization.memory.max * 100}%`;
                  descriptions.push(`  - ⬆️ **Memory**: Predicted to exceed its target range of $${range} at \`$${prediction.date.toString()}\`)`)
                }
              }

              if (replicas > newMaxReplicas) {
                newMaxReplicas = replicas;
              }
            });

            if (newMaxReplicas > 0) {
              const fullDescription = [
                `Davis AI has detected that the deployment anomaly-simulation can be scaled based on predictive AI analysis. Therefore, this PR applies the following actions:\n`,
                `- $${exceedsLimits ? '⚠️' : '⬆️'} **HorizontalPodAutoscaler**: Scale the maximum number of replicas to \`$${newMaxReplicas}\`:`,
                ...descriptions,
                `\n_This Pull Request was automatically created by Davis CoPilot._`
              ];
              workload.scalingSuggestions = {
                description: fullDescription.join('\n'),
                prompts: [{
                  type: 'up',
                  prompt: `Scale the maxReplicas of the HorizontalPodAutoscaler named "$${workload.scalingConfig.horizontalScaling.hpa.name}" in this manifest to $${newMaxReplicas}.`,
                  predictions: predictionsToApply
                }]
              };
            }

            return workload;
          }

          const calculateTargetUtilization = (scalingConfig) => {
            const limits = scalingConfig.horizontalScaling.hpa.limits;
            return {
              cpu: {
                max: limits.cpu * scalingConfig.targetUtilization.cpu.max,
                min: limits.cpu * scalingConfig.targetUtilization.cpu.min,
                point: limits.cpu * scalingConfig.targetUtilization.cpu.point
              },
              memory: {
                max: limits.memory * scalingConfig.targetUtilization.memory.max,
                min: limits.memory * scalingConfig.targetUtilization.memory.min,
                point: limits.memory * scalingConfig.targetUtilization.memory.point
              }
            };
          }
          EOT
        )
      })
      position {
        x = -1
        y = 6
      }
      conditions {
        states = {
          adjust_limits = "OK"
        }
      }
      with_items = "workload in {{ result(\"adjust_limits\") }}"
    }
    task {
      name        = "create_scaling_events"
      description = "Trigger a custom Davis event for each workload that needs scaling and let other automations react to it"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {actionExecution} from "@dynatrace-sdk/automation-utils";
          import {eventsClient, EventIngestEventType} from "@dynatrace-sdk/client-classic-environment-v2";

          export default async function ({action_execution_id}) {
            const actionEx = await actionExecution(action_execution_id);
            const workload = actionEx.loopItem.workload;

            if (!workload.scalingSuggestions) {
              return;
            }

            const prompts = [];
            const types = new Set([]);

            workload.scalingSuggestions.prompts.forEach(prompt => {
              prompts.push(prompt.prompt);
              types.add(prompt.type);
            });

            const horizontalScalingConfig = workload.scalingConfig.horizontalScaling;
            let limits;
            if (horizontalScalingConfig.enabled) {
              limits = {
                cpu: horizontalScalingConfig.hpa.limits.cpu,
                memory: horizontalScalingConfig.hpa.limits.memory,
              }
            } else {
              limits = {
                cpu: workload.scalingConfig.limits.cpu,
                memory: workload.scalingConfig.limits.memory,
              }
            }

            const targetUtilization = workload.scalingConfig.targetUtilization;

            const event = {
              eventType: EventIngestEventType.CustomInfo,
              title: 'Suggesting to Scale Because of Davis AI Predictions',
              entitySelector: `type(CLOUD_APPLICATION),entityName.equals("$${workload.name}"),namespaceName("$${workload.namespace}"),toRelationships.isClusterOfCa(type(KUBERNETES_CLUSTER),entityId("$${workload.clusterId}"))`,
              properties: {
                'kubernetes.predictivescaling.type': 'DETECT_SCALING',

                // Workload
                'kubernetes.predictivescaling.workload.cluster.name': workload.cluster,
                'kubernetes.predictivescaling.workload.cluster.id': workload.clusterId,
                'kubernetes.predictivescaling.workload.kind': workload.kind,
                'kubernetes.predictivescaling.workload.namespace': workload.namespace,
                'kubernetes.predictivescaling.workload.name': workload.name,
                'kubernetes.predictivescaling.workload.uuid': workload.uuid,
                'kubernetes.predictivescaling.workload.limits.cpu': limits.cpu,
                'kubernetes.predictivescaling.workload.limits.memory': limits.memory,

                // Prediction
                'kubernetes.predictivescaling.prediction.type': [...types].join(','),
                'kubernetes.predictivescaling.prediction.prompt': prompts.join(' '),
                'kubernetes.predictivescaling.prediction.description': workload.scalingSuggestions.description,
                'kubernetes.predictivescaling.prediction.suggestions': JSON.stringify(workload.scalingSuggestions),

                // Target Utilization
                'kubernetes.predictivescaling.targetutilization.cpu.min': targetUtilization.cpu.min,
                'kubernetes.predictivescaling.targetutilization.cpu.max': targetUtilization.cpu.max,
                'kubernetes.predictivescaling.targetutilization.cpu.point': targetUtilization.cpu.point,
                'kubernetes.predictivescaling.targetutilization.memory.min': targetUtilization.memory.min,
                'kubernetes.predictivescaling.targetutilization.memory.max': targetUtilization.memory.max,
                'kubernetes.predictivescaling.targetutilization.memory.point': targetUtilization.memory.point,

                // Target
                'kubernetes.predictivescaling.target.uuid': horizontalScalingConfig.enabled ? horizontalScalingConfig.hpa.uuid : workload.uuid,
                'kubernetes.predictivescaling.target.repository': workload.repository,
              },
            }

            await eventsClient.createEvent({body: event});
            return event;
          }
          EOT
        )
      })
      position {
        x = 0
        y = 7
      }
      conditions {
        states = {
          add_horizontal_scaling_suggestions = "OK"
          add_vertical_scaling_suggestions = "OK"
        }
      }
      with_items = "workload in {{ result(\"add_horizontal_scaling_suggestions\") + result(\"add_vertical_scaling_suggestions\") }}"
    }
  }
  trigger {}
}