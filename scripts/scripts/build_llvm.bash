#! /usr/bin/env bash

set -euo pipefail

# General vars
jobs="$(echo $(( $(nproc) * 3/4 )) | cut -d '.' -f1)"
git_dir="${HOME:?}/git"
install_prefix_root="${HOME:?}/.tools"

# LLVM vars
llvm_source_dir="${git_dir}/llvm"
llvm_build_dir="${git_dir}/llvm-build"
llvm_branch="${LLVM_BRANCH:-release/13.x}"
first_stage_install_prefix="${install_prefix_root:?}/llvm-stage1"
install_prefix="${install_prefix_root:?}/llvm"

# Include What You Use vars
iwyu_source_dir="${git_dir:?}/iwyu"
iwyu_branch="${IWYU_BRANCH:-clang_12}"

error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_llvm_executable() {
  local -r binary_path="${1:?}"
  if [ ! -x "$(readlink -m "${binary_path}")" ]; then
    error "\"${binary_path}\" is not an executable"
  fi

  if ! "${binary_path}" --version >& /dev/null; then
    error "Cannot run \"${binary_path}\" - invalid output binary"
  fi
}

check_requirements() {
  local -r build_dependencies=(
    git git-lfs gcc g++ build-essential cmake ninja-build
    libpython3-dev libxml2-dev liblzma-dev libedit-dev python3-sphinx swig
  )
  local dependencies_to_install=()
  for dependency in "${build_dependencies[@]}"; do
    if ! dpkg -l "${dependency}" | cut -d ' ' -f1 | grep "ii" >& /dev/null; then
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing LLVM build dependencies:"
    sudo apt install ${dependencies_to_install[@]} -yqq # intentional word splitting
  fi

  if [ ! -d "${git_dir:?}" ]; then
    mkdir -p "${git_dir}" || error "Could not create the git dir: ${git_dir}"
  fi

  if [ ! -d "${llvm_source_dir:?}/.git" ]; then
    git clone https://github.com/llvm/llvm-project.git "${llvm_source_dir}" -b "${llvm_branch:?}" || error "Failed to clone LLVM"
  fi

  if [ ! -d "${install_prefix_root:?}" ]; then
    mkdir -p "${install_prefix_root}" || error "Could not create the install root dir: ${install_prefix_root}"
  fi

  local -r git_dir_expected_space=$(( 15 * 1024 )) # 15GB
  local -r install_dir_expected_space=$(( 4 * 1024 )) # 4GB

  local git_dir_available_space_bytes
  git_dir_available_space_bytes=$(df --output=avail "${git_dir:?}" | tail -1)
  local -r git_dir_available_space=$(( git_dir_available_space_bytes / 1024 ))

  local install_dir_available_space_bytes
  install_dir_available_space_bytes=$(df --output=avail "${install_prefix_root:?}" | tail -1)
  local -r install_dir_available_space=$(( install_dir_available_space_bytes / 1024 ))

  not_enough_space_error() {
    error "Not enough disk space inside \"${1:?}\" dir: ${2:?}MB. Required at least: ${3:?}MB"
  }

  # If it is the same partition, we need to sum up the expected space
  if [ "$(df --output=source "${git_dir:?}" | tail -1)" = "$(df --output=source "${install_prefix_root:?}" | tail -1)" ]; then
    local -r expected_space=$(( git_dir_expected_space + install_dir_expected_space ))
    if [ "${git_dir_available_space}" -lt "${expected_space}" ]; then
      not_enough_space_error "${git_dir}" ${git_dir_available_space} ${expected_space}
    fi
  else
    if [ "${git_dir_available_space}" -lt "${git_dir_expected_space}" ]; then
      not_enough_space_error "${git_dir}" ${git_dir_available_space} ${git_dir_expected_space}
    fi

    if [ "${install_dir_available_space}" -lt "${install_dir_expected_space}" ]; then
      not_enough_space_error "${install_prefix_root}" ${install_dir_available_space} ${install_dir_expected_space}
    fi
  fi
}

update_project() {
  local -r dir="${1:?}"
  local -r branch="${2:?}"
  (
    cd "${dir}" || error "Failed to change dir to: ${dir}"
    git fetch origin "${branch}"
    git clean -fdx
    git reset --hard origin/"${branch}"
  )
}

