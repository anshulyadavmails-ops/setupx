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

  log_info 'Installing Homebrew...'
  if ! run_cmd_as_admin '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'; then
    log_error 'Homebrew installation failed.'
    return 1
  fi
  log_info 'Homebrew installed successfully.'
}

ensure_brew() {
  if ! brew_installed; then
    install_homebrew
  fi
}
