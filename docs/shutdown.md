# Finzla shutdown receipt

Both development and production in AWS account 732108543574, eu-west-2, were decommissioned on 6 October 2026 at the owner's request.

Terraform successfully deleted 102 managed resources: development infrastructure 44 and bootstrap 8; production infrastructure 44 and bootstrap 6. All four final Terraform states contain zero managed resources. This removed the services, clusters, ALBs, networking and private endpoints, ECR repositories/images, project IAM roles, application logs, dashboards, alarms, SNS topics/subscriptions, ACM certificates and versioned state buckets.

Both generated Container Insights performance log groups were removed. Five development and two production task-definition revisions were deregistered and submitted for deletion; AWS may retain deletion-in-progress metadata temporarily after workloads terminate.

GitHub's Deploy application and Validate pull request workflows are disabled. Pending Terraform plan runs were cancelled. Repository source, documentation, recent log samples and private state archives were preserved locally. The pre-existing shared GitHub OIDC provider was retained. Temporary Terraform deletion overrides were removed after successful teardown.

Final direct AWS inventory checks covered Finzla VPCs, load balancers, target groups, ECR repositories, logs, alarms, dashboards, SNS topics, IAM roles, S3 buckets, ECS clusters and certificates. These checks concern this project, not all resources in the AWS account. Historical AWS charges remain payable.

## Manual DNS follow-up

Remove these four CNAME hosts from Whogohost under kunlekush.name.ng:

- `finzla`
- `finzla-prod`
- `_8b30ee0f16b80b6caeaa3563542f4f8e.finzla`
- `_afb5e2afcad84d2cb0a3f2743f326145.finzla-prod`

Keep unrelated domain records. DNS changes could not be performed through the available tools.

## Rebuilding later

Review the source and create new Terraform backends, certificates and ECR seed images. Update DNS, certificate ARNs, backend settings and GitHub deployment configuration before deliberately re-enabling workflows. Old ARNs, ALB targets and image digests in deployment records are historical.

Private shutdown evidence is in `.deployment/teardown/`, which is excluded from Git. The updated PDF includes a shutdown receipt on page 15.
