#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_dir="$HOME/.local/share/kube-per-session"
source_file="$install_dir/kube-per-session.sh"
bashrc="$HOME/.bashrc"
source_line='source "$HOME/.local/share/kube-per-session/kube-per-session.sh"'

mkdir -p "$install_dir"
install -m 0644 "$repo_dir/kube-per-session.sh" "$source_file"
touch "$bashrc"

if ! grep -Fqx "$source_line" "$bashrc"; then
    {
        printf '\n# kube-per-session\n'
        printf '%s\n' "$source_line"
    } >>"$bashrc"
fi

printf 'Installed kube-per-session to %s\n' "$source_file"
printf 'Run: source ~/.bashrc\n'
