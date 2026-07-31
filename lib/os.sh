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
      if command -v choco >/dev/null 2>&1; then
        printf 'choco'
      elif command -v scoop >/dev/null 2>&1; then
        printf 'scoop'
      elif command -v winget >/dev/null 2>&1; then
        printf 'winget'
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
  case "$pm" in
    brew)
      ensure_brew
      ;;
    choco|scoop|winget)
      update_windows_package_manager "$pm"
      ;;
    unknown|none)
      case "$(detect_os)" in
        macos)
          ensure_brew
          ;;
        windows)
          install_windows_package_manager
          ;;
        *)
          log_warn 'Unable to detect a supported package manager for this OS.'
          return 1
          ;;
      esac
      ;;
    *)
      log_warn "Package manager '$pm' is detected but setup is not implemented."
      return 1
      ;;
  esac
}

install_windows_package_manager() {
  local powershell='powershell.exe'
  if ! command -v "$powershell" >/dev/null 2>&1; then
    powershell='powershell'
  fi
  if ! command -v "$powershell" >/dev/null 2>&1; then
    log_error 'PowerShell is required to install a Windows package manager.'
    return 1
  fi

  log_info 'No Windows package manager found. Installing Scoop...'
  if ! run_cmd "$powershell -NoProfile -ExecutionPolicy Bypass -Command \"irm get.scoop.sh | iex\""; then
    log_warn 'Scoop installation failed. Trying Chocolatey...'
    if ! run_cmd "$powershell -NoProfile -ExecutionPolicy Bypass -Command \"Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))\""; then
      log_error 'Unable to install Scoop or Chocolatey.'
      return 1
    fi
  fi

  local pm
  pm="$(detect_package_manager)"
  if [[ "$pm" == 'unknown' ]]; then
    log_error 'Windows package manager installation completed but no manager is on PATH.'
    return 1
  fi
  update_windows_package_manager "$pm"
}

update_windows_package_manager() {
  local pm="$1"
  log_info "Updating package manager: $pm"
  case "$pm" in
    choco)
      run_cmd 'choco upgrade chocolatey -y'
      ;;
    scoop)
      run_cmd 'scoop update'
      ;;
    winget)
      run_cmd 'winget source update'
      ;;
    *)
      log_error "Unsupported Windows package manager: $pm"
      return 1
      ;;
  esac
}
