#!/usr/bin/env bash
#
# Updates flake.lock and iosevka-charon font to latest versions.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

update_flake() {
    echo "Updating flake.lock..."
    nix flake update --flake ./nix
}

update_iosevka_charon() {
    echo "Updating iosevka-charon..."
    local api_url="https://api.github.com/repos/jul-sh/iosevka-charon/releases"
    local tmp_json
    tmp_json=$(mktemp)

    curl -fsSL "$api_url" -o "$tmp_json"

    local version url sha256
    version=$(jq -r '.[0].tag_name' "$tmp_json")
    url=$(jq -r '.[0].assets[] | select(.name == "iosevka-charon.zip") | .browser_download_url' "$tmp_json")
    rm "$tmp_json"

    echo "  Fetching hash for $version..."
    sha256=$(curl -fsSL "$url" | shasum -a 256 | awk '{print $1}')

    # Update version and sha256 in home.nix (matched by trailing marker comment)
    perl -i -pe "s|version = \".*?\"; # iosevka-charon|version = \"$version\"; # iosevka-charon|" nix/home.nix
    perl -i -pe "s|sha256 = \".*?\"; # iosevka-charon|sha256 = \"$sha256\"; # iosevka-charon|" nix/home.nix

    echo "  Updated to $version"
}

main() {
    update_flake
    update_iosevka_charon
    echo "Done."
}

main "$@"
