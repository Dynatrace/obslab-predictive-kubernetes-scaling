resource "dynatrace_generic_setting" "github_credentials" {
  schema = "app:dynatrace.github.connector:connection"
  scope  = "environment"
  value = jsonencode({
    name  = substr(join(" - ", [var.demo_name, var.codespace_name]), 0, 49)
    type  = "pat"
    token = var.github_token
  })
}

resource "dynatrace_automation_workflow" "commit_prediction" {
  title       = "Commit Davis Prediction [${var.demo_name} - ${var.codespace_name}]"
  description = "Reacts to events containing suggestions based on Davis resource usage prediction and applies them by creating a pull request on GitHub"
  tasks {
    task {
      name        = "get_repository_data"
      description = "Fetches the default branch of the target repository and outputs all important repository data"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {execution} from '@dynatrace-sdk/automation-utils';
          import {credentialVaultClient} from "@dynatrace-sdk/client-classic-environment-v2";

          export default async function ({execution_id}) {
            const ex = await execution(execution_id);
            const event = ex.params.event;

            const owner = event['kubernetes.predictivescaling.target.repository.owner'];
            const repo = event['kubernetes.predictivescaling.target.repository.name'];
            const path = event['kubernetes.predictivescaling.target.path'];

            const apiToken = await credentialVaultClient.getCredentialsDetails({
              id: "${dynatrace_credentials.github_pat.id}",
            }).then((credentials) => credentials.token);

            const repoInfo = await fetch(`https://api.github.com/repos/$${owner}/$${repo}`, {
              method: 'GET',
              headers: {
                'Authorization': `Bearer $${apiToken}`
              }
            }).then(response => response.json());

            return {
              owner: owner,
              repository: repo,
              filePath: path,
              defaultBranch: repoInfo.default_branch
            }
          }
          EOT
        )
      })
      position {
        x = 0
        y = 1
      }
    }
    task {
      name        = "fetch_manifest"
      description = "Gets the content of the manifest"
      action      = "dynatrace.github.connector:get-content"
      active      = true
      input = jsonencode({
        owner        = "{{ result(\"get_repository_data\").owner }}",
        repository   = "{{ result(\"get_repository_data\").repository }}",
        filePath     = "{{ result(\"get_repository_data\").filePath }}",
        reference    = "{{ result(\"get_repository_data\").defaultBranch }}",
        connectionId = dynatrace_generic_setting.github_credentials.id
      })
      position {
        x = 0
        y = 2
      }
      conditions {
        states = {
          get_repository_data = "OK"
        }
      }
    }
    task {
      name        = "apply_suggestions"
      description = "Uses Davis CoPilot to apply all suggestions to the given manifest"
      action      = "dynatrace.davis.copilot.workflow.actions:davis-copilot"
      active      = true
      input = jsonencode({
        config = "disabled",
        prompt = "{{ event()['kubernetes.predictivescaling.prediction.prompt'] }}\n\n{{ result(\"fetch_manifest\")[\"content\"] }}",
        autoTrim = true,
        supplementary = ""
      })
      position {
        x = 0
        y = 3
      }
      conditions {
        states = {
          fetch_manifest = "OK"
        }
      }
    }
    task {
      name        = "parse_manifest"
      description = "Parses the updated manifest and extracts the description and time of the suggestions"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {execution} from '@dynatrace-sdk/automation-utils';

          export default async function ({execution_id}) {
            const ex = await execution(execution_id);
            const event = ex.params.event;
            var copilotResult = (await ex.result('apply_suggestions')).text;

            return {
              manifest: copilotResult.match(/(?<=^```(yaml|yml).*\\n)([^`])*(?=^```$)/gm)[0],
              time: new Date(event.timestamp).getTime(),
              description: event['kubernetes.predictivescaling.prediction.description']
            }
          }
          EOT
        )
      })
      position {
        x = 0
        y = 4
      }
      conditions {
        states = {
          apply_suggestions = "OK"
        }
      }
    }
    task {
      name        = "push_manifest"
      description = "Pushes the updated manifest to a new branch on GitHub"
      action      = "dynatrace.github.connector:create-or-replace-file"
      active      = true
      input = jsonencode({
        owner : "{{ result(\"get_repository_data\").owner }}",
        repository : "{{ result(\"get_repository_data\").repository }}",
        createNewBranch : true
        sourceBranch : "{{ result(\"get_repository_data\").defaultBranch }}",
        branch : "apply-davis-predictions-{{result(\"parse_manifest\").time}}",
        filePath : "{{ result(\"get_repository_data\").filePath }}",
        fileContent : "{{ result(\"parse_manifest\").manifest }}",
        commitMessage : "Apply suggestions predicted by Davis AI:\n\n{{ result(\"parse_manifest\").description }}",
        connectionId : dynatrace_generic_setting.github_credentials.id
      })
      position {
        x = 0
        y = 5
      }
      conditions {
        states = {
          parse_manifest = "OK"
        }
      }
    }
    task {
      name        = "create_pull_request"
      description = "Creates a pull request that includes all suggested changes"
      action      = "dynatrace.github.connector:create-pull-request"
      active      = true
      input = jsonencode({
        owner        = "{{ result(\"get_repository_data\").owner }}",
        repository   = "{{ result(\"get_repository_data\").repository }}",
        sourceBranch = "apply-davis-predictions-{{result(\"parse_manifest\").time}}",
        targetBranch = "{{ result(\"get_repository_data\").defaultBranch }}"
        title        = "Apply suggestions predicted by Dynatrace Davis AI",
        description  = "{{ result(\"parse_manifest\").description }}",
        connectionId = dynatrace_generic_setting.github_credentials.id
      })
      position {
        x = 0
        y = 6
      }
      conditions {
        states = {
          push_manifest = "OK"
        }
      }
    }
    task {
      name        = "create_suggestion_applied_event"
      description = "Trigger an event of type \"Custom Info\" and let other components react to it"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import {execution} from '@dynatrace-sdk/automation-utils';
          import {eventsClient, EventIngestEventType} from "@dynatrace-sdk/client-classic-environment-v2";

          export default async function ({execution_id}) {
            const ex = await execution(execution_id);
            const pullRequest = (await ex.result('create_pull_request')).pullRequest;
            const event = ex.params.event;

            const eventBody = {
              eventType: EventIngestEventType.CustomInfo,
              title: 'Applied Scaling Suggestion Because of Davis AI Prediction',
              entitySelector: `type(CLOUD_APPLICATION),entityName.equals("$${event['kubernetes.predictivescaling.workload.name']}"),namespaceName("$${event['kubernetes.predictivescaling.workload.namespace']}"),toRelationships.isClusterOfCa(type(KUBERNETES_CLUSTER),entityId("$${event['kubernetes.predictivescaling.workload.cluster.id']}"))`,
              properties: {
                'kubernetes.predictivescaling.type': 'SUGGEST_SCALING',

                // Workload
                'kubernetes.predictivescaling.workload.cluster.name': event['kubernetes.predictivescaling.workload.cluster.name'],
                'kubernetes.predictivescaling.workload.cluster.id': event['kubernetes.predictivescaling.workload.cluster.id'],
                'kubernetes.predictivescaling.workload.kind': event['kubernetes.predictivescaling.workload.kind'],
                'kubernetes.predictivescaling.workload.namespace': event['kubernetes.predictivescaling.workload.namespace'],
                'kubernetes.predictivescaling.workload.name': event['kubernetes.predictivescaling.workload.name'],
                'kubernetes.predictivescaling.workload.uuid': event['kubernetes.predictivescaling.workload.uuid'],
                'kubernetes.predictivescaling.workload.limits.cpu': event['kubernetes.predictivescaling.workload.limits.cpu'],
                'kubernetes.predictivescaling.workload.limits.memory': event['kubernetes.predictivescaling.workload.limits.memory'],

                // Prediction
                'kubernetes.predictivescaling.prediction.type': event['kubernetes.predictivescaling.prediction.type'],
                'kubernetes.predictivescaling.prediction.prompt': event['kubernetes.predictivescaling.prediction.prompt'],
                'kubernetes.predictivescaling.prediction.description': event['kubernetes.predictivescaling.prediction.description'],
                'kubernetes.predictivescaling.prediction.suggestions': event['kubernetes.predictivescaling.prediction.suggestions'],

                // Target Utilization
                'kubernetes.predictivescaling.targetutilization.cpu.min': event['kubernetes.predictivescaling.targetutilization.cpu.min'],
                'kubernetes.predictivescaling.targetutilization.cpu.max': event['kubernetes.predictivescaling.targetutilization.cpu.max'],
                'kubernetes.predictivescaling.targetutilization.cpu.point': event['kubernetes.predictivescaling.targetutilization.cpu.point'],
                'kubernetes.predictivescaling.targetutilization.memory.min': event['kubernetes.predictivescaling.targetutilization.memory.min'],
                'kubernetes.predictivescaling.targetutilization.memory.max': event['kubernetes.predictivescaling.targetutilization.memory.max'],
                'kubernetes.predictivescaling.targetutilization.memory.point': event['kubernetes.predictivescaling.targetutilization.memory.point'],

                // Target
                'kubernetes.predictivescaling.target.path': event['kubernetes.predictivescaling.target.path'],
                'kubernetes.predictivescaling.target.repository.owner': event['kubernetes.predictivescaling.target.repository.owner'],
                'kubernetes.predictivescaling.target.repository.name': event['kubernetes.predictivescaling.target.repository.name'],

                // Pull Request
                'kubernetes.predictivescaling.pullrequest.id': `$${pullRequest.id}`,
                'kubernetes.predictivescaling.pullrequest.url': pullRequest.url,
              },
            };

            await eventsClient.createEvent({body: eventBody});
            return eventBody;
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
          create_pull_request = "OK"
        }
      }
    }
  }
  trigger {
    event {
      active = true
      config {
        event {
          event_type = "events"
          query      = "kubernetes.predictivescaling.type == \"DETECT_SCALING\""
        }
      }
    }
  }
}