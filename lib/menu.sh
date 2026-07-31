#!/usr/bin/env bash
set -euo pipefail

launch_menu() {
  clear
  local os_name os_version device pm pm_display
  os_name="$(get_os_display_name)"
  os_version="$(get_os_version)"
  device="$(get_device_info)"
  pm="$(detect_package_manager)"
  pm_display="$(get_package_manager_display_name "$pm")"

  cat <<EOF
███████╗███████╗████████╗██╗   ██╗██████╗ ██╗  ██╗
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗╚██╗██╔╝
███████╗█████╗     ██║   ██║   ██║██████╔╝ ╚███╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝  ██╔██╗
███████║███████╗   ██║   ╚██████╔╝██║     ██╔╝ ██╗
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝

        SetupX Development Environment

──────────────────────────────────────────────────────────────
 OS               : $os_name
 OS Version       : $os_version
 Device           : $device
 Package Manager  : $pm_display
──────────────────────────────────────────────────────────────

  1.  System Information         7.  Run Doctor
  2.  List Categories           8.  Install from List
  3.  List All Apps             9.  Installed Tools
  4.  Install Tool by Name     10.  Missing Tools
  5.  Install by Category      11.  Update Category
  6.  Install by Selection     12.  Exit

──────────────────────────────────────────────────────────────
EOF
  while true; do
    printf 'Select an option [1-12]: '
    if ! IFS= read -r choice; then
      break
    fi

    case "$choice" in
      1)
        show_system_info
        ;;
      2)
        list_categories_numbered
        ;;
      3)
        list_all_apps_numbered
        ;;
      4)
        install_tool_by_name_menu
        ;;
      5)
        if category="$(select_category)"; then
          install_category "$category"
        fi
        ;;
      6)
        install_selected_tool_menu
        ;;
      7)
        install_from_list_menu
        ;;
      8)
        if category="$(select_category)"; then
          doctor_category "$category"
        fi
        ;;
      9)
        list_installed
        ;;
      10)
        list_missing
        ;;
      11)
        if category="$(select_category)"; then
          update_category "$category"
        fi
        ;;
      12)
        exit 0
        ;;
      *)
        log_warn 'Unknown choice.'
        ;;
    esac
    echo
  done
}

install_tool_by_name_menu() {
  printf 'Enter tool or package name: '
  read -r tool_name
  if [[ -z "${tool_name// /}" ]]; then
    log_warn 'No tool name provided.'
    return 1
  fi
  install_tool_by_name "$tool_name"
  show_system_info
}

install_selected_tool_menu() {
  if ! category="$(select_category)"; then
    return 1
  fi

  ensure_python
  printf 'Select a tool:\n' >&2
  "$PYTHON" - "$DATA_FILE" "$category" <<'PY' >&2
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
for index, tool in enumerate(data.get(category, {}).get('tools', []), start=1):
    print(f"{index}) {tool.get('name')}")
PY
  printf 'Tool number: ' >&2
  read -r tool_number

  tool_name="$($PYTHON - "$DATA_FILE" "$category" "$tool_number" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
category = sys.argv[2]
try:
    index = int(sys.argv[3]) - 1
except ValueError:
    sys.exit(1)
tools = data.get(category, {}).get('tools', [])
if index < 0 or index >= len(tools):
    sys.exit(1)
print(tools[index].get('name'))
PY
  )" || {
    log_error 'Invalid tool number.'
    return 1
  }

  install_tool "$category" "$tool_name"
}

install_from_list_menu() {
  ensure_python
  printf 'Select a tool from the full list:\n' >&2
  list_all_apps_numbered >&2
  printf 'Tool number: ' >&2
  read -r tool_number

  selected="$($PYTHON - "$DATA_FILE" "$tool_number" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
try:
    index = int(sys.argv[2]) - 1
except ValueError:
    sys.exit(1)
count = 0
for category in data.get('categories', []):
    for tool in data.get(category, {}).get('tools', []):
        if count == index:
            print(f"{category}\t{tool.get('name')}")
            sys.exit(0)
        count += 1
sys.exit(1)
PY
  )" || {
    log_error 'Invalid tool number.'
    return 1
  }

  IFS=$'\t' read -r category tool_name <<< "$selected"
  install_tool "$category" "$tool_name"
}

list_categories_numbered() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for index, category in enumerate(data.get('categories', []), start=1):
    print(f"{index}) {category}")
PY
}

list_all_apps_numbered() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
index = 1
for category in data.get('categories', []):
    for tool in data.get(category, {}).get('tools', []):
        print(f"{index}) {category}: {tool.get('name')}")
        index += 1
PY
}

select_category() {
  ensure_python
  printf 'Select a category:\n' >&2
  list_categories_numbered >&2
  printf 'Category number: ' >&2
  read -r category_number
  category="$($PYTHON - "$DATA_FILE" "$category_number" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
try:
    index = int(sys.argv[2]) - 1
except ValueError:
    sys.exit(1)
categories = data.get('categories', [])
if index < 0 or index >= len(categories):
    sys.exit(1)
print(categories[index])
PY
  )" || {
    log_error 'Invalid category number.'
    return 1
  }
  printf '%s\n' "$category"
}

list_installed() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys, subprocess
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for category in data.get('categories', []):
    for tool in data.get(category, {}).get('tools', []):
        check = tool.get('check')
        if not check:
            continue
        result = subprocess.run(check, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode == 0:
            print(f"{category}: {tool.get('name')} (installed)")
PY
}

list_missing() {
  ensure_python
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys, subprocess
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for category in data.get('categories', []):
    for tool in data.get(category, {}).get('tools', []):
        check = tool.get('check')
        if not check:
            continue
        result = subprocess.run(check, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(f"{category}: {tool.get('name')} (missing)")
PY
}

launch_checklist() {
  ensure_python
  echo "Checklist:"
  "$PYTHON" - "$DATA_FILE" <<'PY'
import json, sys, subprocess
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for category in data.get('categories', []):
    print(f"\nCategory: {category}")
    for tool in data.get(category, {}).get('tools', []):
        name = tool.get('name')
        check = tool.get('check')
        if not check:
            print(f"  [ ] {name} (no check configured)")
            continue
        result = subprocess.run(check, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        status = 'x' if result.returncode == 0 else ' '
        print(f"  [{status}] {name}")
PY
}
