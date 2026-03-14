
#! Vars

# repo_root    := `git rev-parse --show-toplevel 2>/dev/null || pwd`
root         := justfile_directory()
compiler_cpp := `which clang++`
compiler_c   := `which clang`

subprojects := `for d in */; do if [ -f "$d/CMakeLists.txt" ]; then echo "${d%/}"; fi; done`

build_dir    := root / "build"
subbuild_dir := build_dir / "subbuild"

fresh_flag := if path_exists(subbuild_dir) == "true" { "" } else { "--fresh" }

parallel := "24"
preset := "dev"
generator := "Ninja"

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
config:
    @cmake -E make_directory "{{subbuild_dir}}"
    cmake --preset {{preset}} -G {{generator}}
    @echo
    cmake -E copy_if_different "{{subbuild_dir}}/compile_commands.json" "{{root}}/compile_commands.json"

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
    cmake --build {{subbuild_dir}} -j {{parallel}} --target "{{target}}"

# target = all / <project_name>
run target *args: (build target)
    ./{{build_dir}}/bin/{{target}}/{{target}} {{args}}

# target = all / <project_name>
[working-directory("{{subbuild}}")]
test target *args: (build target)
    # cmake -E chdir {{subbuild_dir}}
    ctest --output-on-failure --parallel 8 -C {{preset}}

#! Cleanup

# target = all / src  (wipe 'all' or 'projects only')
clean target="all":
    just _clean_{{target}}

_clean_projects:
    rm -rf {{subbuild_dir}}/*

_clean_all:
    rm -rf {{build_dir}}
    rm -f {{root}}/compile_commands.json
