
#
## Vars
################################################################################

root := justfile_directory()

nest_dir := root / ".nest"
build_dir := nest_dir / "build"

projects := `for d in projects/*/; do if [ -f "$d/CMakeLists.txt" ]; then basename "$d"; fi; done`
presets := `cmake --list-presets 2>/dev/null | awk -F'"' '/^[[:space:]]+"/ {print $2}'`

fresh_flag := if path_exists(build_dir) == "true" { "" } else { "--fresh" }

parallel := "24"
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
    @echo "Available presets:"
    @echo "{{ presets }}"  | while read -r p; do if [ -n "$p" ]; then echo "    $p"; fi; done
    @echo
    @just -l -u

[private]
config:
    @cmake -E make_directory "{{ build_dir }}"
    cmake {{ fresh_flag }} --preset {{ preset }} -G "{{ generator }}"
    @echo
    -cmake -E copy_if_different "{{ build_dir }}/compile_commands.json" "{{ root }}/compile_commands.json"

[no-exit-message]
[private]
validate target:
    @if echo "{{ target }}" | grep -q " "; then \
        echo "🔴 Target '{{ target }}' contains spaces, cannot be built."; \
        exit 1; \
    fi

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

# target = all / <project_name>
[no-exit-message]
build target="all": (validate target) config
    cmake --build "{{ build_dir }}" -j {{ parallel }} --target "{{ target }}"

# target = all / <project_name>
run target *args: (build target)
    @echo
    @"{{ root }}/cmake/nest-run.sh" "{{ target }}" "{{ preset }}" {{ args }}

# target = all / <project_name>
test target="all" *args: (build target)
    @echo "🧪 Running tests..."
    cmake -E chdir "{{ build_dir }}" \
        ctest --output-on-failure --parallel 8 -C {{ preset }} {{ args }} | grep -v "^    Start"

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
