#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
DATA_FILE="$SCRIPT_DIR/data.json"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"

source "$LIB_DIR/utils.sh"
source "$LIB_DIR/os.sh"
source "$LIB_DIR/env.sh"
source "$LIB_DIR/brew.sh"
source "$LIB_DIR/installer.sh"
source "$LIB_DIR/updater.sh"
source "$LIB_DIR/doctor.sh"
source "$LIB_DIR/menu.sh"

main_help() {
  cat <<'EOF'
Usage: ./main.sh <command> [category] [tool]

Commands:
  help                     Show this help text
  menu                     Launch the interactive setup menu
  sysinfo                  Show OS and package manager info
  list                     List all configured categories
  list-tools <category>    List tools in a category
  install <category>       Install all tools in a category
  install-all              Install every category in data.json
  install-tool <cat> <tool> Install a specific tool
  n <package>              Install a tool by package or name (choco-like)
  update <category>        Update all tools in a category
  update-all               Update every category in data.json
  doctor <category>        Run doctor checks for a category
  checklist                Show installed/missing checklist
  list-installed           Show installed tools
  list-missing             Show missing tools
  show-category <category> Show category details
EOF
}

show_system_info() {
  local os pm
  os="$(detect_os)"
  pm="$(detect_package_manager)"

  log_info "OS: $os"
  log_info "Package manager: $pm"

  if [[ "$os" == "macos" && "$pm" == "none" ]]; then
    log_warn 'Homebrew is not installed. Install it manually or run install after enabling sudo.'
  fi

  if [[ "$pm" == "unknown" ]]; then
    log_warn 'Unable to detect a supported package manager for this OS.'
  fi
}

prepare_system() {
  show_system_info
  if ! ensure_package_manager; then
    log_error 'Package manager setup failed. The software menu cannot continue.'
    return 1
  fi

  log_info "Package manager ready: $(detect_package_manager)"
  show_system_info
}

run_install_all() {
  install_all_categories
}

run_install_by_name() {
  install_tool_by_name "$1"
}

run_update_all() {
  update_all_categories
}

show_checklist() {
  launch_checklist
}

assert_data_file() {
  if [[ ! -f "$DATA_FILE" ]]; then
    log_error "Missing $DATA_FILE. Create or restore the JSON manifest first."
    exit 1
  fi
}

show_category() {
  assert_data_file
  if ! category_exists "$1"; then
    log_error "Category '$1' is not defined in data.json"
    exit 1
  fi
  print_category_summary "$1"
}

main() {
  assert_data_file
  if [[ $# -lt 1 ]]; then
    if ! prepare_system; then
      log_warn 'Opening the menu without a ready package manager.'
    fi
    launch_menu
    return
  fi

  case "$1" in
    help|-h|--help)
      main_help
      ;;
    menu)
      launch_menu
      ;;
    sysinfo)
      show_system_info
      ;;
    list)
      list_categories
      ;;
    list-tools)
      shift
      list_tools_in_category "$1"
      ;;
    install)
      shift
      install_category "$1"
      ;;
    install-all)
      run_install_all
      ;;
    install-tool)
      shift
      install_tool "$1" "$2"
      ;;
    n)
      shift
      if [[ $# -lt 1 ]]; then
        log_error 'Missing package name for n command.'
        main_help
        exit 1
      fi
      run_install_by_name "$1"
      ;;
    update)
      shift
      update_category "$1"
      ;;
    update-all)
      run_update_all
      ;;
    doctor)
      shift
      doctor_category "$1"
      ;;
    checklist)
      show_checklist
      ;;
    list-installed)
      list_installed
      ;;
    list-missing)
      list_missing
      ;;
    show-category)
      shift
      show_category "$1"
      ;;
    *)
      log_error "Unknown command: $1"
      main_help
      exit 1
      ;;
  esac
}

main "$@"
