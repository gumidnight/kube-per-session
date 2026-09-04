#!/usr/bin/env bash

# kube-per-session
# Independent Kubernetes contexts per interactive Bash session.

# Do nothing in non-interactive shells.
[[ $- == *i* ]] || return 0

if ! command -v kubectl >/dev/null 2>&1; then
    return 0
fi

# Avoid creating multiple session configs when the file is sourced more than once.
if [[ -n "${KUBE_SESSION_CONFIG:-}" && -f "${KUBE_SESSION_CONFIG:-}" ]]; then
    return 0
fi

# Preserve the original kubeconfig source as the master.
if [[ -n "${KUBECONFIG:-}" ]]; then
    export KPS_MASTER_KUBECONFIG="$KUBECONFIG"
elif [[ -f "$HOME/.kube/config" ]]; then
    export KPS_MASTER_KUBECONFIG="$HOME/.kube/config"
else
    return 0
fi

# Prefer per-user runtime storage when available, otherwise fall back to /tmp.
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" && -w "$XDG_RUNTIME_DIR" ]]; then
    _kps_tmp_dir="$XDG_RUNTIME_DIR"
else
    _kps_tmp_dir="/tmp"
fi

export KUBE_SESSION_CONFIG="$(mktemp "${_kps_tmp_dir}/kube-${USER:-$(id -un)}-XXXXXX")"

# kubectl supports colon-separated KUBECONFIG values. Flatten the configured
# source(s) into one isolated file for this shell session.
if ! KUBECONFIG="$KPS_MASTER_KUBECONFIG" kubectl config view --raw --flatten >"$KUBE_SESSION_CONFIG"; then
    rm -f -- "$KUBE_SESSION_CONFIG"
    unset KUBE_SESSION_CONFIG
    unset _kps_tmp_dir
    return 1
fi

chmod 600 "$KUBE_SESSION_CONFIG"
export KUBECONFIG="$KUBE_SESSION_CONFIG"

# Safety guardrail: every new terminal begins with no active context.
kubectl config unset current-context >/dev/null 2>&1 || true

_kps_cleanup() {
    if [[ -n "${KUBE_SESSION_CONFIG:-}" && -f "$KUBE_SESSION_CONFIG" ]]; then
        rm -f -- "$KUBE_SESSION_CONFIG"
    fi
}

# Preserve a simple pre-existing EXIT trap and run it after kube-per-session's
# cleanup. Bash executes EXIT traps when an interactive shell exits, including
# normal SSH disconnects. SIGKILL and host crashes cannot be trapped.
_kps_previous_exit_trap="$(trap -p EXIT || true)"
_kps_previous_exit_cmd=""
if [[ -n "$_kps_previous_exit_trap" ]]; then
    _kps_previous_exit_cmd="${_kps_previous_exit_trap#trap -- \'}"
    _kps_previous_exit_cmd="${_kps_previous_exit_cmd%\' EXIT}"
fi

_kps_exit_handler() {
    local rc=$?
    _kps_cleanup

    if [[ -n "${_kps_previous_exit_cmd:-}" ]]; then
        eval "$_kps_previous_exit_cmd"
    fi

    return "$rc"
}

trap _kps_exit_handler EXIT

kuse() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: kuse <context-name>" >&2
        return 1
    fi

    if ! kubectl config get-contexts -o name | grep -Fxq -- "$1"; then
        echo "ERROR: Kubernetes context does not exist: $1" >&2
        return 1
    fi

    kubectl config use-context "$1"
}

kctx() {
    local ctx
    ctx="$(kubectl config current-context 2>/dev/null || true)"

    if [[ -n "$ctx" ]]; then
        printf '%s\n' "$ctx"
    else
        echo "No Kubernetes context selected"
    fi
}

koff() {
    kubectl config unset current-context >/dev/null 2>&1 || true
    echo "Kubernetes context cleared"
}

# Optional convenience alias. Existing aliases/functions named `k` are left alone.
if ! type k >/dev/null 2>&1; then
    alias k='kubectl'
fi

# Enable completion when kubectl supports it.
if kubectl completion bash >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(kubectl completion bash)
    if declare -F __start_kubectl >/dev/null 2>&1; then
        complete -o default -F __start_kubectl k 2>/dev/null || true
    fi
fi

unset _kps_tmp_dir
