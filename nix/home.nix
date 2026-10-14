# This file receives arguments from flake.nix, including our 'inputs'
{ config, pkgs, lib, inputs, ... }:

let
  iosevka-charon = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "iosevka-charon";
    version = "v34.802"; # iosevka-charon
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/iosevka-charon/releases/download/${version}/iosevka-charon.zip";
      sha256 = "a453733116aad7313576bb02486cc470e2497902d435b905cd8796a99f4baaa7"; # iosevka-charon
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

  kerberos = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "kerberos";
    version = "v1.2.4"; # kerberos
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/Kerberos/releases/download/${version}/Kerberos-${lib.removePrefix "v" version}.zip";
      sha256 = "89674dcc8cc5c80d941e3ee849f8273ee577a653e3079bba10d92f253e2927c3"; # kerberos
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      roman=$(find . -type f -path '*/variable/*' -name 'Kerberos*.ttf' ! -name '*Italic*' -print -quit)
      italic=$(find . -type f -path '*/variable/*' -name 'Kerberos-Italic*.ttf' -print -quit)
      test -n "$roman" -a -n "$italic"
      install -m 444 "$roman" $out/share/fonts/truetype/Kerberos-VF.ttf
      install -m 444 "$italic" $out/share/fonts/truetype/Kerberos-Italic-VF.ttf
    '';
  };

  keytapPackage = inputs.keytap.packages.${pkgs.system}.default or null;
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
  ]
  ++ lib.optional (keytapPackage != null) keytapPackage
  ++ lib.optional pkgs.stdenv.isLinux kerberos;

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

  # CoreText does not reliably register fonts symlinked into ~/Library/Fonts.
  # Copy Kerberos as real files so it is immediately available to macOS apps.
  home.activation = lib.optionalAttrs pkgs.stdenv.isDarwin {
    installKerberosFonts = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      font_dir="${config.home.homeDirectory}/Library/Fonts"
      mkdir -p "$font_dir"
      for font in Kerberos-VF.ttf Kerberos-Italic-VF.ttf; do
        source="${kerberos}/share/fonts/truetype/$font"
        target="$font_dir/$font"
        if ! cmp -s "$source" "$target"; then
          install -m 644 "$source" "$target"
        fi
      done
    '';
  };

  # --- 3. Fonts ---
  fonts.fontconfig.enable = pkgs.stdenv.isLinux; # Ensures font cache is updated on Linux

  # Home Manager is invoked via `nix build` + activate (see setup-internal.sh),
  # so the CLI doesn't need to be in PATH.
  programs.home-manager.enable = false;
}
