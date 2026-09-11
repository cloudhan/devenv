#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -r /etc/os-release ]]; then
    printf 'bootstrap-ngc.sh expects an Ubuntu-based NGC PyTorch image\n' >&2
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
    printf 'bootstrap-ngc.sh expects Ubuntu; found %s\n' "${ID:-unknown}" >&2
    exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
    apt=(apt-get)
elif command -v sudo >/dev/null 2>&1; then
    apt=(sudo apt-get)
else
    printf 'Run as root, or install sudo, so system packages can be installed\n' >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
"${apt[@]}" update
"${apt[@]}" install -y --no-install-recommends \
    bash bubblewrap ca-certificates clangd curl file fish git htop jq \
    libarchive-tools libdw-dev socat sudo tmux tree wget
"${apt[@]}" clean

if ! command -v mise >/dev/null 2>&1; then
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

mkdir -p "$HOME/.config/fish/conf.d"
fish_hook="$HOME/.config/fish/conf.d/mise.fish"
if [[ ! -e "$fish_hook" ]] || ! grep -Fq 'mise activate fish' "$fish_hook"; then
    printf '%s\n' "$mise_bin activate fish | source" >>"$fish_hook"
fi

touch "$HOME/.bashrc"
if ! grep -Fq 'mise activate bash' "$HOME/.bashrc"; then
    printf '%s\n' "eval \"\$(\"$mise_bin\" activate bash)\"" >>"$HOME/.bashrc"
fi

"$mise_bin" trust --yes "$repo_dir/mise.toml"
"$mise_bin" --cd "$repo_dir" install

# Make the configured tools visible for the rest of this run without relying
# on shell startup files.
eval "$("$mise_bin" activate bash)"

# Install only developer packages absent from the raw NGC image. The image's
# Python compute stack is left untouched.
python -m pip install -r "$repo_dir/requirements-dev.txt"

"$repo_dir/scripts/check-env.sh"

printf '\nBootstrap complete. In a fresh shell, cd to:\n  %s\n' "$repo_dir"
