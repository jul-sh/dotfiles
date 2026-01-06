#!/usr/bin/env bash
# Idempotent entrypoint to install/update jul-sh/dotfiles.
# - Ensures the checkout exists and points at the expected origin.
# - Fast-forwards to the current branch (or origin HEAD) and runs setup.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/jul-sh/dotfiles.git}"
CHECKOUT_DIR="${CHECKOUT_DIR:-$HOME/git/dotfiles}"
TARGET_REF="${TARGET_REF:-}"

die() { echo "error: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_git() {
    have_cmd git || die "git is required; install it and re-run"
}

ensure_checkout_dir() {
    mkdir -p "$(dirname "$CHECKOUT_DIR")"
}

update_existing_repo() {
    [ -d "$CHECKOUT_DIR/.git" ] || return 1

    local origin current_branch default_branch ref
    origin="$(git -C "$CHECKOUT_DIR" remote get-url origin 2>/dev/null || true)"
    [ "$origin" = "$REPO_URL" ] || die "existing $CHECKOUT_DIR origin is '$origin', expected '$REPO_URL'"

    git -C "$CHECKOUT_DIR" fetch --prune origin
    default_branch="$(git -C "$CHECKOUT_DIR" remote show origin | sed -n 's/^  HEAD branch: //p')"
    current_branch="$(git -C "$CHECKOUT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
    ref="${TARGET_REF:-${current_branch:-${default_branch:-main}}}"

    git -C "$CHECKOUT_DIR" checkout "$ref" >/dev/null 2>&1 || true
    if ! git -C "$CHECKOUT_DIR" pull --ff-only origin "$ref"; then
        echo "################################################################################"
        echo "ERROR: Fast-forward pull failed in $CHECKOUT_DIR"
        echo "This usually happens when local changes conflict with upstream."
        echo "################################################################################"
        echo
        git -C "$CHECKOUT_DIR" status
        echo
        echo "How would you like to proceed?"
        echo " [r] Reset to upstream (WARNING: deletes all local changes)"
        echo " [m] Manual resolution (exit script)"
        echo -n "Option [r/M]: "
        read -r choice < /dev/tty || true
        case "$choice" in
            r|R)
                echo "Resetting to origin/$ref..."
                git -C "$CHECKOUT_DIR" reset --hard "origin/$ref"
                ;;
            *)
                die "Aborting. Please resolve conflicts in $CHECKOUT_DIR and re-run."
                ;;
        esac
    fi
    return 0
}

clone_repo() {
    git clone "$REPO_URL" "$CHECKOUT_DIR"
}

ensure_repo() {
    if [ -d "$CHECKOUT_DIR" ] && [ ! -d "$CHECKOUT_DIR/.git" ]; then
        die "existing $CHECKOUT_DIR is not a git repo; move it or set CHECKOUT_DIR to another path"
    fi

    update_existing_repo || clone_repo
}

main() {
    require_git
    ensure_checkout_dir
    ensure_repo
    cd "$CHECKOUT_DIR"
    ./setup.sh
}

main "$@"
