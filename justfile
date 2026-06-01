
#
set shell := ["bash", "-c"]

## Vars
################################################################################

root := justfile_directory()

nest_dir := root / ".nest"
build_dir := nest_dir / "build"

projects := `for d in projects/*/; do if [ -f "$d/CMakeLists.txt" ]; then basename "$d"; fi; done`
tests := `for f in tests/*.cpp; do f=$(basename "$f" .cpp); echo "$f"; done`
presets := `cmake --list-presets 2>/dev/null | awk -F'"' '/^[[:space:]]+"/ {print $2}'`

fresh_flag := if path_exists(build_dir) == "true" { "" } else { "--fresh" }

parallel := `nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4`
preset := "debug"

generator := "Ninja"

#
## Privates
################################################################################

[private]
default:
    @echo
    @echo "Available projects:"
    @echo "{{ projects }}" | while read -r p; do if [ -n "$p" ]; then echo "    $p"; fi; done
    @echo
    @echo "Available tests:"
    @echo "{{ tests }}" | while read -r t; do if [ -n "$t" ]; then echo "    $t"; fi; done
    @echo
    @echo "Available presets:"
    @echo "{{ presets }}"  | while read -r p; do if [ -n "$p" ]; then echo "    $p"; fi; done
    @echo
    @just -l -u

[private]
config:
    @cmake -E make_directory "{{ build_dir }}"
    cmake --preset {{ preset }} -G "{{ generator }}" {{ fresh_flag }}
    @echo
    @cmake -E copy_if_different "{{ build_dir }}/compile_commands.json" "{{ root }}/compile_commands.json"

#
## Manage
################################################################################

# Scaffolds a new exe
add_exe name:
    @cmake -DNEST_DO_SCAFFOLD=ON -DTARGET_NAME="{{ name }}" -DTARGET_TYPE="EXE" -P cmake/nest.cmake

# Scaffolds a new lib (type = SHARED / STATIC)
add_lib name type="SHARED":
    @cmake -DNEST_DO_SCAFFOLD=ON -DTARGET_NAME="{{ name }}" -DTARGET_TYPE="{{ type }}" -P cmake/nest.cmake

#
## Build
################################################################################

# targets = all / <project_name> ...
[no-exit-message]
build *targets: config
    @if [ -z "{{ targets }}" -o "{{ targets }}" = "all" ]; then \
        cmake --build "{{ build_dir }}" -j {{ parallel }}; \
    else \
        cmake --build "{{ build_dir }}" -j {{ parallel }} --target {{ targets }}; \
    fi

# target = all / <project_name>
[no-exit-message]
run target *args: (build target)
    @echo
    @"{{ root }}/cmake/nest-run.sh" "{{ target }}" "{{ preset }}" {{ args }}

# tests = all / test_name(s) — space-separated runs multiple, empty runs all
test *tests:
    @echo
    @echo "🧪 Building & running tests..."
    @just build "{{ tests }}"
    @r=""; [ -n "{{ tests }}" ] && r="^($(echo {{ tests }} | tr ' ' '|'))$"; \
    ctest --test-dir "{{ build_dir }}" \
        --output-on-failure --parallel 8 -C {{ preset }} \
        $( [ -n "$r" ] && echo "-R" "$r" ) \
        | grep -v "^    Start"

#
## Cleanup
################################################################################

# target = all / projects  (wipe 'all' or 'projects only')
clean target="all":
    @just _clean_{{ target }}

[private]
_clean_projects:
    @rm -rf "{{ build_dir }}"/*

[private]
_clean_all:
    @rm -rf "{{ nest_dir }}"
    @rm -f "{{ root }}/compile_commands.json"
