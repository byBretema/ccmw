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
        height=$(( ($(tput lines) < 20) ? $(tput lines) : 20 ))
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

exec "$bindir/$v/${preset}/${target}" "$@"
