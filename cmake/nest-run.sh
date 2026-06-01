#!/usr/bin/env bash
set -euo pipefail

target="$1"
preset="$2"
shift 2

bindir=".nest/bin/${target}"

if [ ! -d "$bindir" ]; then
    echo "No build found for target '${target}'"
    exit 1
fi

versions=()
for e in "$bindir"/*/; do
    [ -d "$e" ] && versions+=("$(basename "$e")")
done

if [ ${#versions[@]} -eq 0 ]; then
    echo "No build found for target '${target}'"
    exit 1
elif [ ${#versions[@]} -eq 1 ]; then
    v="${versions[0]}"
else
    if command -v fzf &>/dev/null; then
        height=$((($(tput lines) < 20) ? $(tput lines) : 20))
        v=$(printf "%s\n" "${versions[@]}" | fzf -1 --prompt="Choose project version > " --layout=reverse --cycle --info=inline-right --height "$height")
    else
        PS3=">> "
        echo "Multiple versions found for '${target}':"
        select v in "${versions[@]}"; do
            if [ -n "$v" ]; then
                break
            fi
            echo "Invalid selection, try again."
        done
    fi
fi

config_dirs=()
for e in "$bindir/$v"/*/; do
    [ -d "$e" ] && config_dirs+=("$(basename "$e")")
done

if [ ${#config_dirs[@]} -eq 0 ]; then
    echo "No configuration found for ${target}"
    exit 1
elif [ ${#config_dirs[@]} -eq 1 ]; then
    build_type="${config_dirs[0]}"
else
    if command -v fzf &>/dev/null; then
        height=$((($(tput lines) < 20) ? $(tput lines) : 20))
        build_type=$(printf "%s\n" "${config_dirs[@]}" | fzf -1 --prompt="Choose configuration > " --layout=reverse --cycle --info=inline-right --height "$height")
    else
        PS3=">> "
        echo "Multiple configurations for '${target}':"
        select build_type in "${config_dirs[@]}"; do
            if [ -n "$build_type" ]; then
                break
            fi
            echo "Invalid selection, try again."
        done
    fi
fi

exec "$bindir/$v/${build_type}/${target}" "$@"
