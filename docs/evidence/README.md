# Assessment evidence

Captured on 7 October 2026 (Africa/Lagos). Local checks were rerun; AWS and GitHub deployment evidence is historical from 6 October. Both AWS environments have been deleted and workflows remain disabled. No resources were deployed to collect this evidence.

| Requirement | Actual output / source |
| --- | --- |
| Successful Docker build | [Build output](docker-build.txt), exit code 0; `docker build --progress=plain --build-arg APP_VERSION=evidence-2026-10-07 -t finzla:evidence .` |
| Terraform validate | [Validation output](terraform-validate.txt), `terraform validate -no-color` |
| Terraform plan | [Historical AWS-backed production plan](terraform-production-plan.txt): 42 additions, no changes/deletions; [post-release plan](terraform-production-no-drift.txt): no changes |
| Local mocked plan | [Terraform test output](terraform-mocked-plan.txt): 1 passed, 0 failed; `terraform test -no-color`, test uses `command = plan` with mocked AWS |
| Green GitHub validation | [Run metadata](github-validation-run.json), [successful run 37392433704](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37392433704) |
| Green development deployment | [Run metadata](github-development-run.json), [successful run 37392433623](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37392433623) |
| Green production deployment | [Run metadata](github-production-run.json), [successful run 37395863727](https://github.com/Kun13kush/ubiquitous-octo/actions/runs/37395863727) |
| Live health checks | [Historical production verification log excerpt](historical-health-check.txt); release verification follows five public HTTPS health/version checks |

Terraform validation and the mocked plan used an isolated copy of the infrastructure configuration with no auto-tfvars or backend initialization, and the existing locked AWS provider. They did not access AWS state. Historical AWS-backed plan logs were preserved locally before shutdown; no new AWS plan or apply was performed. The full plan already had two ECR resources created for image seeding, explaining the remaining 42 additions.

The deployment script suppresses successful health response bodies. The evidence preserves the actual verification line and successful workflow step rather than manufacturing response output. See [development deployment history](../deployment.md), [production history](../production-deployment.md), and [shutdown receipt](../shutdown.md) for context.

Only selected public configuration/output is included. Terraform state, binary plans, credentials and private shutdown archives are excluded. Screenshots are unnecessary because the requested alternative—actual output and linked runs—is provided.
