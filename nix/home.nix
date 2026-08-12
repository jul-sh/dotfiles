# This file receives arguments from flake.nix, including our 'inputs'
{ config, pkgs, lib, inputs, ... }:

let
  iosevka-charon = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "iosevka-charon";
    version = "v34.300"; # iosevka-charon
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/iosevka-charon/releases/download/${version}/iosevka-charon.zip";
      sha256 = "138c8fad01e0b0c5dfc37908cda25fae85e6c3512da6974a2dcfc2b162def2a4"; # iosevka-charon
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      find . \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} $out/share/fonts/truetype/ \;
    '';
  };

  recursive-charon = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "recursive-charon";
    version = "build-8034192"; # recursive-charon
    # Static_TTF (not Static_OTF): only the TrueType fonts are extended with
    # Iosevka Charon glyph coverage, since Iosevka Charon ships TrueType only.
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/recursive-charon/releases/download/${version}/Static_TTF.zip";
      sha256 = "60c65a7ae0ce530e1cd08e7564b158bb29c9f01258591409e62d5dcbd600e09b"; # recursive-charon
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      find . -name '*.ttf' -exec cp {} $out/share/fonts/truetype/ \;
    '';
  };

  # The 0ca2372 source revision is Keytap 8.0.0, but its flake still names an
  # unpublished v7 asset. Override that stale release metadata until the next
  # tagged release while retaining the revision's package definition.
  keytapRelease = {
    aarch64-darwin = {
      url = "https://github.com/jul-sh/keytap/releases/download/0ca2372/keytap-0ca2372-arm64.zip";
      hash = "sha256-PKtTkm10J4AuEKx2xUUs5/RnG68UtBKKON8hd33Y3eU=";
    };
    x86_64-linux = {
      url = "https://github.com/jul-sh/keytap/releases/download/0ca2372/keytap-0ca2372-linux-x86_64.zip";
      hash = "sha256-Bl69cQnlTdFiQFte1kJaA6MUjGg4XMjhsuZIzW5gcyE=";
    };
  }.${pkgs.system} or null;

  keytapPackage =
    if keytapRelease == null then null else
    inputs.keytap.packages.${pkgs.system}.default.overrideAttrs (old: {
      version = "8.0.0";
      src = pkgs.fetchurl keytapRelease;
    } // lib.optionalAttrs pkgs.stdenv.isDarwin {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
      installPhase = ''
        app="$out/share/keytap/Keytap.app"
        mkdir -p "$out/share/keytap" "$out/bin"
        cp -R Keytap.app "$out/share/keytap/"
        makeWrapper "$app/Contents/MacOS/keytap" "$out/bin/keytap" \
          --run "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f '$app' >/dev/null 2>&1 || true"
      '';
    });
in
{
  # Standard Home Manager settings
  # username and homeDirectory are now set in flake.nix
  home.stateVersion = "24.05"; # Set to the current version and change it sparingly

  # --- 1. Packages ---
  home.packages = with pkgs; [
    coreutils
    starship
    inputs.nixpkgs-atuin.legacyPackages.${pkgs.system}.atuin
    uv
    inputs.fresh.packages.${pkgs.system}.default
    zellij
    git
    git-lfs
    gh
    rustup
    direnv
    nodejs
    iosevka-charon
    recursive-charon
  ] ++ lib.optional (keytapPackage != null) keytapPackage;

  home.activation.registerKeytap = lib.mkIf (pkgs.stdenv.isDarwin && keytapPackage != null) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f ${keytapPackage}/share/keytap/Keytap.app >/dev/null
    ''
  );

  # --- 2. Dotfiles ---
  # Most dotfiles are symlinked by setup-internal.sh (not Nix).
  # Only Nix-dependent files are managed here.
  home.file = {
    ".hushlogin".text = "";
    ".zsh_plugins.sh".text = ''
      source ${inputs.zsh-syntax-highlighting}/zsh-syntax-highlighting.plugin.zsh
      source ${inputs.zsh-autocomplete}/zsh-autocomplete.plugin.zsh
    '';
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # macOS needs fonts explicitly placed in ~/Library/Fonts
    "Library/Fonts/iosevka-charon" = {
      source = "${iosevka-charon}/share/fonts/truetype";
      recursive = true;
    };
    "Library/Fonts/recursive-charon" = {
      source = "${recursive-charon}/share/fonts/truetype";
      recursive = true;
    };
  };

  # --- 3. Fonts ---
  fonts.fontconfig.enable = pkgs.stdenv.isLinux; # Ensures font cache is updated on Linux

  # Home Manager is invoked via `nix build` + activate (see setup-internal.sh),
  # so the CLI doesn't need to be in PATH.
  programs.home-manager.enable = false;
}
