#!/usr/bin/env bash
set -euo pipefail

install_dir="$HOME/.local/share/kube-per-session"
bashrc="$HOME/.bashrc"
source_line='source "$HOME/.local/share/kube-per-session/kube-per-session.sh"'

if [[ -f "$bashrc" ]]; then
    tmp_file="$(mktemp)"
    awk -v source_line="$source_line" '
        $0 == "# kube-per-session" { skip_comment=1; next }
        $0 == source_line { skip_comment=0; next }
        { print }
    ' "$bashrc" >"$tmp_file"
    cat "$tmp_file" >"$bashrc"
    rm -f "$tmp_file"
fi

rm -rf -- "$install_dir"

printf 'Uninstalled kube-per-session.\n'
printf 'Open a new shell or run: source ~/.bashrc\n'
