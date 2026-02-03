# dotfiles

Reproducible dev environment with Nix + Home Manager. l

## Install

```bash
curl c.jul.sh | sh
```

Idempotent. Safe to rerun; new dotfiles get symlinked automatically.


## How it works

- **Nix + Home Manager** handle packages and environment setup
- **Symlinks** keep dotfiles live-editable (edit in repo, changes apply immediately)
- **Local Escape Hatches** files like `~/.zshrc` are git-ignored and just source the shared configs (e.g., `~/.zshrc.shared`). This keeps the repo declarative while letting installers and machine-specific tweaks modify the entrypoint freely
