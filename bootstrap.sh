#!/bin/sh
# Idempotent entrypoint to install/update jul-sh/dotfiles.
# - Ensures the checkout exists and points at the expected origin.
# - Fast-forwards to the current branch (or origin HEAD) and runs setup.
set -eu

REPO_URL="${REPO_URL:-https://github.com/jul-sh/dotfiles.git}"
CHECKOUT_DIR="${CHECKOUT_DIR:-$HOME/git/dotfiles}"
TARGET_REF="${TARGET_REF:-}"
SETUP_SCOPE="${SETUP_SCOPE:-}"
export SETUP_SCOPE

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

    # [POSIX] local origin current_branch default_branch ref
    origin="" current_branch="" default_branch="" ref=""
    origin="$(git -C "$CHECKOUT_DIR" remote get-url origin 2>/dev/null || true)"
    [ "$origin" = "$REPO_URL" ] || die "existing $CHECKOUT_DIR origin is '$origin', expected '$REPO_URL'"

    git -C "$CHECKOUT_DIR" fetch --prune origin
    default_branch="$(git -C "$CHECKOUT_DIR" remote show origin | sed -n 's/^  HEAD branch: //p')"
    current_branch="$(git -C "$CHECKOUT_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
    ref="${TARGET_REF:-${current_branch:-${default_branch:-main}}}"

    git -C "$CHECKOUT_DIR" checkout "$ref" >/dev/null 2>&1 || true
    # Check for local changes before pulling
    if ! git -C "$CHECKOUT_DIR" diff --quiet || ! git -C "$CHECKOUT_DIR" diff --staged --quiet; then
        echo "################################################################################"
        echo "Local changes detected - stashing before pull"
        echo "################################################################################"
        echo
        git -C "$CHECKOUT_DIR" diff --stat
        git -C "$CHECKOUT_DIR" diff --staged --stat
        echo
        git -C "$CHECKOUT_DIR" stash push -m "bootstrap-auto-stash"
    fi

    if ! git -C "$CHECKOUT_DIR" pull --ff-only origin "$ref"; then
        die "Fast-forward pull failed. Please resolve manually in $CHECKOUT_DIR"
    fi

    # Reapply stashed changes if any
    if git -C "$CHECKOUT_DIR" stash list | grep -q "bootstrap-auto-stash"; then
        echo "Reapplying local changes..."
        if ! git -C "$CHECKOUT_DIR" stash pop; then
            echo "################################################################################"
            echo "ERROR: Could not reapply local changes - conflicts detected"
            echo "################################################################################"
            echo
            echo "Your changes are still in the stash. To see them:"
            echo "  git -C $CHECKOUT_DIR stash show -p"
            echo
            echo "How would you like to proceed?"
            echo " [d] Drop stashed changes and continue"
            echo " [m] Manual resolution (exit script)"
            printf "Option [d/M]: "
            read -r choice < /dev/tty || true
            case "$choice" in
                d|D)
                    echo "Dropping stashed changes..."
                    git -C "$CHECKOUT_DIR" stash drop
                    ;;
                *)
                    die "Aborting. Resolve conflicts in $CHECKOUT_DIR and run 'git stash drop' when done."
                    ;;
            esac
        fi
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

ensure_nix_conf() {
    conf_dir="$HOME/.config/nix"
    conf_file="$conf_dir/nix.conf"
    mkdir -p "$conf_dir"
    if [ ! -f "$conf_file" ] || ! grep -q "experimental-features" "$conf_file"; then
        echo "experimental-features = nix-command flakes" >> "$conf_file"
    fi
}

main() {
    require_git
    ensure_checkout_dir
    ensure_repo
    cd "$CHECKOUT_DIR"

    if ! command -v nix >/dev/null 2>&1; then
        bash ./nix/install.sh
    fi

    ensure_nix_conf

    if [ "${IN_NIX_SHELL:-}" = "1" ]; then
        bash ./nix/setup-internal.sh
    else
        echo "Entering Nix environment..."
        exec nix develop ./nix --command bash -c "IN_NIX_SHELL=1 bash ./nix/setup-internal.sh"
    fi
}

main "$@"
