#!/usr/bin/env bash
set -euo pipefail

PYTHON="$(command -v python3 || command -v python || true)"

log_info() {
  printf '%s\n' "$1"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s INFO: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
  fi
}

log_warn() {
  printf 'WARNING: %s\n' "$1"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s WARNING: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
  fi
}

log_error() {
  printf 'ERROR: %s\n' "$1" >&2
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s ERROR: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
  fi
}

run_cmd() {
  local cmd="$1"
  local output
  local exit_code=0
  output=$(bash -lc "$cmd" 2>&1) || exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    log_info "OK: $cmd"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
    fi
    return 0
  fi
  log_warn "FAILED: $cmd"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
  fi
  return $exit_code
}

run_cmd_live() {
  local cmd="$1"
  local output_file
  local output
  local exit_code

  output_file="$(mktemp "${TMPDIR:-/tmp}/setupx-output.XXXXXX")"
  log_info "Running: $cmd"
  set +e
  bash -lc "$cmd" 2>&1 | tee "$output_file"
  exit_code="${PIPESTATUS[0]}"
  set -e
  output="$(<"$output_file")"
  rm -f "$output_file"

  if [[ $exit_code -eq 0 ]]; then
    log_info "OK: $cmd"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
    fi
    return 0
  fi

  log_warn "FAILED: $cmd"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
  fi
  return "$exit_code"
}

run_cmd_with_timer() {
  local cmd="$1"
  local label="${2:-Installing}"
  local output_file
  local output
  local exit_code
  local start_time
  local elapsed
  local pid
  local progress_width=24
  local filled=0
  local empty=24
  local bar=''
  local i

  output_file="$(mktemp "${TMPDIR:-/tmp}/setupx-output.XXXXXX")"
  start_time="$(date +%s)"
  log_info "Starting: $cmd"

  set +e
  bash -lc "$cmd" >"$output_file" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    elapsed=$(( $(date +%s) - start_time ))
    filled=$(( elapsed % (progress_width + 1) ))
    if (( filled > progress_width )); then
      filled=$progress_width
    fi
    empty=$(( progress_width - filled ))
    bar=''
    for ((i=0; i<filled; i++)); do bar+='#'; done
    for ((i=0; i<empty; i++)); do bar+='.'; done
    printf '\r\033[K[%s] %s (%ss elapsed)...' "$bar" "$label" "$elapsed"
  done
  wait "$pid"
  exit_code=$?
  set -e

  printf '\n'
  output="$(<"$output_file")"
  rm -f "$output_file"

  if [[ $exit_code -eq 0 ]]; then
    log_info "OK: $cmd"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
    fi
    return 0
  fi

  log_warn "FAILED: $cmd"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$cmd" "$output" >>"$LOG_FILE"
  fi
  return "$exit_code"
}

run_cmd_as_admin() {
  local cmd="$1"
  if [[ "$(uname -s)" == "Darwin" && -x "$(command -v osascript 2>/dev/null)" ]]; then
    local temp_script
    temp_script="$(mktemp /tmp/setupx-admin-XXXXXX.sh)"
    local quoted_cmd
    quoted_cmd=$(printf '%q' "$cmd")

    cat >"$temp_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH"
exec /bin/bash -lc $quoted_cmd
EOF
    chmod +x "$temp_script"

    local output
    if output=$(osascript -e "do shell script \"/bin/bash '$temp_script'\" with administrator privileges" 2>&1); then
      log_info "OK (admin): $cmd"
      if [[ -n "${LOG_FILE:-}" ]]; then
        printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "sudo: $cmd" "$output" >>"$LOG_FILE"
      fi
      rm -f "$temp_script"
      return 0
    fi
    local exit_code=$?
    log_warn "FAILED (admin): $cmd"
    if [[ -n "${LOG_FILE:-}" ]]; then
      printf '%s COMMAND: %s\nOUTPUT: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "sudo: $cmd" "$output" >>"$LOG_FILE"
    fi
    rm -f "$temp_script"
    return $exit_code
  fi
  run_cmd "$cmd"
}

