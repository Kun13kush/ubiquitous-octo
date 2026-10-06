# Production deployment — 6 October 2026

Account `732108543574`, operator `bandit`, region `eu-west-2`, hostname `finzla-prod.kunlekush.name.ng`. User authorized same-account production and a one-time first-release self-approval exception, followed by restoration of production protection.

## Isolation and state

Provisioning runs in an isolated worktree at `.deployment/production-worktree`, based on main `89fd129ae3606b96f581527851df172704b111ba`. It does not load development auto-tfvars or backend metadata. Production has its own state bucket `finzla-production-tfstate-732108543574-eu-west-2`, S3 native locks, keys `bootstrap/terraform.tfstate` and `production/terraform.tfstate`, VPC CIDR `10.30.0.0/16`, ECR repository, ECS cluster/service and IAM roles. No new development plan role is created.

The production checkout's `infra/environments/production.tfvars` explicitly uses London. The production tfvars template is updated to London to match the live deployment; use the separate production backend when rebuilding it. Its bootstrap `production-tags_override.tf` tags the production certificate correctly; the original bootstrap certificate template defaults to development tags.

Same-account isolation is weaker than separate accounts. Development release service updates and PassRole permissions do not cover production. The existing plan role has account-wide metadata discovery, and deployment roles can read task-definition configurations in eu-west-2 because AWS does not support ARN scoping for DescribeTaskDefinition. Neither empty application task role can access business data.

## Resources and image

Bootstrap apply created six new resources, no changes/deletions. Its encrypted, versioned, private TLS-only bucket contains migrated bootstrap state. ACM certificate `arn:aws:acm:eu-west-2:732108543574:certificate/d3aa910c-3791-4fa2-982b-da273dd92a6f` is issued.

Keep the ACM validation CNAME: `_afb5e2afcad84d2cb0a3f2743f326145.finzla-prod.kunlekush.name.ng` -> `_de7a9c1f935dd95b4e2a23c0a3d0bc2a.wzccmgtwzk.acm-validations.aws`. Both authoritative Whogohost nameservers return it.

A one-time ECR-only targeted apply created two resources for initial seeding. The following full plan reconciles the entire root; targeting is not routine deployment practice. All 15 Python tests passed. The seed image passed pinned Trivy 0.70.0 with zero HIGH/CRITICAL findings and was uploaded to `732108543574.dkr.ecr.eu-west-2.amazonaws.com/finzla-production@sha256:2826fe6f3607d9fe78f254c0e677f82453d7c8ba052f4772f6995a64771b43df`. Temporary Docker credentials were removed after push.

The reviewed full plan adds 42 resources, changes/deletes none, with two private Fargate tasks in separate AZs, production ALB deletion protection and 90-day application-log retention. Full apply succeeded: 42 resources added, none changed/deleted. Initial seed health checks are in progress.

Production baseline estimate is another $95.52/month at 730 hours using the London rates recorded in [development deployment](deployment.md), plus LCUs, monitoring, storage, data processing/transfer and taxes. Combined development and production baseline is about $191.04/month before those extras.

## Pending checks

Full apply and seed validation passed: both ALB targets are healthy in eu-west-2a/eu-west-2b, the ECS stable waiter passed, and certificate-verified HTTPS using curl --connect-to returned the expected main revision with environment production. Public application DNS, GitHub production OIDC release, restored gate, post-release drift and production SNS email confirmation are pending. Load/failure/DR exercises, delivery of alarm emails and injected circuit-breaker recovery remain untested. Development's live rollback exercise does not demonstrate every production failure scenario.

Application CNAME: `finzla-prod.kunlekush.name.ng` -> `finzla-production-1427615191.eu-west-2.elb.amazonaws.com`, TTL 300.

Post-apply full Terraform plan exited 0: no changes. AWS IAM simulation returned implicitDeny for development deployment role updating production and for production deployment role updating development. These are policy-simulator checks, not attempted live cross-environment mutations.

First production workflow [37395863727](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37395863727) is waiting for environment approval. The self-review exception has not been applied; public application DNS is required before approval so the release checks can pass. Production alert email subscription remains PendingConfirmation.
