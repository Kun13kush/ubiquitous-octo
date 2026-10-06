# AWS development deployment — 6 October 2026

Target: account `732108543574`, operator `bandit`, region `eu-west-2`, hostname `finzla.kunlekush.name.ng`, repository `Kun13kush/ubiquitous-octo`.

Bootstrap deployed successfully: 8 resources created, none modified/deleted. A private, encrypted, versioned state bucket and repository-scoped GitHub plan role exist. Bootstrap state has been migrated into S3 with native lock files. The ACM certificate is issued following successful external Whogohost DNS validation.

The real infrastructure plan passed: 44 resources to create, none to modify/delete, initially with zero tasks for image seeding. ECR and its untagged-image lifecycle policy have also been created successfully (2 resources, no changes/deletes). The full development apply created the ALB, private endpoints and two tasks following certificate issuance. An ECR-only targeted plan is used once for initial image seeding; subsequent full plans reconcile the entire root. Targeting is not the normal infrastructure-change process.

Both authoritative Whogohost nameservers now return the correct CNAME. ACM status is now **ISSUED**. The full development infrastructure apply succeeded: 42 resources added, none changed/deleted. Its expected full name is `_8b30ee0f16b80b6caeaa3563542f4f8e.finzla.kunlekush.name.ng`, pointing to `_d0420b4f533823031506f99f5c9b431e.wzccmgtwzk.acm-validations.aws`. Do not remove that record after validation: ACM uses it for renewal.

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

The initial image was built from commit `578a5267d90396d7ea6a6ea163ac1c91e660992a`, passed all 10 Python tests and the strict HIGH/CRITICAL Trivy scan, and was pushed to ECR at digest `sha256:c007562a5931f75a6b5d91a3d7d773e19e23c4d1bbe94b60c8c78cd7ad4b249f`. Temporary Docker login credentials were removed after the push.

GitHub environments are configured: development and production permit only main; terraform-plan requires reviewer approval; production prevents self-review and disables administrator bypass. Production has no AWS deployment role/variables configured because it is outside this deployment scope.

After image seeding, the complete plan was regenerated: **42 remaining resources to create, no changes/deletes**, with the real image digest and two private tasks.

Application DNS: add CNAME `finzla` under `kunlekush.name.ng`, targeting `finzla-development-1257270431.eu-west-2.elb.amazonaws.com`, TTL 300. This is separate from the ACM renewal record. Both authoritative nameservers return the correct application CNAME, and normal public DNS HTTPS `/health` returns HTTP 200.

The SNS email subscription for `olakunle.kushehin@outlook.com` is confirmed, verified through the AWS API. Alarm email delivery has not been tested.

Initial live HTTPS `/health` returned HTTP 200 and `{"status": "ok"}` with the correct hostname and certificate verification, using curl `--connect-to` to reach the ALB while public DNS is pending. Both targets are healthy in eu-west-2a and eu-west-2b, and the ECS services-stable waiter passed. `/version` returned the expected initial commit SHA and `development` environment.

Repository published. Initial full CI validation passed: https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37391277450. OIDC authentication and ECR push passed in the first deployment, which stopped before service mutation because DescribeTaskDefinition was incorrectly scoped to an ARN. AWS requires Resource `*` for that read action; the corrected policy additionally restricts reads to the environment region. Existing service stayed healthy. Automatic approval review rejected both the unrestricted and region-limited read-policy corrections because they allow reading other task definitions. The user explicitly approved region-limited task-definition read access; the reviewed single-policy correction was applied successfully (one policy changed).

Live workflow rollback was exercised successfully in run https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37391604138: the stable waiter returned while rolloutState was still IN_PROGRESS, the strict assertion rejected the release, and the handler restored revision 1 with a successful public health check. A bounded completion wait and five regression checks fix this race; all 15 Python tests pass locally. The corrected release subsequently completed successfully; final evidence follows below.

Still untested: production deployment, injected application/ALB failures, confirmed SNS email delivery and the protected PR plan job. Production requires independent review and has no AWS resources deployed.

Post-apply full Terraform plan exited 0: no changes, infrastructure matches configuration.

CloudWatch log streams exist for both healthy tasks. AWS EC2 API confirms both task ENIs have private addresses only and no public association. Production environment protections were verified: main-only deployment branch, reviewer required, prevent_self_review=true and can_admins_bypass=false.

Main branch protection is active: validate check required, strict up-to-date checks, code-owner review, one approval, last-push approval, admin enforcement and no force pushes/deletions. Changes require an independent reviewer; the owner cannot self-approve their own pull request.

## Final verified release

On 6 October 2026 (Africa/Lagos), main commit `c13885dcf44118cb33c421f2ca46d24d6cc9756a` passed [full GitHub validation](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37392433704) and [OIDC application deployment](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37392433623). The deployment executed ECR authentication/push, revision registration, scoped service update, ECS completion polling, and five verified public health/exact-version checks.

Public endpoints: [health](https://finzla.kunlekush.name.ng/health) and [version](https://finzla.kunlekush.name.ng/version). Version reports the commit above and environment `development`. ECS task definition `finzla-development:3` is the sole completed deployment, with two running tasks and two healthy ALB targets across eu-west-2a/eu-west-2b.

PR #1 merged after passing its required validate check using the explicitly user-approved one-time main review exception. Review protection was immediately restored and independently verified: one approval, code-owner review, last-push approval, admin enforcement and the required validate check are active. Production protections were never relaxed. A collaborator able to provide independent review is required for future protected changes and owner-triggered production deployments.

Remaining untested: production deployment, circuit-breaker recovery from an injected unhealthy image, load/failure/DR exercises, delivery of SNS alarm emails, and the approval-gated PR Terraform plan runtime. The live workflow rollback path was exercised and verified; this does not prove recovery from every failure. No production infrastructure was created.

Final full Terraform plan after the GitHub release exited 0: no changes. The pipeline-owned service revision does not create infrastructure drift.
