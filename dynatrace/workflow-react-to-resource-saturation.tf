resource "dynatrace_automation_workflow" "react_to_resource_saturation" {
  title       = "React to Resource Saturation [${var.demo_name}]"
  description = "Is triggered when Davis detects a resource saturation problem and then triggers the 'Predict Kubernetes Resource Usage' workflow to create a Pull Request"
  tasks {
    task {
      name        = "trigger_prediction"
      description = "Triggers the 'Predict Kubernetes Resource Usage' workflow to react to problems"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = chomp(
          <<-EOT
          import { workflowsClient } from "@dynatrace-sdk/client-automation";

          export default async function ({ execution_id }) {
            return await workflowsClient.runWorkflow({
              id: "${dynatrace_automation_workflow.predict_resource_usage.id}",
              body: {},
            });
          }
          EOT
        )
      })
      position {
        x = 0
        y = 1
      }
    }
  }
  trigger {
    event {
      active = false
      config {
        davis_problem {
          on_problem_close = false
          categories {
            resource = true
          }
        }
      }
    }
  }
}