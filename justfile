
#! Vars

repo_root    := `git rev-parse --show-toplevel 2>/dev/null || pwd`
compiler_cpp := `which clang++`
compiler_c   := `which clang`

subprojects := `for d in */; do if [ -f "$d/CMakeLists.txt" ]; then echo "${d%/}"; fi; done`

build_dir    := "build"
subbuild_dir := build_dir / "subbuild"

fresh_flag := if path_exists(subbuild_dir) == "true" { "" } else { "--fresh" }

build_type := "Release"
asan       := "OFF"
werror     := "OFF"

#! Privates

[private]
default:
    @echo
    @echo "Available subprojects:"
    @printf '%s\n' "{{subprojects}}" | while IFS= read -r p; do \
        if echo "$p" | grep -q " "; then \
            echo -e "    '$p'  \e[93m⚠️ Rename to '${p// /_}'\e[0m"; \
        else \
            echo "    $p"; \
        fi \
    done
    @echo
    @just -l -u

[private]
config flags="":
    @mkdir -p {{subbuild_dir}}
    cmake -S . -G "Ninja" -B {{subbuild_dir}} {{flags}} {{fresh_flag}} \
        -DCMAKE_CXX_COMPILER="{{compiler_cpp}}" \
        -DCMAKE_C_COMPILER="{{compiler_c}}" \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCM_ENABLE_ASAN={{asan}} \
        -DCM_WARNINGS_AS_ERRORS={{werror}}
    @echo
    ln -sf {{repo_root}}/{{subbuild_dir}}/compile_commands.json {{repo_root}}/compile_commands.json

[private]
[no-exit-message]
validate target:
    @if echo "{{target}}" | grep -q " "; then \
        echo "🔴 Target '{{target}}' contains spaces, cannot be built."; \
        exit 1; \
    fi

#! Build

# target = all / <project_name>
build target="all": (validate target) config
    cmake --build {{subbuild_dir}} -j 24 --target "{{target}}"

# target = all / <project_name>
run target *args: (build target)
    ./{{build_dir}}/bin/{{target}}/{{target}} {{args}}

#! Cleanup

# target = all / src  (wipe 'all' or 'projects only')
clean target="all":
    just _clean_{{target}}

_clean_projects:
    rm -rf {{subbuild_dir}}/*

_clean_all:
    rm -rf {{build_dir}}
    rm -f {{repo_root}}/compile_commands.json
