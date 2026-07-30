#!/usr/bin/env bash
set -euo pipefail

launch_menu() {
  while true; do
    echo "Dev Setup Menu"
    echo "1) Show OS and package manager"
    echo "2) List categories"
    echo "3) Install category"
    echo "4) Install all categories"
    echo "5) Update category"
    echo "6) Update all categories"
    echo "7) Doctor category"
    echo "8) Checklist (installed / missing)"
    echo "9) List installed tools"
    echo "10) List missing tools"
    echo "11) Exit"
    printf 'Choose an option: '
    read -r choice

    case "$choice" in
      1)
        show_system_info
        ;;
      2)
        list_categories
        ;;
      3)
        printf 'Category: '
        read -r category
        install_category "$category"
        ;;
      4)
        run_install_all
        ;;
      5)
        printf 'Category: '
        read -r category
        update_category "$category"
        ;;
      6)
        run_update_all
        ;;
      7)
        printf 'Category: '
        read -r category
        doctor_category "$category"
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
        exit 0
        ;;
      *)
        log_warn 'Unknown choice.'
        ;;
    esac
    echo
  done
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
