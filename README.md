# dotfiles

Reproducible dev environment with Nix + Home Manager. Shared config is declared once and symlinked in; machine-specific tweaks stay yours.

## Install

```bash
curl -L https://c.jul.sh | sh
```

Idempotent. Safe to rerun after pulling changes—new dotfiles get symlinked automatically.

To skip steps that require sudo (single-user Nix, no system-level macOS tweaks):

```bash
curl -L https://c.jul.sh | sh -s -- --no-sudo
```

## How it works

- **Nix + Home Manager** handle packages and environment setup
- **Symlinks** keep dotfiles live-editable (edit in repo, changes apply immediately)
- **Local wrappers** like `~/.zshrc` are git-ignored and just source the shared configs (e.g., `~/.zshrc.shared`). This keeps the repo declarative while letting installers and machine-specific tweaks modify the entrypoint freely