ensure_python() {
  if [[ -z "$PYTHON" ]]; then
    log_error 'Python is required to parse data.json. Install python3 to continue.'
    exit 1
  fi
}

list_categories() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for category in data.get('categories', []):
    print(category)
PY
}

list_tools_in_category() {
  ensure_python
  local category="$1"
  if ! category_exists "$category"; then
    log_error "Category '$category' not found"
    return 1
  fi
  "$PYTHON" - "$DATA_FILE" "$category" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
for tool in data.get(category, {}).get('tools', []):
    print(tool.get('name'))
PY
}

category_exists() {
  ensure_python
  local category="$1"
  "$PYTHON" - "$DATA_FILE" "$category" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
if category in data.get('categories', []):
    sys.exit(0)
sys.exit(1)
PY
}

tool_exists() {
  ensure_python
  local category="$1"
  local tool_name="$2"
  "$PYTHON" - "$DATA_FILE" "$category" "$tool_name" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
tool_name = sys.argv[3]
for tool in data.get(category, {}).get('tools', []):
    if tool.get('name') == tool_name or tool.get('package') == tool_name:
        sys.exit(0)
sys.exit(1)
PY
}

get_tool_attribute() {
  ensure_python
  local category="$1"
  local tool_name="$2"
  local attribute="$3"
  "$PYTHON" - "$DATA_FILE" "$category" "$tool_name" "$attribute" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
tool_name = sys.argv[3]
attribute = sys.argv[4]
for tool in data.get(category, {}).get('tools', []):
    if tool.get('name') == tool_name or tool.get('package') == tool_name:
        value = tool.get(attribute, '')
        if isinstance(value, (list, dict)):
            print(json.dumps(value))
        elif value is not None:
            print(value)
        sys.exit(0)
sys.exit(1)
PY
}

find_tool_by_name() {
  ensure_python
  local tool_name="$1"
  "$PYTHON" - "$DATA_FILE" "$tool_name" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
search = sys.argv[2]
for category in data.get('categories', []):
    for tool in data.get(category, {}).get('tools', []):
        if tool.get('name') == search or tool.get('package') == search:
            print(f"{category}\t{tool.get('name')}")
            sys.exit(0)
sys.exit(1)
PY
}

print_category_summary() {
  ensure_python
  local category="$1"
  "$PYTHON" - "$DATA_FILE" "$category" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
category_data = data.get(category, {})
print(f"Category: {category}")
print(f"Description: {category_data.get('description', '')}")
print('Tools:')
for tool in category_data.get('tools', []):
    print(f"  - {tool.get('name')} ({tool.get('type', 'unknown')})")
PY
}

get_all_categories() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for category in data.get('categories', []):
    print(category)
PY
}

# Prompt the user for a yes/no answer.
# Usage: prompt_yes_no "Question text" [default]
# - default: 'n' (treat Enter as no) or 'y'
# Accepts 's' or 'S' as affirmative (maps to yes).
prompt_yes_no() {
  local prompt_text="${1:-Proceed?}"
  local default="${2:-n}"

  # Clear current line to remove any old input text
  printf '\r\033[K'

  local default_display
  if [[ "$default" == "y" ]]; then
    default_display='Y/n'
  else
    default_display='y/N'
  fi

  printf '%s [%s] ' "$prompt_text" "$default_display"
  local ans
  if ! read -r ans; then
    # treat EOF as default
    ans="$default"
  fi

  if [[ -z "$ans" ]]; then
    ans="$default"
  fi

  # normalize to lowercase (portable)
  ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"

  # Accept 's' as 'y' (e.g., Spanish sí)
  if [[ "$ans" == "s" ]]; then
    ans="y"
  fi

  if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
    return 0
  fi
  return 1
}
