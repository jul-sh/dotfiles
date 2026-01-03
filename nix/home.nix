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
  # This section declaratively manages your configuration files.
  # We use out-of-store symlinks to allow live editing in your repo.
  home.file =
    let
      dotfilesDir = "/Users/julsh/git/dotfiles/dotfiles";
      dotfilesContents = builtins.readDir ../dotfiles;
      # Create file mappings - all files in dotfiles/ get linked out-of-store
      autoMappings = lib.mapAttrs' (name: type: {
        name = name;
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${name}";
        };
      }) dotfilesContents;
    in
    autoMappings // {
      # Create an empty .hushlogin to prevent the "last login" message in the terminal.
      ".hushlogin".text = "";

      # This file is managed by Nix to handle store-path dependent plugin loading.
      # It is sourced by your live-editable .zshrc.shared.
      ".zsh_plugins.sh".text = ''
        source ${inputs.zsh-syntax-highlighting}/zsh-syntax-highlighting.plugin.zsh
        source ${inputs.zsh-autocomplete}/zsh-autocomplete.plugin.zsh
      '';
    } // (if pkgs.stdenv.isDarwin then {
      "Library/Fonts/managed-by-nix".source = ../fonts;
      "Library/Fonts/managed-by-nix".recursive = true;
    } else {
      ".local/share/fonts/managed-by-nix".source = ../fonts;
      ".local/share/fonts/managed-by-nix".recursive = true;
    });

  # --- 3. Fonts ---
  fonts.fontconfig.enable = true; # Ensures font cache is updated on Linux

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
