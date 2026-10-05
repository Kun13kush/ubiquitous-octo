# AWS development deployment — 6 October 2026

Target: account `732108543574`, operator `bandit`, region `eu-west-2`, hostname `finzla.kunlekush.name.ng`, repository `Kun13kush/ubiquitous-octo`.

Bootstrap deployed successfully: 8 resources created, none modified/deleted. A private, encrypted, versioned state bucket and repository-scoped GitHub plan role exist. Bootstrap state has been migrated into S3 with native lock files. The ACM certificate has been requested and is waiting for external Whogohost DNS validation.

The real infrastructure plan passed: 44 resources to create, none to modify/delete, initially with zero tasks for image seeding. ECR and its untagged-image lifecycle policy have also been created successfully (2 resources, no changes/deletes). The ALB, private endpoints and tasks have not been deployed while certificate validation is pending. An ECR-only targeted plan is used once for initial image seeding; subsequent full plans reconcile the entire root. Targeting is not the normal infrastructure-change process.

Current blocker: the authoritative Whogohost nameservers do not yet return the validation CNAME. Its expected full name is `_8b30ee0f16b80b6caeaa3563542f4f8e.finzla.kunlekush.name.ng`, pointing to `_d0420b4f533823031506f99f5c9b431e.wzccmgtwzk.acm-validations.aws`. Do not remove that record after validation: ACM uses it for renewal.

The exact OIDC trust includes immutable owner/repository IDs: `repo:Kun13kush@105042280/ubiquitous-octo@1406475293:environment:development` (and matching `terraform-plan` environment for the read-only role). This matches GitHub's subject format for repositories created after July 15, 2026. [GitHub OIDC documentation](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

## Cost estimate

AWS Pricing API London on-demand rates were queried on 6 October 2026. At 730 hours/month:

| Baseline component | Monthly USD |
|---|---:|
| Six interface endpoint AZ attachments at $0.011/hour each | 48.18 |
| Two Linux x86 Fargate tasks, each 0.25 vCPU / 0.5 GB | 20.72 |
| One ALB at $0.02646/hour | 19.32 |
| Two in-use public IPv4 addresses at $0.005/hour each | 7.30 |
| Total baseline | **95.52** |

This excludes LCUs, endpoint processing, CloudWatch/Container Insights, storage, data transfer, taxes, and any external DNS-provider fees. ALB LCUs cost $0.0084 per LCU-hour in this region. The baseline is an estimate, not a spending cap. [PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/), [Fargate pricing](https://aws.amazon.com/fargate/pricing/), [ALB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/).

Production AWS infrastructure is not being deployed. Production GitHub protection requires main and prevents self-review; an independent review path must be arranged before any production deployment.
