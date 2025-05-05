# Getting Started

## Requirements

--8<-- "snippets/preview-functionality.md"
--8<-- "snippets/bizevent-getting-started.js"

- A **Grail enabled Dynatrace SaaS Tenant**
  where [Davis CoPilot](https://www.dynatrace.com/platform/artificial-intelligence/){target="_blank"} is enabled ([sign up here](https://dt-url.net/trial){target="_blank"}).
- A **GitHub account** to interact with the demo repository.
- The GitHub for Workflows app installed (via Hub on your Dynatrace environment)
    - Press `ctrl + k`. Search for `Hub`.
    - In the hub, search for `Github for Workflows` and install the application

## 1. Prepare Your Environment

The [GitHub Codespace](https://github.com/features/codespaces){target="_blank"}, you will create within this demo, will automatically set
up a local Kubernetes cluster and deploy the necessary Dynatrace resources. To make this work, you'll need to provide
the below credentials and settings.

- A [Dynatrace API token](https://docs.dynatrace.com/docs/dynatrace-api/basics/dynatrace-api-authentication#dynatrace-api-tokens-and-authentication){target="_blank"}
to generate [other tokens used in this demo](https://github.com/Dynatrace/obslab-predictive-kubernetes-scaling/blob/main/dynatrace/tokens.tf){target="_blank"}. Permissions:
    - `apiTokens.read`
    - `apiTokens.write`
- A [Dynatrace OAuth 2.0 client](https://docs.dynatrace.com/docs/platform-modules/automations/cloud-automation/setup-cloud-automation/authentication#client){target="_blank"}
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
- A Dynatrace [Platform token](https://docs.dynatrace.com/docs/manage/identity-access-management/access-tokens-and-oauth-clients/platform-tokens){target=_blank} to trigger the Davis CoPilot from the demo workflow. Permissions:
    - `davis-copilot:conversations:execute`
- [Allow an outbound connection from Dynatrace](https://developer.dynatrace.com/develop/functions/allow-outbound-connections/){target="_blank"}
  to `api.github.com` so that the demo workflow can communicate with GitHub.

!!! info "Wait for GitHub to Index Your Fork"
    The Dynatrace workflow relies on GitHub search functionality. Therefore it is important to wait until GitHub search has indexed your fork.

    To test this, try searching your fork for `predictive-kubernetes-scaling.observability-labs.dynatrace.com`

    If you get a warning: `⚠️ This repository's code is being indexed right now. Try again in a few minutes.` you should not proceed.

    Wait until the search completes successfully, then proceed.

## 2. Create Your Development Environment

--8<-- "snippets/codespace-details-warning-box.md"

- Fork [this repository](https://github.com/Dynatrace/obslab-predictive-kubernetes-scaling/tree/main){target="_blank"} to your GitHub account. This will allow you to make changes and submit pull requests
  later on.
- Adjust the `predictive-kubernetes-scaling.observability-labs.dynatrace.com/managed-by-repo` annotations in 
- [`apps/horizontal-scaling/deployment.yaml`](https://github.com/Dynatrace/obslab-predictive-kubernetes-scaling/blob/main/apps/horizontal-scaling/deployment.yaml){target="_blank"} and
  [`apps/vertical-scaling/deployment.yaml`](https://github.com/Dynatrace/obslab-predictive-kubernetes-scaling/blob/main/apps/vertical-scaling/deployment.yaml){target="_blank"} to match your forked repository.
- Create a new Codespace
    - Go to [https://codespaces.new](https://codespaces.new){target=_blank}
    - Set the `repository` to your forked repo
    - Complete the variables requested in the form
    - Click `Create Codespace`
- Wait for the Setup to complete. The Codespace will run a `postCreate` command to initialize your environment. This may
  take a few minutes. You'll know it's ready when the `zsh` shell is shown again.
    - If you want to check the progress, you can press `Ctrl + Shift + P` and type `Creation Log` to see the setup logs
      once the Codespace has initialized.

## 3. Explore What Has Been Deployed

Your Codespace has now deployed the following resources:

- A local Kubernetes ([kind](https://kind.sigs.k8s.io/){target="_blank"}) cluster monitored by Dynatrace, with some pre-deployed apps
  that will be used later in the demo.
- Three [Dynatrace workflows](https://www.dynatrace.com/platform/workflows/){target="_blank"}:
    - **Predict Kubernetes Resource Usage**: This workflow predicts the future resource usage of Kubernetes workloads
      using Davis predictive AI. If a workload is likely to exceed its resource quotas, the workflow creates a custom
      Davis event with all necessary information.
    - **Commit Davis Suggestions**: Triggered by the predictive workflow's events, this workflow uses Davis CoPilot and
      the GitHub for Workflows app to create pull requests for remediation suggestions.
    - **React to Resource Saturation**: If the prediction actually misses some resource spikes, this workflow will get
      alerted via the automatically created Davis problem and will trigger the prediction workflow to immediately react
      and create a pull request. This workflow is disabled by default to avoid unwanted triggers of the prediction
      workflow.
- A [Dynatrace notebook](https://www.dynatrace.com/platform/notebooks/){target="_blank"} that provides a more in-depth overview of how
  the deployed workflows work.
- A [Dynatrace dashboard](https://www.dynatrace.com/platform/dashboards/){target="_blank"} that shows a summary of all predictions and 
  their accuracy.

## 4. Grab a Coffee

Before moving on, Davis AI needs around 20 minutes to analyze your Kubernetes workloads and establish a baseline for
predictive analysis. You can check its progress by navigating to the newly deployed "Predictive Kubernetes Scaling"
notebook and running the DQL query in the "2. Predict Resource Usage" step. If the results indicate that Davis AI is
ready, you can proceed to [step 5](#5-generate-some-load).

Just make sure that your Codespace does not expire within that time by e.g. clicking into the window from time to time.
Check out the [GitHub Codespace documentation](https://docs.github.com/en/codespaces/setting-your-user-preferences/setting-your-timeout-period-for-github-codespaces){target="_blank"}
to read more about timeout periods for Codespaces and how to configure them.

## 5. Generate Some Load

!!! info
    Before proceeding, ensure Davis AI has finished creating a baseline for your workloads
    (see [step 4](#4-grab-a-coffee) for more information).

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

<div class="grid cards" markdown>
- [Click Here to Continue :octicons-arrow-right-24:](cleanup.md)
</div>