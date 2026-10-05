#!/usr/bin/env bash
set -Eeuo pipefail
# Run from the repository root. Cache public vulnerability data for repeat scans.
mkdir -p .trivy-cache docs
scanner='ghcr.io/aquasecurity/trivy:0.70.0@sha256:85e87be1a96459c38a4eea47dc64eb2d342bb14cd4b4cef96adcf6ff03378b7c'
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/.trivy-cache:/root/.cache/trivy" -v "$PWD/docs:/reports" \
  "$scanner" image --no-progress --scanners vuln --exit-code 1 \
  --severity HIGH,CRITICAL --format json --output /reports/image-scan.json "${1:-finzla:local}"
