#!/usr/bin/env bash

set -euo pipefail

workspace=$HOME/workspaces

if [[ ! -d $workspace ]]; then
    printf 'error: required workspace directory does not exist: %s\n' "$workspace" >&2
    exit 1
fi

path_exists() {
    [[ -e $1 || -L $1 ]]
}

# Verify that merging SRC into DST cannot overwrite a file, symlink, or other
# non-directory.  Do this before moving anything for the current entry.
check_merge() {
    local src=$1 dst=$2 child target

    if ! path_exists "$dst"; then
        return
    fi
    if [[ -d $src && ! -L $src && -d $dst && ! -L $dst ]]; then
        shopt -s nullglob dotglob
        for child in "$src"/*; do
            target=$dst/${child##*/}
            check_merge "$child" "$target"
        done
        shopt -u nullglob dotglob
        return
    fi

    printf 'error: refusing to overwrite existing path: %s\n' "$dst" >&2
    printf '       while migrating: %s\n' "$src" >&2
    return 1
}

# Merge directories recursively; otherwise use rename(2) via mv.  check_merge
# has already established that every move is non-overwriting.
merge_move() {
    local src=$1 dst=$2 child target

    if ! path_exists "$dst"; then
        mkdir -p -- "${dst%/*}"
        mv -- "$src" "$dst"
        return
    fi

    shopt -s nullglob dotglob
    for child in "$src"/*; do
        target=$dst/${child##*/}
        merge_move "$child" "$target"
    done
    shopt -u nullglob dotglob
    rmdir -- "$src"
}

install_link() {
    local name=$1 target_rel=$2
    local src=$HOME/$name
    local dst=$workspace/$target_rel
    local link_target=workspaces/$target_rel

    if [[ -L $src ]]; then
        if [[ $(readlink -f -- "$src") == $(readlink -f -- "$dst") ]]; then
            printf 'ok:   ~/%s already points to ~/workspaces/%s\n' "$name" "$target_rel"
            return
        fi
        printf 'error: ~/%s is an unexpected symlink to %s\n' \
            "$name" "$(readlink -- "$src")" >&2
        return 1
    fi

    if path_exists "$src"; then
        check_merge "$src" "$dst"
        printf 'move: ~/%s -> ~/workspaces/%s\n' "$name" "$target_rel"
        merge_move "$src" "$dst"
    else
        mkdir -p -- "$dst"
    fi

    ln -s -- "$link_target" "$src"
    printf 'link: ~/%s -> %s\n' "$name" "$link_target"
}

# Topologically sorted by destination: workspace parents are migrated before
# links whose destinations live below them (for example .cache before .triton).
links=(
    '.cache|.cache'
    '.cursor-server|.cursor-server'
    '.local|.local'
    '.vscode-remote-containers|.vscode-remote-containers'
    '.vscode-server|.vscode-server'
    '.triton|.cache/triton'
    '.claude|.local/opt/claude'
    '.codex|.local/opt/codex'
    '.cursor|.local/opt/cursor'
    '.npm|.local/opt/npm'
    '.nvm|.local/opt/nvm'
)

for entry in "${links[@]}"; do
    install_link "${entry%%|*}" "${entry#*|}"
done
