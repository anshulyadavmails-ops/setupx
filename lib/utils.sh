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
  output=$(bash -lc "$cmd" 2>&1)
  local exit_code=$?
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
