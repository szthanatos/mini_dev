#!/usr/bin/env bash
# ==============================================================================
#  Run Large Language Model to generate SQL queries based on questions.
#  All configurations can be overridden by environment variables.
# ==============================================================================
set -euo pipefail

# --- Configuration ---
# API and Model Config
PROVIDER="${PROVIDER:-openai}"                             # Options: 'azure' | 'openai'
BASE_URL="${BASE_URL:-https://api.deepseek.com}"           # LLM service endpoint
API_KEY="${API_KEY:-}"                                     # Your API key (leave empty if not needed)
API_VERSION="${API_VERSION:-2024-02-01}"                   # API version (mainly for Azure)
MODEL="${MODEL:-deepseek-chat}"                            # LLM model name

# Data and Path Config
SQL_DIALECT="${SQL_DIALECT:-SQLite}"                       # Options: 'SQLite' | 'PostgreSQL' | 'MySQL'
# Input questions file. The name is derived from SQL_DIALECT.
EVAL_PATH="${EVAL_PATH:-data/minidev/MINIDEV/mini_dev_${SQL_DIALECT,,}.json}"
DB_ROOT_PATH="${DB_ROOT_PATH:-data/minidev/MINIDEV/dev_databases/}" # Path to SQLite DBs folder
# Output directory for generated SQL files.
DATA_OUTPUT_PATH="${DATA_OUTPUT_PATH:-exp_result/}"

# Execution Config
MODE="${MODE:-mini_dev}"                                   # Options: 'dev' | 'train' | 'mini_dev'
NUM_THREADS="${NUM_THREADS:-6}"                            # Number of parallel threads
USE_KNOWLEDGE="${USE_KNOWLEDGE:-True}"                     # Whether to use knowledge from the dataset
COT="${COT:-True}"                                         # Whether to use Chain-of-Thought prompting
EXEC_CMD="${EXEC_CMD:-uv run}"                             # Python execution command (e.g., 'uv run', 'conda run -n myenv')

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

main() {
  mkdir -p "${DATA_OUTPUT_PATH}"

  log "Starting SQL generation with the following configuration:"
  cat <<-EOF
  - LLM Provider:         ${PROVIDER}
  - Model:                ${MODEL}
  - SQL Dialect:          ${SQL_DIALECT}
  - Evaluation File:      ${EVAL_PATH}
  - Output Path:          ${DATA_OUTPUT_PATH}
  - Threads:              ${NUM_THREADS}
  - Use Knowledge:        ${USE_KNOWLEDGE}
  - Chain of Thought:     ${COT}
EOF

  read -p "Configuration looks correct? Press Enter to start in 5 seconds or Ctrl+C to cancel..." -t 5 || true
  echo

  log "Executing python script to generate SQL..."
  ${EXEC_CMD} python -u llm/src/gpt_request.py \
    --provider "${PROVIDER}" \
    --base_url "${BASE_URL}" \
    --api_key "${API_KEY}" \
    --api_version "${API_VERSION}" \
    --model "${MODEL}" \
    --eval_path "${EVAL_PATH}" \
    --db_root_path "${DB_ROOT_PATH}" \
    --data_output_path "${DATA_OUTPUT_PATH}" \
    --mode "${MODE}" \
    --sql_dialect "${SQL_DIALECT}" \
    --num_threads "${NUM_THREADS}" \
    --use_knowledge "${USE_KNOWLEDGE}" \
    --chain_of_thought "${COT}"

  log "SQL generation script finished."
}

main "$@"
