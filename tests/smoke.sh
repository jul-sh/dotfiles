#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() { echo "not ok - $*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "expected file: $1"; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"; }

make_fake_nix() {
    local bin_dir="$1"
    mkdir -p "$bin_dir"
    printf '#!/bin/sh\nexit 0\n' > "$bin_dir/nix"
    chmod +x "$bin_dir/nix"
}

make_git_fixture() {
    local fixture="$1"
    mkdir -p "$fixture"
    git init -q --bare "$fixture/origin.git"
    git --git-dir="$fixture/origin.git" symbolic-ref HEAD refs/heads/main
    git init -q -b main "$fixture/source"
    git -C "$fixture/source" config user.name Test
    git -C "$fixture/source" config user.email test@example.com
    printf 'initial\n' > "$fixture/source/tracked.txt"
    git -C "$fixture/source" add tracked.txt
    git -C "$fixture/source" commit -qm initial
    git -C "$fixture/source" remote add origin "$fixture/origin.git"
    git -C "$fixture/source" push -q -u origin main
    make_fake_nix "$fixture/bin"
    mkdir -p "$fixture/home"
}

run_bootstrap() {
    local fixture="$1"
    HOME="$fixture/home" \
    PATH="$fixture/bin:/usr/bin:/bin" \
    REPO_URL="$fixture/origin.git" \
    CHECKOUT_DIR="$fixture/checkout" \
    TARGET_REF=main SETUP_SCOPE=user \
        "$REPO_ROOT/bootstrap.sh" > "$fixture/bootstrap.log" 2>&1
}

test_bootstrap_fresh_and_clean_update() {
    local fixture="$TEST_ROOT/bootstrap-clean"
    make_git_fixture "$fixture"
    run_bootstrap "$fixture"
    assert_file "$fixture/checkout/tracked.txt"

    printf 'remote\n' > "$fixture/source/remote.txt"
    git -C "$fixture/source" add remote.txt
    git -C "$fixture/source" commit -qm remote
    git -C "$fixture/source" push -q
    run_bootstrap "$fixture"
    assert_file "$fixture/checkout/remote.txt"
}

test_bootstrap_dirty_update() {
    local fixture="$TEST_ROOT/bootstrap-dirty"
    make_git_fixture "$fixture"
    run_bootstrap "$fixture"
    printf 'local\n' >> "$fixture/checkout/tracked.txt"
    printf 'untracked\n' > "$fixture/checkout/local-untracked.txt"
    printf 'remote\n' > "$fixture/source/remote.txt"
    git -C "$fixture/source" add remote.txt
    git -C "$fixture/source" commit -qm remote
    git -C "$fixture/source" push -q

    run_bootstrap "$fixture"
    assert_contains "$fixture/checkout/tracked.txt" local
    assert_file "$fixture/checkout/local-untracked.txt"
    assert_file "$fixture/checkout/remote.txt"
    [[ -z "$(git -C "$fixture/checkout" stash list)" ]] || fail "bootstrap left a recovered stash behind"
}

test_bootstrap_diverged_update() {
    local fixture="$TEST_ROOT/bootstrap-diverged" backup
    make_git_fixture "$fixture"
    run_bootstrap "$fixture"
    git -C "$fixture/checkout" config user.name Test
    git -C "$fixture/checkout" config user.email test@example.com
    printf 'local commit\n' > "$fixture/checkout/local.txt"
    git -C "$fixture/checkout" add local.txt
    git -C "$fixture/checkout" commit -qm local

    printf 'remote commit\n' > "$fixture/source/remote.txt"
    git -C "$fixture/source" add remote.txt
    git -C "$fixture/source" commit -qm remote
    git -C "$fixture/source" push -q
    run_bootstrap "$fixture"

    backup=$(git -C "$fixture/checkout" branch --format='%(refname:short)' --list 'bootstrap-backup/*')
    [[ -n "$backup" ]] || fail "bootstrap did not preserve diverged commits"
    git -C "$fixture/checkout" show "$backup:local.txt" >/dev/null
    assert_file "$fixture/checkout/remote.txt"
}

