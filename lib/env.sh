#!/usr/bin/env bash
set -euo pipefail

detect_shell() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    bash|zsh|fish)
      printf '%s' "$shell_name"
      ;;
    *)
      printf 'sh'
      ;;
  esac
}

shell_rc_file() {
  local shell_name
  shell_name="$(detect_shell)"
  case "$shell_name" in
    bash)
      printf '%s' "$HOME/.bashrc"
      ;;
    zsh)
      printf '%s' "$HOME/.zshrc"
      ;;
    fish)
      printf '%s' "$HOME/.config/fish/config.fish"
      ;;
    *)
      printf '%s' "$HOME/.profile"
      ;;
  esac
}

ensure_env_entry() {
  local key="$1"
  local value="$2"
  local rc_file
  rc_file="$(shell_rc_file)"
  local export_line="export $key=\"$value\""

  if [[ ! -f "$rc_file" ]]; then
    touch "$rc_file"
  fi
  if ! grep -Fxq "$export_line" "$rc_file"; then
    printf '%s\n' "$export_line" >>"$rc_file"
    log_info "Appended environment variable to $rc_file"
  else
    log_info "$key is already configured in $rc_file"
  fi
}

configure_environment_for_tool() {
  local category="$1"
  local tool_name="$2"
  local env_json
  env_json="$(get_tool_attribute "$category" "$tool_name" "env" 2>/dev/null || true)"
  if [[ -z "$env_json" ]]; then
    return 0
  fi

  if [[ "$env_json" == "]" ]] || [[ "$env_json" == "null" ]]; then
    return 0
  fi

  local line
  while IFS= read -r line; do
    local key
    local value
    key="$(echo "$line" | awk -F'\t' '{print $1}')"
    value="$(echo "$line" | awk -F'\t' '{print $2}')"
    ensure_env_entry "$key" "$value"
  done < <(printf '%s' "$env_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); import os; [print(f"{item["key"]}\t{item["value"]}") for item in data]')
}
