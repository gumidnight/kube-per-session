#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$repo_dir/kube-per-session.sh"
bash -n "$repo_dir/install.sh"
bash -n "$repo_dir/uninstall.sh"

printf 'Shell syntax checks passed.\n'
