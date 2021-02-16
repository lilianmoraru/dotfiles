#! /usr/bin/env bash

set -euo pipefail

dotfiles_dir="${HOME:?}/.dotfiles"

error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_and_install_requirements() {
  local -r package_dependencies=(git stow)

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

setup_cli() {
  stow zsh
  stow git
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
}

main "$@"
echo "Setup finished!"