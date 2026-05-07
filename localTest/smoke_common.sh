#!/usr/bin/env bash

# Shared functions for integration and runtime smoke tests.
# Meant to be sourced by other scripts.

if [[ -n "${KWKHTMLTOPDF_SMOKE_COMMON_SOURCED:-}" ]]; then
  return 0
fi
KWKHTMLTOPDF_SMOKE_COMMON_SOURCED=1

set -euo pipefail

smoke_assert_grep() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq -- "$needle" <<<"$haystack"; then
    echo "[smoke] expected to find: $needle" >&2
    exit 1
  fi
}

smoke_metric_value() {
  local metrics="$1"
  local series="$2"
  grep -F -- "$series" <<<"$metrics" | head -n 1 | awk '{print $2}'
}

smoke_assert_number_ge() {
  local got="$1"
  local min="$2"
  awk -v got="$got" -v min="$min" 'BEGIN { exit(got+0 < min+0) }'
}

smoke_assert_number_gt() {
  local got="$1"
  local min="$2"
  awk -v got="$got" -v min="$min" 'BEGIN { exit(got+0 <= min+0) }'
}

smoke_wait_for_ready() {
  local base_url="$1"
  local attempts="${2:-100}"
  local sleep_s="${3:-0.1}"

  for i in $(seq 1 "$attempts"); do
    if curl -fsS "$base_url/status" >/dev/null; then
      return 0
    fi
    sleep "$sleep_s"
  done
  return 1
}

smoke_prepare_html_input() {
  local workdir="$1"
  local data_dir="$2"
  local domain_label="$3"

  local html_in="$workdir/report.cookie_jar_test1.html"
  cat "$data_dir/test1.html" >"$html_in"
  printf '\n<!-- domain=%s; -->\n' "$domain_label" >>"$html_in"
  echo "$html_in"
}

smoke_request_pdf() {
  local base_url="$1"
  local html_in="$2"
  local out_file="$3"

  curl -fsS -X POST "$base_url/pdf" \
    -F "file=@${html_in};filename=report.cookie_jar_test1.html" \
    -o "$out_file"

  if ! head -c 4 "$out_file" | grep -q "%PDF"; then
    echo "[smoke] expected PDF output" >&2
    head -c 64 "$out_file" | cat -v >&2 || true
    exit 1
  fi
}

smoke_request_image() {
  local base_url="$1"
  local html_in="$2"
  local out_file="$3"

  curl -fsS -X POST "$base_url/image" \
    -F "file=@${html_in};filename=report.cookie_jar_test1.html" \
    -o "$out_file"

  local img_sig_hex
  img_sig_hex="$(od -An -t x1 -N 8 "$out_file" | tr -d ' \n')"

  # Accept common wkhtmltoimage outputs:
  # - PNG signature: 89 50 4E 47 0D 0A 1A 0A
  # - JPEG signature prefix: FF D8 FF
  if [[ "$img_sig_hex" != "89504e470d0a1a0a" && "${img_sig_hex:0:6}" != "ffd8ff" ]]; then
    echo "[smoke] unexpected image output (signature: $img_sig_hex)" >&2
    exit 1
  fi
}

smoke_fetch_metrics() {
  local base_url="$1"

  local ct
  ct="$(curl -fsSI "$base_url/metrics" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type" {print tolower($2)}' | head -n 1)"
  case "$ct" in
    text/plain*version=0.0.4*)
      ;;
    *)
      echo "[smoke] unexpected /metrics Content-Type: $ct" >&2
      exit 1
      ;;
  esac

  curl -fsS "$base_url/metrics"
}

smoke_validate_metrics() {
  local metrics="$1"
  local domain_label="$2"

  # Basic presence checks
  smoke_assert_grep "$metrics" "# TYPE kwkhtmltopdf_conversions_total counter"
  smoke_assert_grep "$metrics" "# TYPE kwkhtmltopdf_conversion_duration_seconds histogram"
  smoke_assert_grep "$metrics" "# TYPE kwkhtmltopdf_conversion_output_bytes_total counter"

  local pdf_conv_series="kwkhtmltopdf_conversions_total{type=\"pdf\",domain=\"$domain_label\",result=\"success\"}"
  local img_conv_series="kwkhtmltopdf_conversions_total{type=\"image\",domain=\"$domain_label\",result=\"success\"}"
  smoke_assert_grep "$metrics" "$pdf_conv_series"
  smoke_assert_grep "$metrics" "$img_conv_series"
  smoke_assert_number_ge "$(smoke_metric_value "$metrics" "$pdf_conv_series")" 1
  smoke_assert_number_ge "$(smoke_metric_value "$metrics" "$img_conv_series")" 1

  local pdf_dur_count_series="kwkhtmltopdf_conversion_duration_seconds_count{type=\"pdf\",domain=\"$domain_label\",result=\"success\"}"
  local img_dur_count_series="kwkhtmltopdf_conversion_duration_seconds_count{type=\"image\",domain=\"$domain_label\",result=\"success\"}"
  smoke_assert_grep "$metrics" "$pdf_dur_count_series"
  smoke_assert_grep "$metrics" "$img_dur_count_series"
  smoke_assert_number_ge "$(smoke_metric_value "$metrics" "$pdf_dur_count_series")" 1
  smoke_assert_number_ge "$(smoke_metric_value "$metrics" "$img_dur_count_series")" 1

  local pdf_bytes_series="kwkhtmltopdf_conversion_output_bytes_total{type=\"pdf\",domain=\"$domain_label\",result=\"success\"}"
  local img_bytes_series="kwkhtmltopdf_conversion_output_bytes_total{type=\"image\",domain=\"$domain_label\",result=\"success\"}"
  smoke_assert_grep "$metrics" "$pdf_bytes_series"
  smoke_assert_grep "$metrics" "$img_bytes_series"
  smoke_assert_number_gt "$(smoke_metric_value "$metrics" "$pdf_bytes_series")" 0
  smoke_assert_number_gt "$(smoke_metric_value "$metrics" "$img_bytes_series")" 0
}

smoke_run_conversion_and_metrics_checks() {
  local base_url="$1"
  local data_dir="$2"
  local domain_label="$3"

  local workdir
  workdir="$(mktemp -d)"

  local html_in
  html_in="$(smoke_prepare_html_input "$workdir" "$data_dir" "$domain_label")"

  local pdf_out="$workdir/out.pdf"
  local img_out="$workdir/out.img"

  smoke_request_pdf "$base_url" "$html_in" "$pdf_out"
  smoke_request_image "$base_url" "$html_in" "$img_out"

  local metrics
  metrics="$(smoke_fetch_metrics "$base_url")"
  smoke_validate_metrics "$metrics" "$domain_label"
}
