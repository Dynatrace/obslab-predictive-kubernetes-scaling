# Dynatrace Observability Lab: Predictive Auto-Scaling for Kubernetes Workloads

--8<-- "snippets/disclaimer.md"
--8<-- "snippets/view-code.md"
--8<-- "snippets/bizevent-homepage.js"

Struggling to keep up with the demands of dynamic Kubernetes environments? Manual scaling is not only time-consuming and
reactive but also prone to errors. In this demo we harness the power of Dynatrace Automations and Davis AI to predict
resource bottlenecks and automatically open pull requests to scale applications. This proactive approach minimizes
downtime, helps you to optimize resource utilization, and ensures your applications perform at their best.

We achieve this by combining predictive AI to forecast resource limitations with generative AI to modify Kubernetes
manifests on GitHub by creating pull requests for scaling adjustments. If you'd like a closer look at how this works,
you can [run the full demo on your own tenant](./getting-started.md).

## Considerations and Limitations

While this demo showcases the power of automating Kubernetes scaling, it's important to be aware of a few aspects to
ensure smooth integration into your specific environment:

- **GitOps Deployment Assumptions**: For the automatic scaling pull requests to function effectively, the demo makes
  some assumptions about your GitOps setup:
    - The Kubernetes Auto Remediation workflows will only target workloads with these specific annotations. This
      behavior could be changed but was introduced to speed up workflow runs and save resources.
        - `predictive-kubernetes-scaling.observability-labs.dynatrace.com/enabled: 'true'`
- **GitHub Codespace Usage**: If you follow the above instructions, a GitHub Codespace will be created under your
  account. While running this demo in a GitHub Codespace is free for most users due to generous usage limits and default
  billing settings, we recommend deleting the Codespace after completing the tutorial to avoid potential future charges
  if you exceed the free tier. To delete your Codespace, go to https://github.com/codespaces. For more information, see
  the [GitHub Codespaces documentation](https://docs.github.com/en/codespaces/overview){target="_blank"}.
- **Davis CoPilot API Usage**: This demo utilizes Davis CoPilot API calls for its generative AI capabilities. These
  calls might cause costs in the future.

## Compatibility

| Deployment         | Tutorial Compatible |
|--------------------|---------------------|
| Dynatrace Managed  | ❌                 |
| Dynatrace SaaS     | ✔️                 |

<div class="grid cards" markdown>
- [Click Here to Begin :octicons-arrow-right-24:](getting-started.md)
</div>