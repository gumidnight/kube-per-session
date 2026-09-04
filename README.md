# kube-per-session

Independent Kubernetes contexts per terminal session, while keeping one master kubeconfig.

`kube-per-session` is a small Bash utility for engineers who work with multiple Kubernetes clusters from the same machine, jump host, bastion, or shared DevOps server.

Normally, multiple shells using the same kubeconfig also share its `current-context`. Switching context in one terminal can therefore change what another terminal targets. `kube-per-session` avoids that by creating an isolated temporary kubeconfig for each interactive shell.

## Why

Without isolation:

```text
~/.kube/config
    |
    +-- Terminal 1 -> QAT1
    +-- Terminal 2 -> switches current-context to PROD
                         |
                         +-- Terminal 1 now also sees PROD
```

With `kube-per-session`:

```text
master kubeconfig
~/.kube/config
      |
      +--> temporary session config -> Terminal 1 -> QAT1
      |
      +--> temporary session config -> Terminal 2 -> PROD
```

Each terminal can switch independently without rewriting the master kubeconfig.

## Features

- One master kubeconfig as the source of truth
- Independent Kubernetes context per terminal session
- New sessions start with no active context
- Works with normal `kubectl` commands
- `kuse <context>` to select a context for the current shell
- `kctx` to show the current shell's context
- `koff` to clear the current shell's context
- Validates context names before switching
- Temporary kubeconfigs are created with restrictive permissions
- Automatic cleanup on normal shell exit
- No `sudo` required
- Bash only for v0.1

## Requirements

- Bash
- `kubectl`
- A valid kubeconfig (`$KUBECONFIG` or `~/.kube/config`)

## Install

Clone the repository and run:

```bash
git clone https://github.com/gumidnight/kube-per-session.git
cd kube-per-session
./install.sh
source ~/.bashrc
```

The installer copies the script to:

```text
~/.local/share/kube-per-session/kube-per-session.sh
```

and adds one source line to `~/.bashrc`.

## Usage

A new shell intentionally starts without a selected cluster:

```bash
kctx
```

```text
No Kubernetes context selected
```

Select a context:

```bash
kuse QAT1-MobileApp-LumenAPI-EKS-1
```

Check it:

```bash
kctx
```

Run Kubernetes commands normally:

```bash
kubectl get pods
kubectl get nodes
```

Switch the same terminal to another context:

```bash
kuse QAT2-MobileApp-LumenAPI-EKS-1
```

Clear the current context:

```bash
koff
```

## Multiple terminals

Terminal 1:

```bash
kuse QAT1-MobileApp-LumenAPI-EKS-1
```

Terminal 2:

```bash
kuse QAT2-MobileApp-LumenAPI-EKS-1
```

Both terminals can now use `kubectl` independently.

To verify isolation, run this in each terminal:

```bash
echo "$KUBECONFIG"
kctx
```

The `KUBECONFIG` paths should be different.

## Master kubeconfig

At startup, `kube-per-session` stores the original kubeconfig source in:

```bash
$KPS_MASTER_KUBECONFIG
```

The active shell then points `$KUBECONFIG` to its temporary session copy.

This means commands that intentionally update kubeconfig should target the master explicitly. For example:

```bash
KUBECONFIG="$KPS_MASTER_KUBECONFIG" aws eks update-kubeconfig ...
```

If your original `KUBECONFIG` contained multiple colon-separated files, use the same variable when running maintenance commands.

## Cleanup

The session kubeconfig is removed on normal shell exit. The utility also handles common `HUP` and `TERM` termination paths.

No shell script can guarantee cleanup after `SIGKILL` (`kill -9`), a kernel crash, or a power loss. When available, `kube-per-session` prefers `$XDG_RUNTIME_DIR`; otherwise it falls back to `/tmp`.

## Security note

This is a workflow safety guardrail, not a security boundary.

Production access should still be protected with appropriate controls such as:

- Kubernetes RBAC
- Cloud IAM
- Least privilege
- Separate roles/accounts where appropriate
- Change-management and production approval processes

The goal is to reduce accidental cross-session context switching, not to replace access control.

## Uninstall

```bash
./uninstall.sh
source ~/.bashrc
```

## License

MIT
