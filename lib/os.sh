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

get_os_display_name() {
  case "$(detect_os)" in
    macos)
      printf 'macOS'
      ;;
    linux)
      printf 'Linux'
      ;;
    windows)
      printf 'Windows'
      ;;
    freebsd)
      printf 'FreeBSD'
      ;;
    openbsd)
      printf 'OpenBSD'
      ;;
    netbsd)
      printf 'NetBSD'
      ;;
    solaris)
      printf 'Solaris'
      ;;
    *)
      printf 'Unknown'
      ;;
  esac
}

get_os_version() {
  case "$(detect_os)" in
    macos)
      if command -v sw_vers >/dev/null 2>&1; then
        sw_vers -productVersion 2>/dev/null || uname -r
      else
        uname -r
      fi
      ;;
    linux)
      if [[ -f /etc/os-release ]]; then
        (
          source /etc/os-release 2>/dev/null || true
          printf '%s\n' "${VERSION_ID:-${PRETTY_NAME:-}}"
        )
      else
        uname -r
      fi
      ;;
    windows)
      if command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c ver 2>/dev/null | head -n 1 | tr -d '\r' || true
      fi
      uname -r
      ;;
    *)
      uname -r
      ;;
  esac
}

get_device_info() {
  local model arch
  arch="$(uname -m)"
  case "$(detect_os)" in
    macos)
      if command -v system_profiler >/dev/null 2>&1; then
        model="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/ {print $2; exit}' || true)"
      fi
      if [[ -n "$model" ]]; then
        printf '%s (%s)' "$model" "$arch"
      else
        printf '%s' "$arch"
      fi
      ;;
    linux)
      if command -v hostnamectl >/dev/null 2>&1; then
        model="$(hostnamectl 2>/dev/null | awk -F': ' '/Machine/ {print $2; exit}' || true)"
      fi
      if [[ -n "$model" ]]; then
        printf '%s (%s)' "$model" "$arch"
      else
        printf '%s' "$arch"
      fi
      ;;
    windows)
      printf '%s' "$arch"
      ;;
    *)
      printf '%s' "$arch"
      ;;
  esac
}

get_package_manager_display_name() {
  case "$1" in
    brew)
      printf 'Homebrew'
      ;;
    apt)
      printf 'APT'
      ;;
    dnf)
      printf 'DNF'
      ;;
    pacman)
      printf 'Pacman'
      ;;
    zypper)
      printf 'Zypper'
      ;;
    choco)
      printf 'Chocolatey'
      ;;
    scoop)
      printf 'Scoop'
      ;;
    winget)
      printf 'Winget'
      ;;
    pkg)
      printf 'pkg'
      ;;
    none)
      printf 'None'
      ;;
    *)
      printf '%s' "$1"
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
