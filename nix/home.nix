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
    version = "build-782fabd"; # recursive-charon
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/recursive-charon/releases/download/${version}/Static_OTF.zip";
      sha256 = "a6a16c1a522ed4e8bec1d4de7847c26172dde5a62126130f1e2b9f13a16f4a8a"; # recursive-charon
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      find . -name '*.otf' -exec cp {} $out/share/fonts/opentype/ \;
    '';
  };
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
  ] ++ lib.optionals (inputs.keytap.packages ? ${pkgs.system} && inputs.keytap.packages.${pkgs.system} ? default) [
    inputs.keytap.packages.${pkgs.system}.default
  ];

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
      source = "${recursive-charon}/share/fonts/opentype";
      recursive = true;
    };
  };

  # --- 3. Fonts ---
  fonts.fontconfig.enable = pkgs.stdenv.isLinux; # Ensures font cache is updated on Linux

  # Home Manager is invoked via `nix build` + activate (see setup-internal.sh),
  # so the CLI doesn't need to be in PATH.
  programs.home-manager.enable = false;
}
