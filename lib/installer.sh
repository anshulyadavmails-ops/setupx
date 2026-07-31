#!/usr/bin/env bash
set -euo pipefail

install_category() {
  local category="$1"
  if ! category_exists "$category"; then
    log_error "Category '$category' does not exist."
    return 1
  fi

  log_info "Installing category: $category"
  ensure_package_manager

  local tools
  tools="$(get_tools_list "$category")"
  local tool
  while IFS= read -r tool; do
    if [[ -z "$tool" ]]; then
      continue
    fi
    log_info "Installing tool: $tool"
    if ! install_tool "$category" "$tool"; then
      log_warn "Continuing after failed install for $tool"
    fi
  done <<<"$tools"
}

install_all_categories() {
  log_info 'Installing all categories.'
  local categories
  categories="$(get_all_categories)"
  local category
  while IFS= read -r category; do
    if [[ -z "$category" ]]; then
      continue
    fi
    if ! install_category "$category"; then
      log_warn "Continuing after failed category install for $category"
    fi
  done <<<"$categories"
}

install_tool() {
  local category="$1"
  local tool_name="$2"

  if ! tool_exists "$category" "$tool_name"; then
    log_error "Tool '$tool_name' not found in category '$category'."
    return 1
  fi

  local install_cmd
  install_cmd="$(get_tool_attribute "$category" "$tool_name" "install" 2>/dev/null || true)"
  if [[ -z "$install_cmd" ]]; then
    log_error "No install command defined for $tool_name"
    return 1
  fi

  log_info "Installing $tool_name..."
  if ! run_cmd "$install_cmd"; then
    log_warn "Install failed for $tool_name, attempting doctor checks..."
    doctor_tool "$category" "$tool_name"
    log_info "Retrying install for $tool_name..."
    if ! run_cmd "$install_cmd"; then
      log_error "Installation failed again for $tool_name"
      return 1
    fi
  fi

  configure_environment_for_tool "$category" "$tool_name"
  return 0
}

install_tool_by_name() {
  local tool_name="$1"
  local result category tool

  if ! result="$(find_tool_by_name "$tool_name" 2>/dev/null)"; then
    log_error "Tool or package '$tool_name' not found in data.json"
    return 1
  fi

  IFS=$'\t' read -r category tool <<< "$result"
  install_tool "$category" "$tool"
}

get_tools_list() {
  ensure_python
  local category="$1"
  "$PYTHON" - "$DATA_FILE" "$category" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
items = data.get(sys.argv[2], {}).get('tools', [])
for tool in items:
    print(tool.get('name'))
PY
}
