# dotfiles

Reproducible dev environment with Nix + Home Manager.

## Install

```bash
curl c.jul.sh | sh
```

Idempotent. Safe to rerun; new dotfiles get symlinked automatically.

### Without sudo

```bash
SETUP_SCOPE=user curl c.jul.sh | sh
```

Installs Nix in single-user mode and skips all system-wide configuration (LaunchDaemons, login window text). The choice is persisted in `.setup_scope` and reused on subsequent runs. Override anytime by setting `SETUP_SCOPE` explicitly.


## How it works

- **Nix + Home Manager** handle packages and environment setup
- **Symlinks** keep dotfiles live-editable (edit in repo, changes apply immediately)
- **Local Escape Hatches** files like `~/.zshrc` are git-ignored and just source the shared configs (e.g., `~/.zshrc.shared`). This keeps the repo declarative while letting installers and machine-specific tweaks modify the entrypoint freely

## Environment variables

| Variable | Values | Description |
|---|---|---|
| `SETUP_SCOPE` | `system` (default), `user` | `system` installs LaunchDaemons and system defaults (requires sudo). `user` installs LaunchAgents only — fully sudo-free. Persisted in `.setup_scope` |
