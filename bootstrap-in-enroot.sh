#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Some NGC images ship /etc/environment in pam_env syntax even though Debian
# maintainer scripts source it as shell code. They also mount /run itself
# read-only while leaving /run/lock writable. Stage and validate both repairs
# before replacing either file, then restore both originals if a commit fails.
patch_enroot_apt_prerequisites() (
    local environment_file="${1:-/etc/environment}"
    local adduser_common_file="${2:-/usr/share/perl5/Debian/AdduserCommon.pm}"
    local environment_stage='' environment_backup=''
    local adduser_stage='' adduser_backup=''
    local environment_committed=0 adduser_committed=0 transaction_complete=0

    cleanup_transaction() {
        local status=$?
        trap - EXIT

        if (( ! transaction_complete )); then
            if (( adduser_committed )) && [[ -n "$adduser_backup" ]]; then
                mv -f -- "$adduser_backup" "$adduser_common_file" || status=1
                adduser_backup=''
            fi
            if (( environment_committed )) && [[ -n "$environment_backup" ]]; then
                mv -f -- "$environment_backup" "$environment_file" || status=1
                environment_backup=''
            fi
        fi

        [[ -z "$environment_stage" ]] || rm -f -- "$environment_stage"
        [[ -z "$environment_backup" ]] || rm -f -- "$environment_backup"
        [[ -z "$adduser_stage" ]] || rm -f -- "$adduser_stage"
        [[ -z "$adduser_backup" ]] || rm -f -- "$adduser_backup"
        exit "$status"
    }
    trap cleanup_transaction EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    environment_stage="$(mktemp --tmpdir="$(dirname -- "$environment_file")" \
        ".$(basename -- "$environment_file").bootstrap-stage.XXXXXX")"
    adduser_stage="$(mktemp --tmpdir="$(dirname -- "$adduser_common_file")" \
        ".$(basename -- "$adduser_common_file").bootstrap-stage.XXXXXX")"
    cp --preserve=all -- "$environment_file" "$environment_stage"
    cp --preserve=all -- "$adduser_common_file" "$adduser_stage"

    # Quote assignment values for both pam_env and the shell scripts that
    # source this file. Already quoted values are left byte-for-byte intact.
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if [[ -n "$value" && ! "$value" =~ ^\".*\"$ && ! "$value" =~ ^\'.*\'$ ]]; then
                value="${value//\\/\\\\}"
                value="${value//\"/\\\"}"
                value="${value//\$/\\\$}"
                value="${value//\`/\\\`}"
                printf '%s="%s"\n' "$key" "$value"
                continue
            fi
        fi
        printf '%s\n' "$line"
    done <"$environment_file" >"$environment_stage"

    if grep -Fq "my \$lockfile_path = '/run/adduser';" "$adduser_stage"; then
        sed -i 's|/run/adduser|/run/lock/adduser|' "$adduser_stage"
    elif ! grep -Fq "my \$lockfile_path = '/run/lock/adduser';" "$adduser_stage"; then
        printf 'Cannot locate the adduser lock path in %s\n' "$adduser_common_file" >&2
        exit 1
    fi

    # Loading the staged environment catches unmatched quotes and guarantees
    # that every line is a shell assignment rather than an accidental command.
    env -i /bin/bash --noprofile --norc -c 'set -a; source "$1"' \
        bootstrap-environment-check "$environment_stage"
    perl -c "$adduser_stage" >/dev/null
    grep -Fq "my \$lockfile_path = '/run/lock/adduser';" "$adduser_stage"
    ! grep -Fq "my \$lockfile_path = '/run/adduser';" "$adduser_stage"

    environment_backup="$(mktemp --tmpdir="$(dirname -- "$environment_file")" \
        ".$(basename -- "$environment_file").bootstrap-backup.XXXXXX")"
    adduser_backup="$(mktemp --tmpdir="$(dirname -- "$adduser_common_file")" \
        ".$(basename -- "$adduser_common_file").bootstrap-backup.XXXXXX")"
    cp --preserve=all -- "$environment_file" "$environment_backup"
    cp --preserve=all -- "$adduser_common_file" "$adduser_backup"

    if ! cmp -s -- "$environment_file" "$environment_stage"; then
        mv -f -- "$environment_stage" "$environment_file"
        environment_stage=''
        environment_committed=1
    fi
    if ! cmp -s -- "$adduser_common_file" "$adduser_stage"; then
        mv -f -- "$adduser_stage" "$adduser_common_file"
        adduser_stage=''
        adduser_committed=1
    fi

    transaction_complete=1
    rm -f -- "$environment_backup" "$adduser_backup"
    environment_backup=''
    adduser_backup=''
)

patch_enroot_apt_prerequisites

if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    curl --proto '=https' --tlsv1.2 -fsSL https://mise.run | sh
fi

mise_bin="$(type -P mise 2>/dev/null || true)"
if [[ -z "$mise_bin" && -x "$HOME/.local/bin/mise" ]]; then
    mise_bin="$HOME/.local/bin/mise"
fi
if [[ -z "$mise_bin" ]]; then
    printf 'mise installation did not produce an executable\n' >&2
    exit 1
fi

"$mise_bin" trust --yes "$repo_dir/mise.toml"
export DEBIAN_FRONTEND=noninteractive

# Record bootstrap dependencies globally so they remain selected after leaving
# this repository. Mise selects amd64/aarch64 tool artifacts as appropriate.
install_global_apt_packages() (
    local apt_config_file
    apt_config_file="$(mktemp)"
    trap 'rm -f -- "$apt_config_file"' EXIT
    printf 'APT::Install-Recommends "false";\n' >"$apt_config_file"

    APT_CONFIG="$apt_config_file" "$mise_bin" bootstrap packages use --global --yes \
        apt:bash apt:bubblewrap apt:ca-certificates apt:clangd apt:curl apt:emacs-nox \
        apt:file apt:fish apt:git apt:htop apt:jq apt:libarchive-tools \
        apt:libdw-dev apt:socat apt:sudo apt:tmux apt:tree apt:wget
)
install_global_apt_packages

"$mise_bin" use --global --yes \
    node@24 npm:@openai/codex@latest gh@latest ripgrep@latest fd@latest \
    fzf@latest github:arxanas/git-branchless@0.11.1

install -Dm644 "$repo_dir/scripts/mise.fish" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/mise.fish"

# Make the configured tools visible for the rest of this run without relying
# on shell startup files.
eval "$("$mise_bin" --cd "$repo_dir" env --shell bash)"

# Install only developer packages absent from the raw NGC image. The image's
# Python compute stack is left untouched.
python -m pip install -r "$repo_dir/requirements-dev.txt"

printf '\nBootstrap complete.\n'
