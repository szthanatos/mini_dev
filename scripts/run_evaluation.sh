#!/usr/bin/env bash
# ==============================================================================
#  Run evaluation scripts to compare generated SQL with ground truth.
#  All configurations can be overridden by environment variables.
#
#  Usage:
#    ./run_evaluation.sh [EVAL_MODE]
#
#  Variables:
#    EVAL_MODE:   which evaluation to run, 0 for all evaluation, 1|2|3 for EX|R-VES|Soft F1-Score
#                 split with commas to run multi evaluation
# ==============================================================================
set -euo pipefail

# --- Configuration ---
SQL_DIALECT="${SQL_DIALECT:-SQLite}"             # Options: 'SQLite' | 'PostgreSQL' | 'MySQL'
DSN="${DSN:-mysql://root:123456@localhost:3306/BIRD}" # DSN for MySQL/PostgreSQL, only used if dialect is not SQLite
# Path to the JSON file with predicted SQL queries.
PREDICTED_SQL_PATH="${PREDICTED_SQL_PATH:-exp_result/predict_mini_dev_deepseek-chat_cot_SQLite.json}"
# Path for evaluation output log. It derives from the prediction file name.
OUTPUT_LOG_PATH="${OUTPUT_LOG_PATH:-eval_result/$(basename "${PREDICTED_SQL_PATH}" .json).log}"

DATA_PATH="${DATA_PATH:-data/minidev/MINIDEV}"     # Main data path
DB_ROOT_PATH="${DB_ROOT_PATH:-${DATA_PATH}/dev_databases/}" # Path to SQLite DBs folder
NUM_CPUS="${NUM_CPUS:-3}"                          # Number of CPUs for evaluation
META_TIME_OUT="${META_TIME_OUT:-30.0}"             # Max seconds for SQL execution
EXEC_CMD="${EXEC_CMD:-uv run}"                     # Python execution command (e.g., 'uv run', 'conda run -n myenv')

# --- Script Paths (Internal) ---
EVAL_SCRIPTS_DIR="evaluation"
EX_SCRIPT="${EVAL_SCRIPTS_DIR}/evaluation_ex.py"
R_VES_SCRIPT="${EVAL_SCRIPTS_DIR}/evaluation_ves.py"
F1_SCRIPT="${EVAL_SCRIPTS_DIR}/evaluation_f1.py"

# --- Helper Functions ---
log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

run_evaluation() {
  local eval_name="$1"
  local python_script="$2"
  local diff_json_path="$3"
  local ground_truth_path="$4"

  log "Running evaluation: ${eval_name}"
  ${EXEC_CMD} python -u "${python_script}" \
    --predicted_sql_path "${PREDICTED_SQL_PATH}" \
    --ground_truth_path "${ground_truth_path}" \
    --db_root_path "${DB_ROOT_PATH}" \
    --num_cpus "${NUM_CPUS}" \
    --meta_time_out "${META_TIME_OUT}" \
    --diff_json_path "${diff_json_path}" \
    --output_log_path "${OUTPUT_LOG_PATH}" \
    --sql_dialect "${SQL_DIALECT}" \
    --dsn "${DSN}"
}

main() {
  local eval_mode="${1:-all}"

  # Derive dialect-specific paths automatically.
  local dialect_lower
  dialect_lower=$(echo "${SQL_DIALECT}" | tr '[:upper:]' '[:lower:]') # e.g., 'SQLite' -> 'sqlite'
  local diff_json_path="${DATA_PATH}/mini_dev_${dialect_lower}.json"
  local ground_truth_path="${DATA_PATH}/mini_dev_${dialect_lower}_gold.sql"

  [[ -f "${PREDICTED_SQL_PATH}" ]] || error "Predicted SQL file not found: ${PREDICTED_SQL_PATH}"
  [[ -f "${diff_json_path}" ]] || error "Differential JSON file not found: ${diff_json_path}"
  [[ -f "${ground_truth_path}" ]] || error "Ground truth SQL file not found: ${ground_truth_path}"

  mkdir -p "$(dirname "${OUTPUT_LOG_PATH}")"

  log "Starting evaluation with the following configuration:"
  cat <<-EOF
  - SQL Dialect:          ${SQL_DIALECT}
  - Predicted SQL File:   ${PREDICTED_SQL_PATH}
  - Ground Truth File:    ${ground_truth_path}
  - Output Log:           ${OUTPUT_LOG_PATH}
  - CPUs:                 ${NUM_CPUS}
  - Timeout:              ${META_TIME_OUT}s
EOF

  read -p "Configuration looks correct? Press Enter to start in 5 seconds or Ctrl+C to cancel..." -t 5 || true
  echo

  # If mode is 'all' or '0', expand it to run all evaluations.
  if [[ "$eval_mode" == "all" || "$eval_mode" == "0" || -z "$eval_mode" ]]; then
    eval_mode="ex,ves,f1"
  fi

  log "Selected evaluation modes: ${eval_mode}"

  # Replace commas with spaces and iterate through the selected modes.
  for mode in ${eval_mode//,/ }; do
    case "$mode" in
    "1" | "ex")
      run_evaluation "EX" "${EX_SCRIPT}" "${diff_json_path}" "${ground_truth_path}"
      ;;
    "2" | "ves")
      run_evaluation "R-VES" "${R_VES_SCRIPT}" "${diff_json_path}" "${ground_truth_path}"
      ;;
    "3" | "f1")
      run_evaluation "Soft F1-Score" "${F1_SCRIPT}" "${diff_json_path}" "${ground_truth_path}"
      ;;
    *)
      if [[ -n "$mode" ]]; then
          log "Warning: Invalid evaluation mode '${mode}' will be skipped."
      fi
      ;;
    esac
  done

  log "Evaluation finished. Results are in ${OUTPUT_LOG_PATH}"
}

main "$@"
