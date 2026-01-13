# dotfiles

Reproducible dev environment with Nix + Home Manager. Shared config is declared once and symlinked in; machine-specific tweaks stay yours.

## Install (idempotent)

```bash
curl -L https://c.jul.sh | sh
```

`bootstrap.sh` clones (or fast-forwards) the repo, validates the origin, and re-runs `setup.sh`. Safe to rerun after a `git pull`; new files under `dotfiles` or `dotfiles/.config` get symlinked automatically on the next run.

What `bootstrap.sh` does:
1. Install Nix (multi-user preferred, falls back to single-user)
2. Apply Home Manager config (packages + dotfiles)
3. Create local shell rc wrappers for machine-specific edits
4. Install GUI apps (Raycast, Zed)
5. Apply macOS tweaks

## Layout

- **Live-Edited (Symlinked)**: Every file in `./dotfiles` (including shared shell scripts) is linked directly to your repository using `mkOutOfStoreSymlink`. Just edit and save.
- **Nix-Managed Environment**: Nix handles package installation and environment setup. It generates a small `~/.zsh_plugins.sh` to load store-dependent ZSH plugins.
- **Local Wrappers**: Your git-ignored `.zshrc`, `.bashrc`, etc., source the `.shared` files.

### Shell Source Flow
```text
~/.zshrc (Local wrapper)
  └─ sources ~/.zshrc.shared (Live-editable in dotfiles/)
       ├─ sources ~/.profile.shared (Live-editable in dotfiles/)
       ├─ sources ~/.utils.sh (Live-editable in dotfiles/)
       └─ sources ~/.zsh_plugins.sh (Nix-managed plugins)
```
