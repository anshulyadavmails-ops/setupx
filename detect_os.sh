#!/usr/bin/env bash

# detect_os.sh
# Detect the current operating system and print a normalized name.
# On macOS, check Homebrew and update it if installed, or install it if missing.
# Record the run details in dat.json.

set -euo pipefail

log_error() {
  printf 'ERROR: %s\n' "$1" >&2
}

log_info() {
  printf '%s\n' "$1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="${SCRIPT_DIR}/dat.json"
PYTHON="$(command -v python3 || command -v python || true)"

TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
os_name="unknown"
package_manager="unknown"
homebrew_installed=false
homebrew_action="none"
homebrew_status="none"
error_message=""
commands_json='[]'

json_escape() {
  local s="$1"
  s=${s//\/\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

append_command() {
  local cmd="$1" status="$2" output="$3"
  local esc_cmd esc_status esc_output
  esc_cmd="$(json_escape "$cmd")"
  esc_status="$(json_escape "$status")"
  esc_output="$(json_escape "$output")"

  if [[ "$commands_json" == '[]' ]]; then
    commands_json="[{\"cmd\":\"$esc_cmd\",\"status\":\"$esc_status\",\"output\":\"$esc_output\"}]"
  else
    local prefix="${commands_json%]}"
    commands_json="${prefix}, {\"cmd\":\"$esc_cmd\",\"status\":\"$esc_status\",\"output\":\"$esc_output\"}]"
  fi
}

save_log() {
  local exit_code="${1:-$?}"
  local error_field="null"
  if [[ -n "$error_message" ]]; then
    error_field="\"$(json_escape "$error_message")\""
  fi

  local record="{\"timestamp\":\"$(json_escape "$TIMESTAMP")\",\"os_name\":\"$(json_escape "$os_name")\",\"homebrew_installed\":$( [[ "$homebrew_installed" == true ]] && printf 'true' || printf 'false' ),\"homebrew_action\":\"$(json_escape "$homebrew_action")\",\"homebrew_status\":\"$(json_escape "$homebrew_status")\",\"error_message\":$error_field,\"exit_code\":$exit_code,\"commands\":$commands_json}"

  if [[ -n "$PYTHON" ]]; then
    "$PYTHON" - "$DATA_FILE" "$record" <<PY
import json, os, sys
file_path = sys.argv[1]
record = json.loads(sys.argv[2])
if os.path.exists(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if not isinstance(data, list):
                data = []
    except Exception:
        data = []
else:
    data = []
data.append(record)
with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
PY
"$record"
  else
    if [[ ! -f "$DATA_FILE" ]]; then
      printf '[\n  %s\n]\n' "$record" > "$DATA_FILE"
    else
      local current
      current="$(awk 'BEGIN{RS=""}{sub(/[[:space:]]+$/,"");print}' "$DATA_FILE")"
      if [[ "$current" == '[]' ]]; then
        printf '[\n  %s\n]\n' "$record" > "$DATA_FILE"
      else
        current="${current%]}"
        printf '%s,\n  %s\n]\n' "$current" "$record" > "$DATA_FILE"
      fi
    fi
  fi
}

trap 'save_log "$?"' EXIT

run_cmd() {
  local cmd="$1"
  local output
  if output=$(bash -lc -- "$cmd" 2>&1); then
    append_command "$cmd" "success" "$output"
    return 0
  fi
  append_command "$cmd" "failure" "$output"
  return 1
}

case "$(uname -s)" in
  Linux)
    os_name="linux"
    ;;
  Darwin)
    os_name="macos"
    ;;
  FreeBSD)
    os_name="freebsd"
    ;;
  OpenBSD)
    os_name="openbsd"
    ;;
  NetBSD)
    os_name="netbsd"
    ;;
  SunOS)
    os_name="solaris"
    ;;
  CYGWIN*|MINGW*|MSYS*)
    os_name="windows"
    ;;
  *)
    os_name="unknown"
    ;;
esac

if [[ "$os_name" == "windows" ]]; then
  log_info 'Detected Windows. Checking installed package managers...'
  if command -v winget >/dev/null 2>&1; then
    package_manager="winget"
  elif command -v scoop >/dev/null 2>&1; then
    package_manager="scoop"
  elif command -v choco >/dev/null 2>&1; then
    package_manager="choco"
  else
    package_manager="unknown"
  fi
  log_info "Package manager: $package_manager"
fi

if [[ "$os_name" == "macos" ]]; then
  log_info 'Detected macOS. Checking Homebrew...'

  if run_cmd 'command -v brew >/dev/null 2>&1'; then
    homebrew_installed=true
    homebrew_action="update"
    log_info 'Homebrew is installed. Updating Homebrew...'
    if ! run_cmd 'brew update'; then
      homebrew_status="failure"
      log_error 'Homebrew update failed. Please check your network and Homebrew installation.'
      exit 1
    fi
    homebrew_status="success"
    log_info 'Homebrew update completed successfully.'
  else
    homebrew_installed=false
    homebrew_action="install"
    log_info 'Homebrew is not installed. Installing Homebrew...'

    if ! run_cmd 'command -v curl >/dev/null 2>&1'; then
      homebrew_status="failure"
      log_error 'curl is required to install Homebrew but is not available.'
      exit 1
    fi

    if ! run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
      homebrew_status="failure"
      log_error 'Homebrew installation failed. Please inspect the output above and try again.'
      exit 1
    fi
    homebrew_status="success"
    log_info 'Homebrew installed successfully.'
  fi
fi

printf '%s\n' "$os_name"
