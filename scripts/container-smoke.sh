#!/usr/bin/env bash
set -Eeuo pipefail
# Local Docker only; random localhost port avoids exposing the test service.
container=$(docker run -d --read-only --cap-drop=ALL --security-opt=no-new-privileges -e APP_ENV=validation -p 127.0.0.1::8080 finzla:local)
cleanup() { docker logs "$container"; docker rm -f "$container" > /dev/null; }
trap cleanup EXIT
port=$(docker inspect --format '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' "$container")
for attempt in {1..30}; do
  if curl --fail --silent "http://127.0.0.1:$port/health" > /dev/null; then break; fi
  sleep 1
done
curl --fail --silent "http://127.0.0.1:$port/health"
curl --fail --silent "http://127.0.0.1:$port/version" | python3 -c 'import json,sys; value=json.load(sys.stdin); assert value == {"version":"local-validation", "environment":"validation"}; print(value)'
for attempt in {1..30}; do
  status=$(docker inspect --format '{{.State.Health.Status}}' "$container")
  if [[ "$status" == healthy ]]; then break; fi
  sleep 1
done
[[ "$status" == healthy ]]
[[ "$(docker inspect --format '{{.Config.User}}' "$container")" == '10001:10001' ]]
[[ "$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$container")" == true ]]
echo 'Docker HTTP, version, healthcheck, non-root and read-only configuration: PASS'
