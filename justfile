
################################################################################
### Vars
################################################################################

repo_root    := `git rev-parse --show-toplevel 2>/dev/null || pwd`
compiler_cpp := `which clang++`
compiler_c   := `which clang`

subprojects := `for d in */; do [ -f "$d/CMakeLists.txt" ] && echo "${d%/}"; done | xargs`

build_dir    := "build"
subbuild_dir := build_dir / "subbuild"

build_type := "Release"


################################################################################
### Privates
################################################################################

[private]
config flags="":
    @mkdir -p {{subbuild_dir}}
    cmake -S . -G "Ninja" -B {{subbuild_dir}} {{flags}} \
      -DCMAKE_CXX_COMPILER="{{compiler_cpp}}" \
      -DCMAKE_C_COMPILER="{{compiler_c}}" \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -DCMAKE_COMPILE_WARNING_AS_ERROR=ON
    @echo ""
    ln -sf {{repo_root}}/{{subbuild_dir}}/compile_commands.json {{repo_root}}/compile_commands.json


################################################################################
### Interface
################################################################################

default: build

help:
    @just --list

list:
    @echo "Available subprojects: {{subprojects}}"
    @just --list


################################################################################
### Build
################################################################################

build name="all": config
    cmake --build {{subbuild_dir}} -j 24 --target {{name}}

run project="app" *args:
    ./{{build_dir}}/bin/{{project}}/{{project}} {{args}}

# test: build
# cd {{build_dir}} && ctest --output-on-failure


################################################################################
### Cleanup
################################################################################
  
fresh:
    rm -rf {{subbuild_dir}}/*
    just config "--fresh"
    just build

clean:
    rm -rf {{build_dir}}
    rm -f {{repo_root}}/compile_commands.json
    just config
    just build
