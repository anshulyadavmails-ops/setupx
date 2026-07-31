#!/usr/bin/env bash
set -euo pipefail

launch_menu() {
  clear
  local os pm
  os="$(detect_os)"
  pm="$(detect_package_manager)"
  if [[ "$pm" == "brew" ]]; then
    pm="Homebrew"
  fi

  cat <<EOF
███████╗███████╗████████╗██╗   ██╗██████╗ ██╗  ██╗
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗╚██╗██╔╝
███████╗█████╗     ██║   ██║   ██║██████╔╝ ╚███╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝  ██╔██╗
███████║███████╗   ██║   ╚██████╔╝██║     ██╔╝ ██╗
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝

        Cross-Platform Development Environment Setup

──────────────────────────────────────────────────────────────
 Platform         : $os
 Package Manager  : $pm
──────────────────────────────────────────────────────────────

  1.  System Information          7.  Run Doctor
  2.  List Categories             8.  Installation Checklist
  3.  Install Category            9.  Installed Tools
  4.  Install All Categories     10.  Missing Tools
  5.  Update Category            11.  Install Tool by Name
  6.  Update All Categories      12.  Exit

──────────────────────────────────────────────────────────────

Select an option [1-12]: 
EOF
  while true; do
    read -r choice
    read -r choice

    case "$choice" in
      1)
        show_system_info
        ;;
      2)
        list_categories_numbered
        ;;
      3)
        if category="$(select_category)"; then
          install_category "$category"
        fi
        ;;
      4)
        run_install_all
        ;;
      5)
        if category="$(select_category)"; then
          update_category "$category"
        fi
        ;;
      6)
        run_update_all
        ;;
      7)
        if category="$(select_category)"; then
          doctor_category "$category"
        fi
        ;;
      8)
        launch_checklist
        ;;
      9)
        list_installed
        ;;
      10)
        list_missing
        ;;
      11)
        install_tool_by_name_menu
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
