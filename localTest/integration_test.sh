#!/usr/bin/env bash
set -euo pipefail

base_url="http://127.0.0.1:8080"

. /usr/local/bin/smoke_common.sh

/usr/local/bin/kwkhtmltopdf_server &
server_pid=$!

cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT


if ! smoke_wait_for_ready "$base_url" 80 0.1; then
  echo "[smoke] server did not become ready" >&2
  exit 1
fi

domain_label="example.com"
smoke_run_conversion_and_metrics_checks "$base_url" "/tests/data" "$domain_label"
