#! /usr/bin/env bash

set -euo pipefail

dotfiles_dir="${HOME:?}/.dotfiles"

error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_and_install_requirements() {
  local -r package_dependencies=(
    git build-essential stow zsh zsh-common zsh-doc python3 fonts-hack-ttf
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
  # Install Rustup
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  # Install Rust tools
  RUSTFLAGS="-C target-cpu=native" cargo install fd-find rg difftastic

  #stow git

  stow --adopt zsh
  chsh -s $(which zsh)
  echo "Default shell changed to ZSH - you need to Log Out or Restart to apply this change"

  # Create the "git" dir - most dependencies go in here
  mkdir -p "${HOME:?}/git"
  (
    cd "${HOME:?}/git"

    # setup autojump:
    (
      git clone https://github.com/wting/autojump.git && cd autojump
      ./install.py
    )

    # setup antigen:
    curl -L git.io/antigen > "${HOME:?}/git/antigen.zsh"
  ) # "${HOME:?}/git"

  #
  # setup alacritty:
  # sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50

  # setup libsecret:
  cd /usr/share/doc/git/contrib/credential/libsecret
  sudo make
  git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret

  # build ninja-build:
  (
    local -r temp_dir_path="$(mktemp -d)"
    cd "${temp_dir_path}"
    git clone https://github.com/ninja-build/ninja.git && cd ninja
    cmake -Bbuild -H. \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_FLAGS="-O3 -mtune=native -march=native -m64 -mavx -fomit-frame-pointer"
    cmake --build build --parallel
    sudo cmake --build build --target install
    sudo rm -rf "${temp_dir_path:?}"
  )
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