install_llvm() {
  mkdir -p "${llvm_build_dir:?}" || error "Failed to create the build dir: ${llvm_build_dir}"
  cd "${llvm_build_dir}" || error "Failed to change dir to: ${llvm_build_dir}"

  rm -rf ./*
  if [ -n "${LLVM_FIRST_RUN}" ]; then
    cmake "${llvm_source_dir:?}/llvm" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS:STRING="clang;lld" \
      -DCMAKE_C_COMPILER=/usr/bin/gcc \
      -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
      -DCMAKE_RANLIB=/usr/bin/ranlib \
      -DCMAKE_AR=/usr/bin/ar \
      -DLLVM_TARGETS_TO_BUILD:STRING=Native \
      -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_BUILD_EXAMPLES=OFF \
      -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3 \
      -DCMAKE_INSTALL_PREFIX="${first_stage_install_prefix:?}" \
      -G Ninja
  else
    cmake "${llvm_source_dir:?}/llvm" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS:STRING="clang;clang-tools-extra;compiler-rt;lld;lldb" \
      -DCMAKE_C_COMPILER="${first_stage_install_prefix:?}/bin/clang" \
      -DCMAKE_CXX_COMPILER="${first_stage_install_prefix:?}/bin/clang++" \
      -DCMAKE_RANLIB="${first_stage_install_prefix:?}/bin/llvm-ranlib" \
      -DCMAKE_AR="${first_stage_install_prefix:?}/bin/llvm-ar" \
      -DCMAKE_CXX_FLAGS="-O3 -mtune=native -march=native -m64 -mavx -fomit-frame-pointer" \
      -DCMAKE_C_FLAGS="-O3 -mtune=native -march=native -m64 -mavx -fomit-frame-pointer" \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1" \
      -DCMAKE_MODULE_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1" \
      -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1" \
      -DLLVM_TARGETS_TO_BUILD:STRING=Native \
      -DENABLE_LINKER_BUILD_ID=ON \
      -DLLVM_BUILD_LLVM_DYLIB=ON \
      -DLLVM_ENABLE_LLD=ON \
      -DLLVM_ENABLE_PIC=ON \
      -DLLVM_ENABLE_RTTI=ON \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_BUILD_EXAMPLES=OFF \
      -DPYTHON_EXECUTABLE:FILEPATH=/usr/bin/python3 \
      -DCMAKE_INSTALL_PREFIX="${install_prefix:?}" \
      -C "${llvm_source_dir}/clang/cmake/caches/PGO.cmake" \
      -G Ninja

    ninja -j${jobs} stage2
  fi

  ninja -j${jobs} install && rm -rf "${llvm_build_dir:?}"

  if [ -n "${LLVM_FIRST_RUN}" ]; then
    check_llvm_executable "${first_stage_install_prefix:?}/bin/clang"
    check_llvm_executable "${first_stage_install_prefix:?}/bin/clang++"
  else
    check_llvm_executable "${install_prefix:?}/bin/clang"
    check_llvm_executable "${install_prefix:?}/bin/clang++"

    rm -rf "${first_stage_install_prefix:?}"
  fi
}

build_iwyu() {
  test ! -d "${iwyu_source_dir:?}/.git" && git clone https://github.com/include-what-you-use/include-what-you-use.git "${iwyu_source_dir:?}"
  update_project "${iwyu_source_dir:?}" "${iwyu_branch:?}"

  test -d "${iwyu_source_dir:?}/build" && rm -rf "${iwyu_source_dir:?}/build"
  mkdir -p "${iwyu_source_dir:?}/build"
  (
    cd "${iwyu_source_dir:?}/build"
    cmake "${iwyu_source_dir:?}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="${install_prefix:?}" \
      -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
      -DCMAKE_C_COMPILER="${install_prefix:?}/bin/clang" \
      -DCMAKE_CXX_COMPILER="${install_prefix:?}/bin/clang++" \
      -DCMAKE_C_FLAGS="-fPIC -fuse-ld=lld" \
      -DCMAKE_CXX_FLAGS="-fPIC -fuse-ld=lld" \
      -G Ninja

    ninja -j${jobs} install && rm -rf "${iwyu_source_dir:?}/build"
    check_llvm_executable "${install_prefix:?}/bin/include-what-you-use"
  )
}

build_llvm() {
  (
    install_llvm
  )
}

main() {
  check_requirements
  update_project "${llvm_source_dir:?}" "${llvm_branch:?}"
  LLVM_FIRST_RUN=1  build_llvm "$@"
  LLVM_FIRST_RUN='' build_llvm "$@"
  build_iwyu

  echo
  echo "Finished building:"
  "${install_prefix:?}/bin/clang++" --version
}

main "$@"
