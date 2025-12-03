# dotfiles

Reproducible dev environment with Nix + Home Manager. Shared config is declared once and symlinked in; machine-specific tweaks stay yours.

## Install (idempotent)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jul-sh/dotfiles/main/bootstrap.sh)
```

`bootstrap.sh` clones (or fast-forwards) the repo, validates the origin, and re-runs `setup.sh`. Safe to rerun after a `git pull`; new files under `dotfiles` or `dotfiles/.config` get symlinked automatically on the next run.

What `./setup.sh` does:
1. Install Nix (multi-user preferred, falls back to single-user)
2. Apply Home Manager config (packages + dotfiles)
3. Create local shell rc wrappers for machine-specific edits
4. Install GUI apps (Raycast, Zed)
5. Apply macOS tweaks

## Layout

- Shared (Nix-managed): `.profile.shared`, `.bashrc.shared`, `.zshrc.shared`, and the files in ./dotfiles.
- Local (yours): `.profile`, `.bashrc`, `.zshrc` are created once, untracked, and only source the `.shared` files. Installers can append here without touching Nix-managed state.

### Flow
```
~/.zshrc (local)
  └─ sources .zshrc.shared (Nix-managed)
       └─ sources .profile.shared (Nix-managed)
```
