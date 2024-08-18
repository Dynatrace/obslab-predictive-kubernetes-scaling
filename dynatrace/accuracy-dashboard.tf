locals {
  accuracy_dashboard = jsonencode({
    variables = [
      {
        key      = "repositories",
        type     = "query",
        visible  = true,
        input    = "fetch events | filter kubernetes.predictivescaling.type == \"SUGGEST_SCALING\" | fields kubernetes.predictivescaling.target.repository"
        multiple = true
      }
    ]
    tiles = {
      1 = {
        type    = "markdown",
        content = "# How Accurate Are the Predictions?"
      }
      2 = {
        type          = "code",
        title         = "Score"
        input         = <<-EOT
          import {queryExecutionClient} from '@dynatrace-sdk/client-query';

          export default async function () {
            const eventsQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `fetch events, timeframe: "$${$dt_timeframe_from}/$${$dt_timeframe_to}"
                | filter kubernetes.predictivescaling.type == "SUGGEST_SCALING"
                | filter in(kubernetes.predictivescaling.target.repository, array("$${$repositories.join("\",\"")}"))`
              },
            });

            const events = (await getQueryResult(eventsQuery)).records;


            const predictions = [];

            await Promise.all(events.map(async (event) => {
              const scalingSuggestions = JSON.parse(event['kubernetes.predictivescaling.prediction.suggestions']);

              await Promise.all(scalingSuggestions.prompts.map(async (prompt) => {
                await Promise.all(prompt.predictions.map(async (prediction) => {
                  const actualMax = await getMaxUsage(event, prediction.resource, Date.parse(prediction.date));
                  let state = 'Not enough data';
                  if (actualMax) {
                    const targetUtilization = getTargetUtilization(event, prediction.resource);
                    const limit = prediction.value / targetUtilization[1];
                    const lowerBound = Math.floor(limit * targetUtilization[0]);
                    const upperBound = Math.ceil(limit * targetUtilization[2]);

                    if (actualMax >= lowerBound && actualMax <= upperBound) {
                      state = 'Correct';
                    } else if (actualMax > upperBound) {
                      state = 'Too Low';
                    } else {
                      state = 'Too High';
                    }
                  }

                  predictions.push({
                    state,
                    resource: prediction.resource,
                    type: prompt.type
                  })

                }));
              }));
            }));

            if (predictions.length === 0) {
              return;
            }

            const correct = predictions.filter(p => p.state === 'Correct').length;
            const ignored = predictions.filter(p => p.state === 'Not enough data').length;
            const total = predictions.length - ignored;

            return correct / total * 100;
          }

          const getTargetUtilization = (event, resource) => {
            if (resource === 'cpu') {
              return [
                event['kubernetes.predictivescaling.targetutilization.cpu.min'],
                event['kubernetes.predictivescaling.targetutilization.cpu.point'],
                event['kubernetes.predictivescaling.targetutilization.cpu.max'],
              ];
            }
            return [
              event['kubernetes.predictivescaling.targetutilization.memory.min'],
              event['kubernetes.predictivescaling.targetutilization.memory.point'],
              event['kubernetes.predictivescaling.targetutilization.memory.max'],
            ];
          }

          const getMaxUsage = async (event, resource, timestamp) => {
            const metricName = resource === 'cpu' ? 'dt.kubernetes.container.cpu_usage' : 'dt.kubernetes.container.memory_working_set'
            // Check the predicted timestamp +/- 5 minutes
            const lookupQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `timeseries cpuUsage = avg($${metricName}),
                      by: {dt.entity.cloud_application},
                      timeframe: "$${new Date(timestamp - 300000).toISOString()}/$${new Date(timestamp + 300000).toISOString()}"
                      | filter dt.entity.cloud_application == "$${event['dt.entity.cloud_application']}"
                      | fields max = arrayMax(cpuUsage)`
              },
            });
            const actualUsage = (await getQueryResult(lookupQuery)).records;

            if (actualUsage.length === 0) {
              return undefined;
            }
            return actualUsage[0].max;
          }

          const getQueryResult = async (query) => {
            let state = 'RUNNING';
            let queryResult;

            while (state === 'RUNNING') {
              // sleep a bit
              await new Promise(r => setTimeout(r, 100));
              queryResult = await queryExecutionClient.queryPoll({
                requestToken: query.requestToken,
              });
              state = queryResult.state;
            }

            return queryResult.result;
          }
        EOT
        visualization = "singleValue"
        visualizationSettings = {
          thresholds = [
            {
              field     = "element",
              isEnabled = true,
              rules = [
                {
                  color = {
                    Default = "var(--dt-colors-charts-status-ideal-default, #2f6863)"
                  },
                  comparator = ">=",
                  value      = 80
                },
                {
                  color = {
                    Default = "var(--dt-colors-charts-status-warning-default, #eca440)"
                  },
                  comparator = ">=",
                  value      = 50
                },
                {
                  color = {
                    Default = "var(--dt-colors-charts-status-critical-default, #c4233b)"
                  },
                  comparator = "=",
                  value      = 0
                }
              ]
            }
          ]
          singleValue = {
            showLabel            = false,
            label                = "",
            recordField          = "element",
            alignment            = "center",
            colorThresholdTarget = "background"
          }
          unitsOverrides = {
            identifier   = "element",
            unitCategory = "unspecified",
            baseUnit     = "none",
            displayUnit  = null
            decimals     = 0,
            suffix       = "%",
            delimiter    = false
          }
        }
      }
      3 = {
        type          = "code",
        input         = <<-EOT
          import {queryExecutionClient} from '@dynatrace-sdk/client-query';

          export default async function () {
            const eventsQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `fetch events, timeframe: "$${$dt_timeframe_from}/$${$dt_timeframe_to}"
                | filter kubernetes.predictivescaling.type == "SUGGEST_SCALING"
                | filter in(kubernetes.predictivescaling.target.repository, array("$${$repositories.join("\",\"")}"))`
              },
            });

            const events = (await getQueryResult(eventsQuery)).records;

            const predictions = [];

            await Promise.all(events.map(async (event) => {
              const scalingSuggestions = JSON.parse(event['kubernetes.predictivescaling.prediction.suggestions']);

              await Promise.all(scalingSuggestions.prompts.map(async (prompt) => {
                await Promise.all(prompt.predictions.map(async (prediction) => {
                  const actualMax = await getMaxUsage(event, prediction.resource, Date.parse(prediction.date));
                  let state = 'Not enough data';
                  if (actualMax) {
                    const targetUtilization = getTargetUtilization(event, prediction.resource);
                    const limit = prediction.value / targetUtilization[1];
                    const lowerBound = Math.floor(limit * targetUtilization[0]);
                    const upperBound = Math.ceil(limit * targetUtilization[2]);

                    if (actualMax >= lowerBound && actualMax <= upperBound) {
                      state = 'Correct';
                    } else if (actualMax > upperBound) {
                      state = 'Too Low';
                    } else {
                      state = 'Too High';
                    }
                  }

                  predictions.push({
                    state,
                    resource: prediction.resource,
                    type: prompt.type,
                  })

                }));
              }));
            }));

            return [
              {state: 'Correct', count: predictions.filter(p => p.state === 'Correct').length},
              {state: 'Too High', count: predictions.filter(p => p.state === 'Too High').length},
              {state: 'Too Low', count: predictions.filter(p => p.state === 'Too Low').length},
              {state: 'Not enough data', count: predictions.filter(p => p.state === 'Not enough data').length},
            ];
          }

          const getTargetUtilization = (event, resource) => {
            if (resource === 'cpu') {
              return [
                event['kubernetes.predictivescaling.targetutilization.cpu.min'],
                event['kubernetes.predictivescaling.targetutilization.cpu.point'],
                event['kubernetes.predictivescaling.targetutilization.cpu.max'],
              ];
            }
            return [
              event['kubernetes.predictivescaling.targetutilization.memory.min'],
              event['kubernetes.predictivescaling.targetutilization.memory.point'],
              event['kubernetes.predictivescaling.targetutilization.memory.max'],
            ];
          }

          const getMaxUsage = async (event, resource, timestamp) => {
            const metricName = resource === 'cpu' ? 'dt.kubernetes.container.cpu_usage' : 'dt.kubernetes.container.memory_working_set'
            // Check the predicted timestamp +/- 5 minutes
            const lookupQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `timeseries cpuUsage = avg($${metricName}),
                      by: {dt.entity.cloud_application},
                      timeframe: "$${new Date(timestamp - 300000).toISOString()}/$${new Date(timestamp + 300000).toISOString()}"
                      | filter dt.entity.cloud_application == "$${event['dt.entity.cloud_application']}"
                      | fields max = arrayMax(cpuUsage)`
              },
            });
            const actualUsage = (await getQueryResult(lookupQuery)).records;

            if (actualUsage.length === 0) {
              return undefined;
            }
            return actualUsage[0].max;
          }

          const getQueryResult = async (query) => {
            let state = 'RUNNING';
            let queryResult;

            while (state === 'RUNNING') {
              // sleep a bit
              await new Promise(r => setTimeout(r, 100));
              queryResult = await queryExecutionClient.queryPoll({
                requestToken: query.requestToken,
              });
              state = queryResult.state;
            }

            return queryResult.result;
          }
        EOT
        visualization = "donutChart"
        visualizationSettings = {
          chartSettings = {
            circleChartSettings = {
              groupingThresholdType  = "relative",
              groupingThresholdValue = 0,
              valueType              = "relative",
              showTotalValue         = true
            }
            categoryOverrides = {
              Correct = { color = "var(--dt-colors-charts-apdex-excellent-default, #2a7453)" }
              "Too High" = { color = "var(--dt-colors-charts-categorical-color-14-default, #d56b1a)" }
              "Too Low" = { color = "var(--dt-colors-charts-loglevel-emergency-default, #ae132d)" }
              "Not enough data" = { color = "var(--dt-colors-charts-categorical-color-05-default, #84859a)" }
            }
            categoricalBarChartSettings = {
              categoryAxis = "state",
              valueAxis    = "count"
            }
          }

        }
      }
      4 = {
        type          = "code",
        input         = <<-EOT
          import {queryExecutionClient} from '@dynatrace-sdk/client-query';

          export default async function () {
            const eventsQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `fetch events, timeframe: "$${$dt_timeframe_from}/$${$dt_timeframe_to}"
                | filter kubernetes.predictivescaling.type == "SUGGEST_SCALING"
                | filter in(kubernetes.predictivescaling.target.repository, array("$${$repositories.join("\",\"")}"))`
              },
            });

            const events = (await getQueryResult(eventsQuery)).records;

            const predictions = [];

            await Promise.all(events.map(async (event) => {
              const scalingSuggestions = JSON.parse(event['kubernetes.predictivescaling.prediction.suggestions']);

              await Promise.all(scalingSuggestions.prompts.map(async (prompt) => {
                await Promise.all(prompt.predictions.map(async (prediction) => {
                  const actualMax = await getMaxUsage(event, prediction.resource, Date.parse(prediction.date));
                  let state = 'Not enough data';
                  if (actualMax) {
                    const targetUtilization = getTargetUtilization(event, prediction.resource);
                    const limit = prediction.value / targetUtilization[1];
                    const lowerBound = Math.floor(limit * targetUtilization[0]);
                    const upperBound = Math.ceil(limit * targetUtilization[2]);

                    if (actualMax >= lowerBound && actualMax <= upperBound) {
                      state = 'Correct';
                    } else if (actualMax > upperBound) {
                      state = 'Too Low';
                    } else {
                      state = 'Too High';
                    }
                  }

                  predictions.push({
                    state,
                    resource: prediction.resource,
                    type: prompt.type,
                  })

                }));
              }));
            }));

            return predictions;
          }

          const getTargetUtilization = (event, resource) => {
            if (resource === 'cpu') {
              return [
                event['kubernetes.predictivescaling.targetutilization.cpu.min'],
                event['kubernetes.predictivescaling.targetutilization.cpu.point'],
                event['kubernetes.predictivescaling.targetutilization.cpu.max'],
              ];
            }
            return [
              event['kubernetes.predictivescaling.targetutilization.memory.min'],
              event['kubernetes.predictivescaling.targetutilization.memory.point'],
              event['kubernetes.predictivescaling.targetutilization.memory.max'],
            ];
          }

          const getMaxUsage = async (event, resource, timestamp) => {
            const metricName = resource === 'cpu' ? 'dt.kubernetes.container.cpu_usage' : 'dt.kubernetes.container.memory_working_set'
            // Check the predicted timestamp +/- 5 minutes
            const lookupQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `timeseries cpuUsage = avg($${metricName}),
                      by: {dt.entity.cloud_application},
                      timeframe: "$${new Date(timestamp - 300000).toISOString()}/$${new Date(timestamp + 300000).toISOString()}"
                      | filter dt.entity.cloud_application == "$${event['dt.entity.cloud_application']}"
                      | fields max = arrayMax(cpuUsage)`
              },
            });
            const actualUsage = (await getQueryResult(lookupQuery)).records;

            if (actualUsage.length === 0) {
              return undefined;
            }
            return actualUsage[0].max;
          }

          const getQueryResult = async (query) => {
            let state = 'RUNNING';
            let queryResult;

            while (state === 'RUNNING') {
              // sleep a bit
              await new Promise(r => setTimeout(r, 100));
              queryResult = await queryExecutionClient.queryPoll({
                requestToken: query.requestToken,
              });
              state = queryResult.state;
            }

            return queryResult.result;
          }
        EOT
        visualization = "honeycomb"
        visualizationSettings = {
          honeycomb = {
            shape        = "hexagon",
            colorMode    = "custom-colors",
            colorPalette = "categorical"
            dataMappings = { value = "state" }
            displayedFields = ["resource"]
            customColors = [
              {
                value      = "Correct",
                comparator = "=",
                color = { Default = "var(--dt-colors-charts-categorical-color-09-default, #649438)" }
              },
              {
                value      = "Too High",
                comparator = "=",
                color = { Default = "var(--dt-colors-charts-loglevel-severe-default, #d56b1a)" }
              },
              {
                value      = "Too Low",
                comparator = "=",
                color = { Default = "var(--dt-colors-charts-categorical-color-12-default, #cd3741)" }
              },
              {
                value      = "Not enough data",
                comparator = "=",
                color = { Default = "var(--dt-colors-charts-logstatus-none-default, #2c2f3f)" }
              }
            ]
            legend = {
              hidden = false,
              position = "auto"
            }
          }
        }
      }
      5 = {
        type    = "markdown",
        content = "# How Many Predictions Have Been Applied?"
      }
      6 = {
        type  = "data",
        title = "New Pull Requests"
        query = <<-EOT
          fetch events
          | filter kubernetes.predictivescaling.type == "SUGGEST_SCALING"
          | filter in(kubernetes.predictivescaling.target.repository, array($repositories))
          | summarize count()
        EOT
        davis = {
          enabled = false
        }
        visualization = "singleValue"
        visualizationSettings = {
          singleValue = {
            showLabel   = false,
            recordField = "count()",
            alignment   = "center",
          }
        }
      }
      7 = {
        type  = "data",
        title = "Merged Pull Requests"
        query = <<-EOT
          fetch events
          | filter dt.openpipeline.source == "/platform/ingest/custom/events/github"
          | parse repository, "JSON:repo"
          | filter in(repo[full_name], array($repositories))
          | filter action == "merged"
          | summarize count()
        EOT
        davis = {
          enabled = false
        }
        visualization = "singleValue"
        visualizationSettings = {
          singleValue = {
            showLabel   = false,
            recordField = "count()",
            alignment   = "center",
          }
        }
      }
      8 = {
        type  = "data",
        title = "Closed Pull Requests"
        query = <<-EOT
          fetch events
          | filter dt.openpipeline.source == "/platform/ingest/custom/events/github"
          | parse repository, "JSON:repo"
          | filter in(repo[full_name], array($repositories))
          | filter action == "closed"
          | summarize count()
        EOT
        davis = {
          enabled = false
        }
        visualization = "singleValue"
        visualizationSettings = {
          singleValue = {
            showLabel   = false,
            recordField = "count()",
            alignment   = "center",
          }
        }
      }
      9 = {
        type    = "markdown",
        content = "# Which Predictions Have Been Wrong?"
      }
      10 = {
        type          = "code",
        input         = <<-EOT
          import {queryExecutionClient} from '@dynatrace-sdk/client-query';

          export default async function () {
            const eventsQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `fetch events, timeframe: "$${$dt_timeframe_from}/$${$dt_timeframe_to}"
                | filter kubernetes.predictivescaling.type == "SUGGEST_SCALING"
                | filter in(kubernetes.predictivescaling.target.repository, array("$${$repositories.join("\",\"")}"))`
              },
            });

            const events = (await getQueryResult(eventsQuery)).records;

            const predictions = [];
            const wrongEvents = [];

            await Promise.all(events.map(async (event) => {
              const scalingSuggestions = JSON.parse(event['kubernetes.predictivescaling.prediction.suggestions']);

              await Promise.all(scalingSuggestions.prompts.map(async (prompt) => {
                await Promise.all(prompt.predictions.map(async (prediction) => {
                  const actualMax = await getMaxUsage(event, prediction.resource, Date.parse(prediction.date));
                  let state = 'Not enough data';
                  if (actualMax) {
                    const targetUtilization = getTargetUtilization(event, prediction.resource);
                    const limit = prediction.value / targetUtilization[1];
                    const lowerBound = Math.floor(limit * targetUtilization[0]);
                    const upperBound = Math.ceil(limit * targetUtilization[2]);

                    if (actualMax >= lowerBound && actualMax <= upperBound) {
                      state = 'Correct';
                    } else if (actualMax > upperBound) {
                      state = 'Too Low';
                    } else {
                      state = 'Too High';
                    }
                  }

                  if (state !== 'Correct' && state !== 'Not enough data') {
                    event.reason = state;
                    wrongEvents.push(event)
                  }
                }));
              }));
            }));

            return wrongEvents;
          }

          const getTargetUtilization = (event, resource) => {
            if (resource === 'cpu') {
              return [
                event['kubernetes.predictivescaling.targetutilization.cpu.min'],
                event['kubernetes.predictivescaling.targetutilization.cpu.point'],
                event['kubernetes.predictivescaling.targetutilization.cpu.max'],
              ];
            }
            return [
              event['kubernetes.predictivescaling.targetutilization.memory.min'],
              event['kubernetes.predictivescaling.targetutilization.memory.point'],
              event['kubernetes.predictivescaling.targetutilization.memory.max'],
            ];
          }

          const getMaxUsage = async (event, resource, timestamp) => {
            const metricName = resource === 'cpu' ? 'dt.kubernetes.container.cpu_usage' : 'dt.kubernetes.container.memory_working_set'
            // Check the predicted timestamp +/- 5 minutes
            const lookupQuery = await queryExecutionClient.queryExecute({
              body: {
                query: `timeseries cpuUsage = avg($${metricName}),
                      by: {dt.entity.cloud_application},
                      timeframe: "$${new Date(timestamp - 300000).toISOString()}/$${new Date(timestamp + 300000).toISOString()}"
                      | filter dt.entity.cloud_application == "$${event['dt.entity.cloud_application']}"
                      | fields max = arrayMax(cpuUsage)`
              },
            });
            const actualUsage = (await getQueryResult(lookupQuery)).records;

            if (actualUsage.length === 0) {
              return undefined;
            }
            return actualUsage[0].max;
          }

          const getQueryResult = async (query) => {
            let state = 'RUNNING';
            let queryResult;

            while (state === 'RUNNING') {
              // sleep a bit
              await new Promise(r => setTimeout(r, 100));
              queryResult = await queryExecutionClient.queryPoll({
                requestToken: query.requestToken,
              });
              state = queryResult.state;
            }

            return queryResult.result;
          }
        EOT
        visualization = "table"
        visualizationSettings = {
          table = {
            rowDensity       = "condensed",
            enableSparkLines = false,
            hiddenColumns = [
              ["timestamp"],
              ["affected_entity_ids"],
              ["affected_entity_types"],
              ["dt.davis.impact_level"],
              ["dt.davis.is_frequent_event"],
              ["dt.davis.is_frequent_issue_detection_allowed"],
              ["dt.davis.mute.status"],
              ["dt.davis.timeout"],
              ["dt.entity.cloud_application"],
              ["dt.entity.cloud_application.name"],
              ["dt.source_entity"],
              ["dt.source_entity.type"],
              ["event.category"],
              ["event.end"],
              ["event.group_label"],
              ["event.id"],
              ["event.kind"],
              ["event.provider"],
              ["event.status"],
              ["event.status_transition"],
              ["event.type"],
              ["kubernetes.predictivescaling.prediction.description"],
              ["kubernetes.predictivescaling.prediction.prompt"],
              ["kubernetes.predictivescaling.pullrequest.id"],
              ["kubernetes.predictivescaling.target.repository"],
              ["kubernetes.predictivescaling.target.uuid"],
              ["kubernetes.predictivescaling.workload.cluster.id"],
              ["kubernetes.predictivescaling.workload.limits.cpu"],
              ["kubernetes.predictivescaling.workload.limits.memory"],
              ["kubernetes.predictivescaling.workload.uuid"],
              ["maintenance.is_under_maintenance"],
              ["prediction"],
              ["kubernetes.predictivescaling.prediction.suggestions"],
              ["kubernetes.predictivescaling.type"]
            ]
          }
        }
      }
    }
    layouts = {
      1 = { x = 0, y = 0, w = 12, h = 1 }
      2 = { x = 0, y = 1, w = 12, h = 5 }
      3 = { x = 0, y = 6, w = 4, h = 7 }
      4 = { x = 4, y = 6, w = 8, h = 7 }
      5 = { x = 13, y = 0, w = 11, h = 1 }
      6 = { x = 13, y = 1, w = 4, h = 5 }
      7 = { x = 17, y = 1, w = 4, h = 5 }
      8 = { x = 21, y = 1, w = 3, h = 5 }
      9 = { x = 13, y = 6, w = 11, h = 1 }
      10 = { x = 13, y = 7, w = 11, h = 6 }
    }
  })
}

resource "dynatrace_document" "accuracy_dashboard" {
  type    = "dashboard"
  name    = "${var.demo_name} Accuracy"
  content = local.accuracy_dashboard
}
