#! /usr/bin/env bash

set -euo pipefail

dotfiles_dir="${HOME:?}/.dotfiles"

error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_and_install_requirements() {
  local -r package_dependencies=(
    git stow zsh zsh-common zsh-doc python fonts-hack-ttf
    cmake pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev python3
    dkms libsecret-1-0 libsecret-1-dev libssl-dev
  )

  local dependencies_to_install=()
  for dependency in "${package_dependencies[@]}"; do
    if ! dpkg -l "${dependency}" | cut -d ' ' -f1 | grep "ii" >& /dev/null; then
      # shellcheck disable=SC2206
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing dependencies:"
    # shellcheck disable=SC2068
    sudo apt install ${dependencies_to_install[@]} -yqq # intentional word splitting
  fi

  if [ ! -d "${dotfiles_dir}/.git" ]; then
    git clone https://github.com/lilianmoraru/dotfiles.git "${dotfiles_dir}"
    (
      cd "${dotfiles_dir}"
      git remote set-url origin git@github.com:lilianmoraru/dotfiles.git
    )
  fi
}

setup_env() {
  stow scripts
}

setup_cli() {
  stow zsh
  stow git
  chsh -s $(which zsh)
  # setup autojump
  # setup antigen
  # setup alacritty
  # sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50
  # rust setup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  # setup libsecret
}

setup() {
  (
    cd "${dotfiles_dir}"
    eval "setup_${1:?}"
  )
}

main() {
  check_and_install_requirements
  setup cli
  setup env
}

main "$@"
echo "Setup finished!"
