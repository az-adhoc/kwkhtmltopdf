#!/usr/bin/env bash
set -euo pipefail

image_tag="${IMAGE_TAG:-kwkhtmltopdf:dev}"
container_name="${CONTAINER_NAME:-kwkhtmltopdf-runtime-smoke}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

. "$repo_root/localTest/smoke_common.sh"

cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$repo_root"

echo "[smoke] building runtime image: $image_tag" >&2
docker build -f localTest/Dockerfile --target runtime -t "$image_tag" . >/dev/null

echo "[smoke] starting container: $container_name" >&2
docker rm -f "$container_name" >/dev/null 2>&1 || true
docker run -d --name "$container_name" -p 127.0.0.1::8080 "$image_tag" >/dev/null

host_port="$(docker port "$container_name" 8080/tcp | head -n 1 | awk -F: '{print $NF}')"
if [[ -z "$host_port" ]]; then
  echo "[smoke] failed to determine mapped host port" >&2
  exit 1
fi
base_url="http://127.0.0.1:${host_port}"

echo "[smoke] container is on $base_url" >&2

if ! smoke_wait_for_ready "$base_url" 100 0.1; then
  echo "[smoke] server did not become ready" >&2
  docker logs "$container_name" >&2 || true
  exit 1
fi

domain_label="example.com"
smoke_run_conversion_and_metrics_checks "$base_url" "$repo_root/tests/data" "$domain_label"

echo "[smoke] OK" >&2
