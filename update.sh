#!/usr/bin/env bash
#
# Updates flake.lock and external.lock.json to latest versions.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

LOCKFILE="external.lock.json"

update_flake() {
    echo "Updating flake.lock..."
    nix flake update --flake ./nix
}

fetch_iosevka_charon_latest() {
    local api_url="https://api.github.com/repos/jul-sh/iosevka-charon/releases"
    local tmp_json
    tmp_json=$(mktemp)

    curl -fsSL "$api_url" -o "$tmp_json"

    local version
    version=$(jq -r '.[0].tag_name' "$tmp_json")

    local url
    url=$(jq -r '.[0].assets[] | select(.name == "iosevka-charon.zip") | .browser_download_url' "$tmp_json")
    rm "$tmp_json"

    echo "  Fetching iosevka-charon hash..." >&2
    local sha256
    sha256=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')

    jq -n --arg v "$version" --arg u "$url" --arg s "$sha256" \
        '{version: $v, url: $u, sha256: $s}'
}

update_apps() {
    echo "Updating $LOCKFILE..."

    echo "Fetching iosevka-charon latest..."
    local iosevka_charon
    iosevka_charon=$(fetch_iosevka_charon_latest)

    jq -n --argjson i "$iosevka_charon" \
        '{"iosevka-charon": $i}' > "$LOCKFILE"

    echo "Updated $LOCKFILE"
}

main() {
    update_flake
    update_apps
    echo "Done."
}

main "$@"
