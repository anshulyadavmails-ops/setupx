#!/usr/bin/env bash
set -euo pipefail

brew_installed() {
  command -v brew >/dev/null 2>&1
}

install_homebrew() {
  if brew_installed; then
    log_info 'Homebrew is already installed.'
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_error 'curl is required to install Homebrew.'
    return 1
  fi

  log_info 'Installing Homebrew (live output follows)...'
  if ! run_cmd_live '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
    log_error 'Homebrew installation failed.'
    return 1
  fi
  log_info 'Homebrew installed successfully.'
}

configure_brew_path() {
  local brew_bin=''
  if command -v brew >/dev/null 2>&1; then
    brew_bin="$(dirname "$(command -v brew)")"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin='/opt/homebrew/bin'
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin='/usr/local/bin'
  fi

  if [[ -z "$brew_bin" ]]; then
    return 1
  fi

  export PATH="$brew_bin:$PATH"
  ensure_env_entry PATH "$brew_bin:\$PATH"
}

update_brew() {
  log_info 'Updating Homebrew...'
  if ! run_cmd 'brew update'; then
    log_error 'Homebrew update failed.'
    return 1
  fi
}

ensure_brew() {
  if ! brew_installed; then
    install_homebrew
  fi
  configure_brew_path
  update_brew
}
