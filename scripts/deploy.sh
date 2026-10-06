#!/usr/bin/env bash
set -Eeuo pipefail
: "${ECR_REPOSITORY:?}" "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}" "${BASE_URL:?}" "${RELEASE:?}" "${AWS_REGION:?}"
[[ "$BASE_URL" == https://* ]] || { echo "BASE_URL must use HTTPS" >&2; exit 1; }
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
export DOCKER_CONFIG="$work_dir/docker-auth"
mkdir -m 700 "$DOCKER_CONFIG"
registry="${ECR_REPOSITORY%%/*}"
repository="${ECR_REPOSITORY#*/}"
tag="${RELEASE}-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$registry"
docker tag finzla:release "$ECR_REPOSITORY:$tag"
docker push "$ECR_REPOSITORY:$tag"
digest=$(aws ecr describe-images --repository-name "$repository" --image-ids "imageTag=$tag" --query 'imageDetails[0].imageDigest' --output text)
[[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
previous=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].taskDefinition' --output text)
[[ "$previous" == arn:* ]]
aws ecs describe-task-definition --task-definition "$previous" --query taskDefinition > "$work_dir/current.json"
python3 scripts/render_task.py "$work_dir/current.json" "$ECR_REPOSITORY@$digest" > "$work_dir/new.json"
next=$(aws ecs register-task-definition --cli-input-json "file://$work_dir/new.json" --query 'taskDefinition.taskDefinitionArn' --output text)
# ECS services-stable can precede rolloutState=COMPLETED by several seconds.
wait_release() {
  local expected="$1" status attempt
  aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" || return 1
  for attempt in {1..24}; do
    aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" > "$work_dir/service.json" || return 1
    if python3 scripts/check_release.py "$work_dir/service.json" "$expected"; then
      return 0
    else
      status=$?
      [[ "$status" == 3 ]] || return "$status"
    fi
    sleep 5
  done
  echo "Timed out waiting for exact release completion: $expected" >&2
  return 1
}
# Arm rollback before UpdateService: a timeout can occur after AWS accepted the change.
rollback() {
  trap - ERR INT TERM
  echo "Release failed; restoring $previous" >&2
  if aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --task-definition "$previous" > /dev/null &&
     wait_release "$previous" &&
     [[ "$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" --query 'services[0].taskDefinition' --output text)" == "$previous" ]] &&
     curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "$BASE_URL/health"; then
    echo "Previous task definition restored; investigate failed release." >&2
  else
    echo "ROLLBACK UNCONFIRMED: page on-call and inspect ECS/ALB immediately." >&2
  fi
  exit 1
}
trap rollback ERR INT TERM
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --task-definition "$next" > /dev/null
wait_release "$next"
# Verify the public TLS route and exact release, not merely that some task is healthy.
for attempt in {1..5}; do
  curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "$BASE_URL/health" > /dev/null
  curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "$BASE_URL/version" > "$work_dir/version.json"
  python3 - "$work_dir/version.json" "$RELEASE" <<'CHECK'
import json, sys
assert json.load(open(sys.argv[1]))["version"] == sys.argv[2], "Wrong release served"
CHECK
  sleep 2
done
trap - ERR INT TERM
echo "Verified release $RELEASE ($next)"
