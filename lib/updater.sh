#!/usr/bin/env bash
set -euo pipefail

update_category() {
  local category="$1"
  if ! category_exists "$category"; then
    log_error "Category '$category' does not exist."
    return 1
  fi

  log_info "Updating category: $category"
  local tools
  tools="$(get_tools_list "$category")"
  local tool
  while IFS= read -r tool; do
    if [[ -z "$tool" ]]; then
      continue
    fi
    update_tool "$category" "$tool"
  done <<<"$tools"
}

update_all_categories() {
  log_info 'Updating all categories.'
  local categories
  categories="$(get_all_categories)"
  local category
  while IFS= read -r category; do
    if [[ -z "$category" ]]; then
      continue
    fi
    update_category "$category"
  done <<<"$categories"
}

update_tool() {
  local category="$1"
  local tool_name="$2"

  if ! tool_exists "$category" "$tool_name"; then
    log_error "Tool '$tool_name' not found in category '$category'."
    return 1
  fi

  local update_cmd
  update_cmd="$(get_tool_attribute "$category" "$tool_name" "update" 2>/dev/null || true)"
  if [[ -z "$update_cmd" ]]; then
    log_warn "No update command defined for $tool_name"
    return 0
  fi

  log_info "Updating $tool_name..."
  if ! run_cmd "$update_cmd"; then
    log_warn "Update failed for $tool_name"
    doctor_tool "$category" "$tool_name"
    return 1
  fi
  return 0
}
