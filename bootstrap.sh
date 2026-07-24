#!/bin/sh
# Idempotent entrypoint to install/update jul-sh/dotfiles.
# - Ensures the checkout exists and points at the expected origin.
# - Converges the checkout to origin (current branch or origin HEAD) and runs
#   setup. Never blocks: local changes/commits are parked in a stash and/or
#   backup branch (recoverable) rather than aborting on conflict.
set -eu

REPO_URL="${REPO_URL:-https://github.com/jul-sh/dotfiles.git}"
CHECKOUT_DIR="${CHECKOUT_DIR:-$HOME/git/dotfiles}"
TARGET_REF="${TARGET_REF:-}"
SETUP_SCOPE="${SETUP_SCOPE:-}"
export SETUP_SCOPE

die() { echo "error: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

update_existing_repo() {
    # [POSIX] local origin default_branch ref
    origin="" default_branch="" ref=""
    origin="$(git -C "$CHECKOUT_DIR" remote get-url origin 2>/dev/null || true)"
    [ "$origin" = "$REPO_URL" ] || die "existing $CHECKOUT_DIR origin is '$origin', expected '$REPO_URL'"

    git -C "$CHECKOUT_DIR" fetch --prune origin
    default_branch="$(git -C "$CHECKOUT_DIR" remote show origin | sed -n 's/^  HEAD branch: //p')"
    default_branch="${default_branch:-main}"
    ref="${TARGET_REF:-$default_branch}"

    for operation in merge rebase cherry-pick; do
        git -C "$CHECKOUT_DIR" "$operation" --abort >/dev/null 2>&1 || true
    done

    git -C "$CHECKOUT_DIR" checkout "$ref" >/dev/null 2>&1 \
        || git -C "$CHECKOUT_DIR" checkout -B "$ref" "origin/$ref" >/dev/null 2>&1 \
        || die "failed to checkout '$ref' in $CHECKOUT_DIR"

    stash_ref="" backup_branch=""

    if [ -n "$(git -C "$CHECKOUT_DIR" status --porcelain)" ]; then
        echo "Local changes detected — stashing before update:"
        git -C "$CHECKOUT_DIR" status --short
        if git -C "$CHECKOUT_DIR" stash push --include-untracked -m bootstrap-auto-stash >/dev/null; then
            stash_ref='stash@{0}'
        fi
    fi

    if ! git -C "$CHECKOUT_DIR" pull --ff-only origin "$ref" >/dev/null 2>&1; then
        if ! git -C "$CHECKOUT_DIR" merge-base --is-ancestor \
            HEAD "origin/$ref" >/dev/null 2>&1; then
            backup_branch="bootstrap-backup/$(date +%Y%m%d-%H%M%S)"
            git -C "$CHECKOUT_DIR" branch "$backup_branch" HEAD >/dev/null 2>&1 || true
            echo "Local commits diverged from origin/$ref."
            echo "  Saved them on branch '$backup_branch'."
        fi
        git -C "$CHECKOUT_DIR" reset --hard "origin/$ref" >/dev/null 2>&1 \
            || die "could not reset $CHECKOUT_DIR to origin/$ref"
    fi

    if [ -n "$stash_ref" ]; then
        if git -C "$CHECKOUT_DIR" stash apply "$stash_ref" >/dev/null 2>&1; then
            git -C "$CHECKOUT_DIR" stash drop "$stash_ref" >/dev/null
            stash_ref=""
            echo "Reapplied your local changes:"
            git -C "$CHECKOUT_DIR" status --short
        else
            git -C "$CHECKOUT_DIR" reset --hard "origin/$ref" >/dev/null 2>&1 || true
            echo "Your local changes conflict with the update — kept in the stash."
        fi
    fi

    if [ -n "$stash_ref" ] || [ -n "$backup_branch" ]; then
        echo "################################################################################"
        echo "Setup is continuing against origin/$ref. Nothing was lost:"
        [ -n "$stash_ref" ] && echo "  • Uncommitted changes: git -C $CHECKOUT_DIR stash show -p '$stash_ref'"
        [ -n "$backup_branch" ] && \
            echo "  • Diverged commits:    git -C $CHECKOUT_DIR log $backup_branch"
        echo "################################################################################"
    fi
    return 0
}

ensure_nix_conf() {
    conf_dir="$HOME/.config/nix"
    conf_file="$conf_dir/nix.conf"
    mkdir -p "$conf_dir"
    if [ ! -f "$conf_file" ] || ! grep -q "experimental-features" "$conf_file"; then
        echo "experimental-features = nix-command flakes" >> "$conf_file"
    fi
}

install_nix() {
    have_cmd nix && return
    echo "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
        sh -s -- install --no-confirm || die "Nix installation failed"

    for profile in "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
                   "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [ -f "$profile" ]; then . "$profile"; break; fi
    done
    have_cmd nix || die "nix not found after install; restart your shell and re-run"
}

main() {
    have_cmd git || die "git is required; install it and re-run"
    mkdir -p "$(dirname "$CHECKOUT_DIR")"
    if [ -d "$CHECKOUT_DIR" ] && [ ! -d "$CHECKOUT_DIR/.git" ]; then
        die "existing $CHECKOUT_DIR is not a git repo; move it or choose another CHECKOUT_DIR"
    fi
    if [ -d "$CHECKOUT_DIR/.git" ]; then
        update_existing_repo
    else
        git clone "$REPO_URL" "$CHECKOUT_DIR"
    fi
    cd "$CHECKOUT_DIR"

    install_nix
    ensure_nix_conf

    if [ "${IN_NIX_SHELL:-}" = "1" ]; then
        bash ./nix/setup-internal.sh
    else
        echo "Entering Nix environment..."
        exec nix develop ./nix --command bash -c "IN_NIX_SHELL=1 bash ./nix/setup-internal.sh"
    fi
}

main "$@"
