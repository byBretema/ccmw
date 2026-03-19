
#
## Vars
################################################################################

root         := justfile_directory()

nest_dir     := root / ".nest"
build_dir    := nest_dir / "build"

subprojects  := `for d in */; do if [ -f "$d/CMakeLists.txt" ]; then echo "${d%/}"; fi; done`

fresh_flag   := if path_exists(build_dir) == "true" { "" } else { "--fresh" }

parallel     := "24"
preset       := "debug"

compiler_cpp := `which clang++`
compiler_c   := `which clang`
generator    := "Ninja"


#
## Privates
################################################################################

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
    @cmake -E make_directory "{{build_dir}}"
    cmake {{fresh_flag}} --preset {{preset}} -G "{{generator}}"
    @echo
    -cmake -E copy_if_different "{{build_dir}}/compile_commands.json" "{{root}}/compile_commands.json"

[private]
[no-exit-message]
validate target:
    @if echo "{{target}}" | grep -q " "; then \
        echo "🔴 Target '{{target}}' contains spaces, cannot be built."; \
        exit 1; \
    fi

#
## Build
################################################################################

# target = all / <project_name>
build target="all": (validate target) config
    cmake --build "{{build_dir}}" -j {{parallel}} --target "{{target}}"

# target = all / <project_name>
run target *args: (build target)
    "{{nest_dir}}/bin/{{target}}/{{target}}" {{args}}

# target = all / <project_name>
test target="all" *args: (build target)
    @echo "🧪 Running tests..."
    cmake -E chdir "{{build_dir}}" \
        ctest --output-on-failure --parallel 8 -C {{preset}} {{args}}


#
## Cleanup
################################################################################

# target = all / projects  (wipe 'all' or 'projects only')
clean target="all":
    just _clean_{{target}}

[private]
_clean_projects:
    rm -rf "{{build_dir}}"/*

[private]
_clean_all:
    rm -rf "{{nest_dir}}"
    rm -f "{{root}}/compile_commands.json"
