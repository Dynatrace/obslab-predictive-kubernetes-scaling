# Dynatrace Observability Lab: Predictive Auto-Scaling for Kubernetes Workloads

Struggling to keep up with the demands of dynamic Kubernetes environments? Manual scaling is not only time-consuming and
reactive but also prone to errors. In this demo we harness the power of Dynatrace Automations and Davis AI to predict
resource bottlenecks and automatically open pull requests to scale applications. This proactive approach minimizes
downtime, helps you to optimize resource utilization, and ensures your applications perform at their best.

We achieve this by combining predictive AI to forecast resource limitations with generative AI to modify Kubernetes
manifests on GitHub by creating pull requests for scaling adjustments. If you'd like a closer look at how this works,
you can either [run the full demo on your own (trial) tenant](./getting-started.md)
or [explore further resources](./resources.md).

## Considerations and Limitations

While this demo showcases the power of automating Kubernetes scaling, it's important to be aware of a few aspects to
ensure smooth integration into your specific environment:

- **Davis CoPilot API Usage**: This demo utilizes Davis CoPilot API calls for its generative AI capabilities. These
  calls do cause costs, so it's recommended to review the [Davis CoPilot pricing model](todo) to understand potential
  expenses in your use case.
- **GitOps Deployment Assumptions**: For the automatic scaling pull requests to function effectively, the demo makes
  some assumptions about your GitOps setup:
    - Each Kubernetes manifest must be located in its own individual file.
    - Each Kubernetes manifest must not only include `kind` and `metadata.name` but also `metadata.namespace`.
    - The Kubernetes Auto Remediation workflows will only target workloads with these specific annotations. This
      behavior could be changed but was introduced to speed up workflow runs and save resources.
        - `observability-labs.dynatrace.com/commit-scaling-suggestions: 'true'`
        - `observability-labs.dynatrace.com/managed-by-repo: 'URL_TO_REPO'` (Replace with the actual URL of your
          repository)
- **GitHub Codespace Usage**: If you follow the above instructions, a GitHub Codespace will be created under your
  account. While running this demo in a GitHub Codespace is free for most users due to generous usage limits and default
  billing settings, we recommend deleting the Codespace after completing the tutorial to avoid potential future charges
  if you exceed the free tier. To delete your Codespace, go to https://github.com/codespaces. For more information, see
  the [GitHub Codespaces documentation](GitHub Codespaces documentation).