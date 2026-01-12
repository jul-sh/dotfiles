#!/usr/bin/env bash
#
# Updates flake.lock and apps.lock.json to latest versions.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

LOCKFILE="external.lock.json"

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

fetch_iosevka_charon_latest() {
    local api_url="https://api.github.com/repos/jul-sh/iosevka-charon/releases"
    local release
    release=$(curl -fsSL "$api_url" | jq '.[0]')

    local version
    version=$(echo "$release" | jq -r '.tag_name')

    local url
    url=$(echo "$release" | jq -r '.assets[] | select(.name == "iosevka-charon.zip") | .browser_download_url')

    echo "  Fetching iosevka-charon hash..." >&2
    local sha256
    sha256=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')

    jq -n --arg v "$version" --arg u "$url" --arg s "$sha256" \
        '{version: $v, url: $u, sha256: $s}'
}

fetch_clipkitty_latest() {
    local api_url="https://api.github.com/repos/jul-sh/clipkitty/releases/latest"
    local release
    release=$(curl -fsSL "$api_url")

    local version
    version=$(echo "$release" | jq -r '.tag_name')

    local url
    url=$(echo "$release" | jq -r '.assets[] | select(.name == "ClipKitty.app.zip") | .browser_download_url')

    echo "  Fetching ClipKitty hash..." >&2
    local sha256
    sha256=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')

    jq -n --arg v "$version" --arg u "$url" --arg s "$sha256" \
        '{version: $v, url: $u, sha256: $s}'
}

update_apps() {
    echo "Updating external.lock.json..."

    echo "Fetching WezTerm latest..."
    local wezterm
    wezterm=$(fetch_wezterm_latest)

    echo "Fetching Zed latest..."
    local zed
    zed=$(fetch_zed_latest)

    echo "Fetching iosevka-charon latest..."
    local iosevka_charon
    iosevka_charon=$(fetch_iosevka_charon_latest)

    echo "Fetching ClipKitty latest..."
    local clipkitty
    clipkitty=$(fetch_clipkitty_latest)

    jq -n --argjson w "$wezterm" --argjson z "$zed" --argjson i "$iosevka_charon" --argjson c "$clipkitty" \
        '{wezterm: $w, zed: $z, "iosevka-charon": $i, clipkitty: $c}' > "$LOCKFILE"

    echo "Updated $LOCKFILE"
}

main() {
    update_flake
    update_apps
    echo "Done."
}

main "$@"
