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

require_git() {
    have_cmd git || die "git is required; install it and re-run"
}

ensure_checkout_dir() {
    mkdir -p "$(dirname "$CHECKOUT_DIR")"
}

update_existing_repo() {
    [ -d "$CHECKOUT_DIR/.git" ] || return 1

    # [POSIX] local origin default_branch ref
    origin="" default_branch="" ref=""
    origin="$(git -C "$CHECKOUT_DIR" remote get-url origin 2>/dev/null || true)"
    [ "$origin" = "$REPO_URL" ] || die "existing $CHECKOUT_DIR origin is '$origin', expected '$REPO_URL'"

    git -C "$CHECKOUT_DIR" fetch --prune origin
    default_branch="$(git -C "$CHECKOUT_DIR" remote show origin | sed -n 's/^  HEAD branch: //p')"
    default_branch="${default_branch:-main}"
    ref="${TARGET_REF:-$default_branch}"

    # Abandon any half-finished merge/rebase/cherry-pick left by a prior aborted
    # run so the steps below start from a sane state.
    git -C "$CHECKOUT_DIR" merge --abort >/dev/null 2>&1 || true
    git -C "$CHECKOUT_DIR" rebase --abort >/dev/null 2>&1 || true
    git -C "$CHECKOUT_DIR" cherry-pick --abort >/dev/null 2>&1 || true

    git -C "$CHECKOUT_DIR" checkout "$ref" >/dev/null 2>&1 \
        || git -C "$CHECKOUT_DIR" checkout -B "$ref" "origin/$ref" >/dev/null 2>&1 \
        || die "failed to checkout '$ref' in $CHECKOUT_DIR"

    # Design goal: never get stuck. We always converge the checkout to
    # origin/<ref>, but never silently destroy work — anything local is parked
    # somewhere recoverable (a stash and/or a backup branch) and setup continues.
    stash_ref=""        # set if we stashed dirty working-tree changes
    backup_branch=""    # set if local commits diverged from origin

    # 1. Park uncommitted changes (tracked + staged) in a tagged stash.
    if ! git -C "$CHECKOUT_DIR" diff --quiet \
        || ! git -C "$CHECKOUT_DIR" diff --staged --quiet; then
        echo "Local changes detected — stashing before update:"
        git --no-pager -C "$CHECKOUT_DIR" diff --stat
        git --no-pager -C "$CHECKOUT_DIR" diff --staged --stat
        if git -C "$CHECKOUT_DIR" stash push --include-untracked \
            -m "bootstrap-auto-stash" >/dev/null 2>&1; then
            stash_ref="$(git -C "$CHECKOUT_DIR" stash list \
                | sed -n 's/^\(stash@{[0-9]*}\):.*bootstrap-auto-stash.*/\1/p' \
                | head -n1)"
        fi
    fi

    # 2. Try a clean fast-forward. If history has diverged (local commits not on
    #    origin), preserve them on a backup branch and hard-reset to origin so we
    #    never wedge on a failed --ff-only pull.
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

    # 3. Reapply the stash cleanly if possible. On conflict, roll the working
    #    tree back to a clean origin state and leave the stash intact — setup
    #    continues from a known-good checkout; the work is recoverable.
    if [ -n "$stash_ref" ]; then
        if git -C "$CHECKOUT_DIR" stash pop "$stash_ref" >/dev/null 2>&1; then
            stash_ref=""  # cleanly reapplied; nothing parked
            echo "Reapplied your local changes:"
            git --no-pager -C "$CHECKOUT_DIR" diff --stat
        else
            git -C "$CHECKOUT_DIR" checkout -- . >/dev/null 2>&1 || true
            git -C "$CHECKOUT_DIR" reset --hard "origin/$ref" >/dev/null 2>&1 || true
            echo "Your local changes conflict with the update — kept in the stash."
        fi
    fi

    # 4. Non-blocking recovery summary (only if anything was parked aside).
    if [ -n "$stash_ref" ] || [ -n "$backup_branch" ]; then
        echo "################################################################################"
        echo "Setup is continuing against origin/$ref. Nothing was lost:"
        [ -n "$stash_ref" ] && \
            echo "  • Uncommitted changes: git -C $CHECKOUT_DIR stash show -p"
        [ -n "$backup_branch" ] && \
            echo "  • Diverged commits:    git -C $CHECKOUT_DIR log $backup_branch"
        echo "################################################################################"
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
        # install.sh runs in a subshell, so source the profile here
        for _p in "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
                  "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
            if [ -f "$_p" ]; then . "$_p"; break; fi
        done
        command -v nix >/dev/null 2>&1 || die "nix not found after install; restart your shell and re-run"
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
