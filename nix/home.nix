# This file receives arguments from flake.nix, including our 'inputs'
{ config, pkgs, lib, inputs, ... }:

let
  iosevka-charon = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "iosevka-charon";
    version = "pre-b3162d9da3c6c56995cbc764ff8d6fe025b6af9b"; # iosevka-charon
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/iosevka-charon/releases/download/${version}/iosevka-charon.zip";
      sha256 = "d5edb8cf50f9fe3f1ceef08f27498e070cc77deef92c0e52756fc2d399367dc6"; # iosevka-charon
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      find . \( -name '*.ttf' -o -name '*.otf' \) -exec cp {} $out/share/fonts/truetype/ \;
    '';
  };
in
{
  # Standard Home Manager settings
  # username and homeDirectory are now set in flake.nix
  home.stateVersion = "24.05"; # Set to the current version and change it sparingly

  # --- 1. Packages ---
  home.packages = with pkgs; [
    starship
    atuin
    uv
    inputs.fresh.packages.${pkgs.system}.default
    zellij
    aichat
    git
    gh
    rustup
    direnv
    nodejs
    iosevka-charon
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
  };

  # --- 3. Fonts ---
  fonts.fontconfig.enable = pkgs.stdenv.isLinux; # Ensures font cache is updated on Linux

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
