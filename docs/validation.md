# Local validation evidence

Validated on 5–6 October 2026 (Africa/Lagos) in Ubuntu WSL. This report records observed results; it records the initial local build phase. Subsequent live AWS and GitHub results are in [deployment.md](deployment.md). The assessment attachment was a text export and was reviewed before implementation.

| Check | Observed result |
|---|---|
| Python HTTP/application and release tests | **PASS**: 10 tests with `python3 -m unittest discover -s tests -v` on Python 3.14.4 |
| HTTP behavior | 200 health, exact environment/version JSON, and 404 unknown route |
| Deployment logic with fake AWS/Docker/HTTP tools | Success updates once; automatic rollback is treated as failure; wrong public version restores previous revision; UpdateService timeout restores previous revision; failed rollback is reported unconfirmed |
| Task-definition rendering | Retains roles and container security settings, changes only app image, removes AWS response-only fields, rejects missing app container |
| Docker build | **PASS**: digest-pinned Python 3.13 Alpine image, `APP_VERSION=local-validation`, tag `finzla:local` |
| Docker smoke | **PASS**: real localhost HTTP health/version; Docker reports healthy; configured UID 10001 and read-only filesystem; temporary container removed |
| Terraform formatting | **PASS**: both `infra/` and `bootstrap/`, recursive checks |
| Terraform infrastructure validation | **PASS** with Terraform 1.15.9 / AWS provider 6.67.0 |
| Terraform bootstrap validation | **PASS**, including optional production bucket-only bootstrap |
| Mocked infrastructure plan | **PASS**: 1 test, private tasks, redundant capacity, HTTPS ingress, circuit breaker rollback, no private default routes, ALB-only task ingress, read-only filesystem |
| Mocked bootstrap plan | **PASS**: 1 test, private versioned state and no production PR plan role |
| Bandit 1.8.6 on Python 3.13.16 | **PASS**: 26 application lines scanned, zero findings, zero skipped files; intentional B104 exclusion for container bind address |
| Final Trivy 0.70.0 scan | **PASS**: Alpine 3.24.2, 29 OS packages, zero HIGH/CRITICAL findings, no third-party Python packages; [raw JSON report](image-scan.json) |
| Shell syntax | **PASS**: deployment, container-smoke, and image-scan scripts |
| Workflow YAML and action pins | **PASS**: YAML parsed; action references checked as 40-character SHA pins. This is not GitHub runtime validation |
| Deliverable-only secret-marker/whitespace scan | **PASS** before report creation: 31 files; no AWS key markers, GitHub token markers, private key headers or trailing whitespace. Heuristic only, not a comprehensive secret audit |

Reproduce the infrastructure checks without configuring an AWS account:

```bash
terraform -chdir=infra init -backend=false -lockfile=readonly
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test -no-color
terraform -chdir=bootstrap init -backend=false -lockfile=readonly
terraform -chdir=bootstrap fmt -check -recursive
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap test -no-color
```

Terraform tests use `mock_provider "aws"`, explicitly overridden account/AZ data, and `command=plan`. They do **not** contact AWS or apply resources. A mocked plan demonstrates resource structure and invariants, not real ARN resolution, permissions, certificate validity, service reachability, or deployability in a particular account. Commit both `.terraform.lock.hcl` files; the provider package was verified by Terraform as signed by HashiCorp. Bootstrap reused that downloaded provider and its checksum lock file.

Docker reproduction:

```bash
docker build --build-arg APP_VERSION=local-validation -t finzla:local .
bash scripts/container-smoke.sh
docker run --rm -v "$PWD/app:/scan:ro" --user 0 --entrypoint sh python:3.13-slim@sha256:3dd7cc108ec1493442514f5c2a871af6af0ec31d768ff6e378a93340c3b3db5f \\
  -c 'pip install --quiet bandit==1.8.6 && bandit -r /scan -s B104'
```

Bandit runs as root only inside a disposable tooling container so pip can install the scanner; the service image/workload remains non-root. The initial WSL Python 3.14 Bandit invocation encountered a compatibility exception and skipped the app despite exiting zero; that result was discarded. The successful scan used the same Python 3.13 runtime as CI and reported no skipped files. Sandbox restrictions required approval for Docker access, local socket tests, provider plugin sockets and public dependency downloads.

## Image security evidence

The final image uses `python:3.13-alpine@sha256:2d9aefe2fef018a7eb2c13064c89c71929800fd2e5dccdbf52ea5da5bb8d929a`, applies available Alpine upgrades, and removes unused pip/site-packages/ensurepip wheels. It passed the same digest-pinned Trivy 0.70.0 HIGH/CRITICAL gate configured in CI. Reproduce with `bash scripts/scan-image.sh`; its database cache is gitignored. The report identifies the image and scan timestamp, so do not reuse its result for a later rebuild.

An initial Debian image failed the scan: after available OS upgrades and packaging-tool removal it still had 44 HIGH package findings across eight distinct CVEs with no listed fixes. The final runtime switched to Alpine; no vulnerability exceptions or `--ignore-unfixed` flags were added. The final HTTP, version, Docker health, non-root and read-only smoke checks passed after that switch.

The scanner emitted warnings about third-party SBOM accuracy and its built-in EOL list not recognizing Alpine 3.24. CVE scanning did execute against Alpine 3.24 and inventoried 29 packages. Keep the scanner/base pins updated through reviewed changes; a zero HIGH/CRITICAL result is not proof of absence of vulnerabilities and does not assess lower-severity findings or application logic.

## Not tested against AWS or GitHub

- Real AWS-backed `terraform plan`/apply, backend permissions/locking and state recovery.
- ECR authentication/push, IAM policy evaluation, OIDC token subject matching, and cross-account isolation.
- ECS scheduling, private endpoint downloads, ALB registration/TLS, ACM/DNS, deployment circuit breaker and live rollback.
- CloudWatch metric math/alarms, SNS confirmation/delivery, dashboard telemetry, load behavior and AZ failure.
- GitHub Actions execution and action download resolution, environment approval enforcement, CODEOWNERS, branch protection and fork/trusted-PR behavior. No repository was created remotely or pushed.
- Production release verification or recovery under runner cancellation, IAM failure or complete lack of healthy tasks. Rollback logic was exercised with mocks only.

The README supplies the remaining environment inputs and setup steps. **At the initial local-build phase, no AWS deployment was attempted and no credentials were added to source. The user subsequently authorized development deployment; see [deployment.md](deployment.md) for live evidence and remaining untested items.**
