#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 1
fi

OUTPUT_DIR="$1"
PORT="${ARCHBEE_PREVIEW_PORT:-3000}"
BASE_URL="http://127.0.0.1:${PORT}"
PREVIEW_CMD="${ARCHBEE_PREVIEW_CMD:-archbee dev}"
LOG_FILE="${ARCHBEE_PREVIEW_LOG:-archbee-preview.log}"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

cleanup() {
  if [[ -n "${PREVIEW_PID:-}" ]] && kill -0 "${PREVIEW_PID}" 2>/dev/null; then
    kill "${PREVIEW_PID}" 2>/dev/null || true
    wait "${PREVIEW_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
  echo "wget is required" >&2
  exit 1
fi

echo "Starting Archbee preview with: ${PREVIEW_CMD}"
CI=1 bash -lc "${PREVIEW_CMD}" >"${LOG_FILE}" 2>&1 &
PREVIEW_PID=$!

for _ in $(seq 1 120); do
  if curl --silent --fail "${BASE_URL}/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl --silent --fail "${BASE_URL}/" >/dev/null 2>&1; then
  echo "Archbee preview did not become ready at ${BASE_URL}" >&2
  tail -n 200 "${LOG_FILE}" >&2 || true
  exit 1
fi

wget \
  --mirror \
  --convert-links \
  --adjust-extension \
  --page-requisites \
  --no-host-directories \
  --directory-prefix "${OUTPUT_DIR}" \
  --execute robots=off \
  "${BASE_URL}/"

if [[ ! -f "${OUTPUT_DIR}/index.html" ]]; then
  echo "Static export did not produce ${OUTPUT_DIR}/index.html" >&2
  find "${OUTPUT_DIR}" -maxdepth 3 -type f | sort >&2 || true
  exit 1
fi

echo "Static preview exported to ${OUTPUT_DIR}"
