#!/usr/bin/env bash

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"

build_dir="build"
subbuild_dir="${build_dir}/subbuild"

compiler_cpp="$(which 'clang++')"
compiler_c="$(which 'clang')"

cmake_extra_flags=""

error_exit() {
  echo "[ERR] @ ${1:-}"
  exit 1
}

cmd="${1:-}"

if [[ "${cmd}" == "--help" || "${cmd}" == "-h" ]]; then
  echo "Usage: $(basename "${BASH_SOURCE[-1]}") [options]"
  echo ""
  echo "Options:"
  echo "  --fresh     Fresh compile projects, not deps."
  echo "  --clean     Fresh compile projects AND deps."
  echo "  -h, --help  Shows this message"
  echo ""
fi
if [[ "${cmd}" == "--fresh" ]]; then
  rm -rf ${subbuild_dir}/*
  cmake_extra_flags="--fresh"
fi
if [[ "${cmd}" == "--clean" ]]; then
  rm -rf ${build_dir}/*
fi

mkdir -p "${subbuild_dir}"

cmake -S . -G "Ninja" -B "${subbuild_dir}" ${cmake_extra_flags} \
  -DCMAKE_CXX_COMPILER="${compiler_cpp}" \
  -DCMAKE_C_COMPILER="${compiler_c}" \
|| error_exit "CMake-Config stage"

cmake --build "${subbuild_dir}" -j 16

ln -sf "${subbuild_dir}/compile_commands.json" "${repo_root}/compile_commands.json"
