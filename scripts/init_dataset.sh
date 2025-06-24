#!/usr/bin/env bash
# ==============================================================================
#  Downloads and unzips the Bird-Bench minidev dataset.
#  All configurations can be overridden by environment variables.
# ==============================================================================
set -euo pipefail

# --- Configuration ---
# No need to change anything by default.
PRIMARY_URL="${PRIMARY_URL:-https://bird-bench.oss-cn-beijing.aliyuncs.com/minidev.zip}"
SECONDARY_URL="${SECONDARY_URL:-https://drive.google.com/file/d/1UJyA6I6pTmmhYpwdn8iT9QKrcJqSQAcX/view?usp=sharing}"
MINIDEV_ZIP="${MINIDEV_ZIP:-llm/mini_dev_data/minidev.zip}"
DATA_DIR="${DATA_DIR:-data}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

main() {
  mkdir -p "$(dirname "${MINIDEV_ZIP}")"

  if [ ! -f "${MINIDEV_ZIP}" ]; then
    log "File ${MINIDEV_ZIP} not found. Attempting to download..."
    if ! curl -sSL -o "${MINIDEV_ZIP}" --connect-timeout "${CONNECT_TIMEOUT}" "${PRIMARY_URL}"; then
      log "Primary URL failed. Trying secondary URL..."
      if ! curl -sSL -o "${MINIDEV_ZIP}" --connect-timeout "${CONNECT_TIMEOUT}" "${SECONDARY_URL}"; then
        error "Failed to download dataset from all sources. Please check your network connection."
      fi
    fi
    log "Download successful."
  else
    log "Dataset ${MINIDEV_ZIP} already exists. Skipping download."
  fi

  log "Unzipping dataset to ${DATA_DIR}..."
  mkdir -p "${DATA_DIR}"
  unzip -q -o "${MINIDEV_ZIP}" -d "${DATA_DIR}"

  log "Everything is ready."
}

main "$@"
