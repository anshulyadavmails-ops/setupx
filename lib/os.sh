#!/usr/bin/env bash
set -euo pipefail

detect_os() {
  case "$(uname -s)" in
    Linux)
      printf 'linux'
      ;;
    Darwin)
      printf 'macos'
      ;;
    FreeBSD)
      printf 'freebsd'
      ;;
    OpenBSD)
      printf 'openbsd'
      ;;
    NetBSD)
      printf 'netbsd'
      ;;
    SunOS)
      printf 'solaris'
      ;;
    CYGWIN*|MINGW*|MSYS*)
      printf 'windows'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

is_macos() {
  [[ "$(detect_os)" == "macos" ]]
}

is_windows() {
  [[ "$(detect_os)" == "windows" ]]
}

detect_package_manager() {
  local os_type
  os_type="$(detect_os)"
  case "$os_type" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        printf 'brew'
      else
        printf 'none'
      fi
      ;;
    linux)
      if command -v apt >/dev/null 2>&1; then
        printf 'apt'
      elif command -v dnf >/dev/null 2>&1; then
        printf 'dnf'
      elif command -v pacman >/dev/null 2>&1; then
        printf 'pacman'
      elif command -v zypper >/dev/null 2>&1; then
        printf 'zypper'
      else
        printf 'unknown'
      fi
      ;;
    freebsd)
      printf 'pkg'
      ;;
    windows)
      if command -v winget >/dev/null 2>&1; then
        printf 'winget'
      elif command -v scoop >/dev/null 2>&1; then
        printf 'scoop'
      elif command -v choco >/dev/null 2>&1; then
        printf 'choco'
      else
        printf 'unknown'
      fi
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

ensure_package_manager() {
  local pm
  pm="$(detect_package_manager)"
  if [[ "$pm" == "brew" ]]; then
    ensure_brew
  elif [[ "$pm" == "winget" || "$pm" == "scoop" || "$pm" == "choco" ]]; then
    log_info "Detected Windows package manager: $pm"
  elif [[ "$pm" == "unknown" ]]; then
    log_warn 'Unable to detect a supported package manager for this OS.'
  fi
}