test_tracked_dotfile_linking_and_local_rcs() {
    local fixture="$TEST_ROOT/linking" home="$TEST_ROOT/link-home"
    mkdir -p "$fixture/dotfiles" "$home"
    git init -q "$fixture"
    printf 'tracked\n' > "$fixture/dotfiles/.tracked"
    printf 'local\n' > "$fixture/dotfiles/.zprofile"
    git -C "$fixture" add dotfiles/.tracked
    ln -s "$fixture/dotfiles/.zprofile" "$home/.zprofile"

    HOME="$home" bash -c 'source "$1"; cd "$2"; symlink_dotfiles; setup_local_rc_files' \
        _ "$REPO_ROOT/nix/setup-internal.sh" "$fixture"

    [[ -L "$home/.tracked" ]] || fail "tracked dotfile was not linked"
    [[ ! -L "$home/.zprofile" ]] || fail "untracked local rc file was linked"
    assert_contains "$home/.zprofile" '# >>> jul-sh/dotfiles managed block >>>'
}

test_local_host_uses_runtime_user() {
    local fixture="$TEST_ROOT/local-host" home="$TEST_ROOT/arbitrary-home"
    mkdir -p "$fixture/nix/hosts" "$home"

    USER=arbitrary HOME="$home" bash -c '
        source "$1"
        cd "$2"
        ensure_local_host_flake
    ' _ "$REPO_ROOT/nix/setup-internal.sh" "$fixture"

    assert_contains "$fixture/nix/hosts/local/flake.nix" 'home.username = lib.mkForce "arbitrary";'
    assert_contains "$fixture/nix/hosts/local/flake.nix" "home.homeDirectory = lib.mkForce \"$home\";"
}

test_persisted_user_scope_skips_system_nix_config() {
    local fixture="$TEST_ROOT/user-nix-config" output
    mkdir -p "$fixture/nix"
    printf 'user\n' > "$fixture/.setup_scope"
    printf 'different\n' > "$fixture/nix/nix.custom.conf"
    output=$(env -u SETUP_SCOPE bash -c '
        source "$1"
        cd "$2"
        sudo() { echo SUDO_CALLED; }
        install_nix_custom_conf
    ' _ "$REPO_ROOT/nix/setup-internal.sh" "$fixture")
    [[ "$output" != *SUDO_CALLED* ]] || fail "persisted user scope invoked sudo"
}

test_setup_scope_dispatch() {
    local scope_file="$TEST_ROOT/setup-scope" output
    if SETUP_SCOPE=invalid bash -c 'source "$1"; SCOPE_FILE="$2"; resolve_setup_scope' \
        _ "$REPO_ROOT/macos/setup.sh" "$scope_file" >/dev/null 2>&1; then
        fail "invalid setup scope was accepted"
    fi
    [[ ! -e "$scope_file" ]] || fail "invalid setup scope was persisted"

    output=$(SETUP_SCOPE=user bash -c '
        source "$1"
        install_capslock_remap_user() { echo user-capslock; }
        install_launchd_job() { echo "launchd:$1"; }
        configure_system_defaults() { echo SYSTEM_CALLED; }
        configure_selected_scope
    ' _ "$REPO_ROOT/macos/setup.sh")
    [[ "$output" == *user-capslock* && "$output" == *launchd:user* && "$output" != *SYSTEM_CALLED* ]] \
        || fail "user scope dispatched incorrectly"

    output=$(SETUP_SCOPE=system bash -c '
        source "$1"
        sudo() { return 0; }
        configure_system_defaults() { echo system; }
        configure_selected_scope
    ' _ "$REPO_ROOT/macos/setup.sh")
    [[ "$output" == *system* ]] || fail "system scope dispatched incorrectly"
}

tests=(
    test_bootstrap_fresh_and_clean_update
    test_bootstrap_dirty_update
    test_bootstrap_diverged_update
    test_tracked_dotfile_linking_and_local_rcs
    test_local_host_uses_runtime_user
    test_persisted_user_scope_skips_system_nix_config
    test_setup_scope_dispatch
)

for test_name in "${tests[@]}"; do
    "$test_name"
    echo "ok - ${test_name#test_}"
done
