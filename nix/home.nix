# This file receives arguments from flake.nix, including our 'inputs'
{ config, pkgs, lib, inputs, ... }:

let
  iosevka-charon = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "iosevka-charon";
    version = "1.0.0"; # iosevka-charon
    src = pkgs.fetchurl {
      url = "https://github.com/jul-sh/iosevka-charon/releases/download/${version}/iosevka-charon.zip";
      sha256 = "6299b20a152aebea48dde5d5a1556d29118216b2becba67bc87f3414b4630c14"; # iosevka-charon
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
    git-lfs
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

  # Home Manager is invoked via `nix build` + activate (see setup-internal.sh),
  # so the CLI doesn't need to be in PATH.
  programs.home-manager.enable = false;
}
