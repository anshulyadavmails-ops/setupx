#!/usr/bin/env bash
set -euo pipefail

doctor_category() {
  local category="$1"
  if ! category_exists "$category"; then
    log_error "Category '$category' does not exist."
    return 1
  fi

  log_info "Running doctor checks for category: $category"
  local tools
  tools="$(get_tools_list "$category")"
  local tool
  while IFS= read -r tool; do
    if [[ -z "$tool" ]]; then
      continue
    fi
    doctor_tool "$category" "$tool"
  done <<<"$tools"
}

doctor_tool() {
  local category="$1"
  local tool_name="$2"

  if ! tool_exists "$category" "$tool_name"; then
    log_error "Tool '$tool_name' not found in category '$category'."
    return 1
  fi

  local doctor_cmds
  doctor_cmds="$(get_tool_attribute "$category" "$tool_name" "doctor" 2>/dev/null || true)"
  if [[ -z "$doctor_cmds" ]] || [[ "$doctor_cmds" == "null" ]]; then
    log_warn "No doctor commands defined for $tool_name"
    return 0
  fi

  local commands
  commands=$(printf '%s' "$doctor_cmds" | python3 -c 'import json,sys; obj=json.load(sys.stdin); print("\n".join(obj) if isinstance(obj, list) else obj)')
  local cmd
  while IFS= read -r cmd; do
    if [[ -z "$cmd" ]]; then
      continue
    fi
    log_info "Running doctor step: $cmd"
    run_cmd "$cmd"
  done <<<"$commands"
}
