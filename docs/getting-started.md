# Getting Started

## Requirements

- A **Grail enabled Dynatrace SaaS Tenant**
  where [Davis CoPilot](https://www.dynatrace.com/platform/artificial-intelligence/) is enabled.
- A **GitHub account** to interact with the demo repository.

## 1. Prepare Your Environment

The [GitHub Codespace](https://github.com/features/codespaces), you will create within this demo, will automatically set
up a local Kubernetes cluster and deploy the necessary Dynatrace resources. To make this work, you'll need to provide
the below credentials and settings.

- A [Dynatrace API token](https://docs.dynatrace.com/docs/dynatrace-api/basics/dynatrace-api-authentication#dynatrace-api-tokens-and-authentication)
to generate [other tokens used in this demo](../dynatrace/tokens.tf). Permissions:
    - `apiTokens.read`
    - `apiTokens.write`
- A [Dynatrace OAuth 2.0 client](https://docs.dynatrace.com/docs/platform-modules/automations/cloud-automation/setup-cloud-automation/authentication#client)
to deploy the workflows and notebook used in this demo. Permissions:
    - `automation:workflows:write`
    - `automation:workflows:read`
    - `document:documents:write`
    - `document:documents:read`
    - `document:documents:delete`
    - `app-engine:edge-connects:connect`
    - `app-engine:edge-connects:write`
    - `app-engine:edge-connects:read`
    - `app-engine:edge-connects:delete`
    - `oauth2:clients:manage`
    - `settings:objects:read`
    - `settings:objects:write`
- A Dynatrace Platform token to trigger the Davis CoPilot from the demo workflow. Permissions:
    - `davis-copilot:conversations:execute`
- [Allow an outbound connection from Dynatrace](https://developer.dynatrace.com/develop/functions/allow-outbound-connections/)
  to `api.github.com` so that the demo workflow can communicate with GitHub.

## 2. Create Your Development Environment

- Fork [this repository](https://github.com/Dynatrace/obslab-predictive-kubernetes-scaling/tree/main) to your GitHub account. This will allow you to make changes and submit pull requests
  later on.
- Adjust the `predictive-kubernetes-scaling.observability-labs.dynatrace.com/managed-by-repo` annotations in 
- [`apps/horizontal-scaling/deployment.yaml`](../apps/horizontal-scaling/deployment.yaml) and
  [`apps/vertical-scaling/deployment.yaml`](../apps/vertical-scaling/deployment.yaml) to match your forked repository.
- Create a new Codespace
    - In your forked repository, click the green `Code` button and switch to the `Codespaces` tab.
    - Click `...` and select `New with options...`.
      > ⚠️ Don't click the green `Create codespace` button in this step.
    - Enter the credentials you generated in [step 1](#1-prepare-your-environment).
    - Click `Create Codespace`.
- Wait for the Setup to complete. The Codespace will run a `postCreate` command to initialize your environment. This may
  take a few minutes. You'll know it's ready when the `zsh` shell is shown again.
    - If you want to check the progress, you can press `Ctrl + Shift + P` and type `Creation Log` to see the setup logs
      once the Codespace has initialized.

## 3. Explore What Has Been Deployed

Your Codespace has now deployed the following resources:

- A local Kubernetes ([kind](https://kind.sigs.k8s.io/)) cluster monitored by Dynatrace, with some pre-deployed apps
  that will be used later in the demo.
- Three [Dynatrace workflows](https://www.dynatrace.com/platform/workflows/):
    - **Predict Kubernetes Resource Usage**: This workflow predicts the future resource usage of Kubernetes workloads
      using Davis predictive AI. If a workload is likely to exceed its resource quotas, the workflow creates a custom
      Davis event with all necessary information.
    - **Commit Davis Suggestions**: Triggered by the predictive workflow's events, this workflow uses Davis CoPilot and
      the GitHub for Workflows app to create pull requests for remediation suggestions.
    - **React to Resource Saturation**: If the prediction actually misses some resource spikes, this workflow will get
      alerted via the automatically created Davis problem and will trigger the prediction workflow to immediately react
      and create a pull request. This workflow is disabled by default to avoid unwanted triggers of the prediction
      workflow.
- A [Dynatrace notebook](https://www.dynatrace.com/platform/notebooks/) that provides a more in-depth overview of how
  the deployed workflows work.
- A [Dynatrace dashboard](https://www.dynatrace.com/platform/dashboards/) that shows a summary of all predictions and 
  their accuracy.

## 4. Grab a Coffee

Before moving on, Davis AI needs around 20 minutes to analyze your Kubernetes workloads and establish a baseline for
predictive analysis. You can check its progress by navigating to the newly deployed "Predictive Kubernetes Scaling"
notebook and running the DQL query in the "2. Predict Resource Usage" step. If the results indicate that Davis AI is
ready, you can proceed to [step 5](#5-generate-some-load).

Just make sure that your Codespace does not expire within that time by e.g. clicking into the window from time to time.
Check out the [GitHub Codespace documentation](https://docs.github.com/en/codespaces/setting-your-user-preferences/setting-your-timeout-period-for-github-codespaces)
to read more about timeout periods for Codespaces and how to configure them.

## 5. Generate Some Load

> ⚠ Before proceeding, ensure Davis AI has finished creating a baseline for your workloads
> (see [step 4](#4-grab-a-coffee) for more information).

Now, let's simulate a scenario where workload increases and triggers a resource prediction:

- Go to your Codespace and open the terminal window.
- Run `./generate-load.sh` to put some load on the deployed demo app. You can choose between two options here:
    - `horizontal-scaling`: Generates load on a deployment that is scaled by a `HorizontalPodAutoscaler` (HPA). In that
      case, the max replicas of the HPA will be adjusted by the workflow.
    - `vertical-scaling`: Generates load on a standard deployment that is not scaled by any other resource. In that
      case,
      the resource quotas of the deployment will be adjusted by the workflow.
- Wait a few minutes again as it will take a bit for the Davis resource prediction to actually exceed the defined
  quotas. You can track progress in the "Predictive Kubernetes Scaling" notebook again. Usually, the CPU will spike
  first and memory will stay stable most of the time.

## 6. Watch the Magic Happen

By now, the deployed Dynatrace workflows should have sprung into action, and you should find an auto-remediation pull
request in your forked repository. Let's explore what happened behind the scenes:

- Navigate to Workflows:  Press `Ctrl + K` (or `Cmd + K` on Mac) and type "Workflows" to open the Dynatrace Workflows
  app.
- Check the "Predict Kubernetes Resource Usage" Workflow:
    - Find the "Predict Kubernetes Resource Usage" workflow in the list and click on it.
    - Click on `Run` in the top right of the toolbar to trigger the workflow.
    - Wait for the execution to see details of each step. The final step should be emitting a `CUSTOM_INFO` Davis event,
      which triggers the next workflow.
- Check the "Commit Davis Prediction" Workflow:
    - Navigate back to the workflows home page.
    - Find the "Commit Davis Prediction" workflow, click the three dots in the top right and select
      `View execution history`.
    - Examine each step to understand how the workflow applied Davis CoPilot's suggestions.
- Review the Pull Request:
    - Go to your forked repository on GitHub.
    - You should see an open pull request with the changes made by the workflow.

## 7. Troubleshooting

If any steps failed:

- Consult the Notebook: The "Predictive Kubernetes Scaling" notebook can provide valuable insights into potential
  issues.
- Raise an Issue: Feel free to raise an issue in this repository for assistance.