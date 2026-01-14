# This file receives arguments from flake.nix, including our 'inputs'
{ config, pkgs, lib, inputs, ... }:

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
  };

  # --- 3. Fonts ---
  fonts.fontconfig.enable = pkgs.stdenv.isLinux; # Ensures font cache is updated on Linux

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
