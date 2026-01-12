#!/usr/bin/env bash
#
# Updates flake.lock and apps.lock.json to latest versions.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

LOCKFILE="apps.lock.json"

get_arch() {
    case "$(uname -m)" in
        x86_64)        echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *)             echo "unknown" ;;
    esac
}

update_flake() {
    echo "Updating flake.lock..."
    nix flake update --flake ./nix
}

fetch_wezterm_latest() {
    local api_url="https://api.github.com/repos/wez/wezterm/releases/latest"
    local release
    release=$(curl -fsSL "$api_url")

    local version
    version=$(echo "$release" | jq -r '.tag_name')

    local url="https://github.com/wezterm/wezterm/releases/download/${version}/WezTerm-macos-${version}.zip"
    local sha256_url="${url}.sha256"
    local sha256
    sha256=$(curl -fsSL "$sha256_url" | awk '{print $1}')

    jq -n --arg v "$version" --arg u "$url" --arg s "$sha256" \
        '{version: $v, url: $u, sha256: $s}'
}

fetch_zed_latest() {
    local api_url="https://api.github.com/repos/zed-industries/zed/releases/latest"
    local release
    release=$(curl -fsSL "$api_url")

    local version
    version=$(echo "$release" | jq -r '.tag_name')

    local result='{"version":"'"$version"'"}'

    for arch in aarch64 x86_64; do
        local url="https://github.com/zed-industries/zed/releases/download/${version}/Zed-${arch}.dmg"
        echo "  Fetching Zed ${arch} hash..." >&2
        local sha256
        sha256=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')
        result=$(echo "$result" | jq --arg a "$arch" --arg u "$url" --arg s "$sha256" \
            '.[$a] = {url: $u, sha256: $s}')
    done

    echo "$result"
}

update_apps() {
    echo "Updating apps.lock.json..."

    echo "Fetching WezTerm latest..."
    local wezterm
    wezterm=$(fetch_wezterm_latest)

    echo "Fetching Zed latest..."
    local zed
    zed=$(fetch_zed_latest)

    jq -n --argjson w "$wezterm" --argjson z "$zed" \
        '{wezterm: $w, zed: $z}' > "$LOCKFILE"

    echo "Updated $LOCKFILE"
}

main() {
    update_flake
    update_apps
    echo "Done."
}

main "$@"
