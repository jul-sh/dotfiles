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
  # We generate .shared files that are sourced by local (untracked) rc files,
  # allowing machine-specific customizations without Nix conflicts.

  # --- Files in HOME (~) ---
  home.file =
    let
      dotfilesDir = ../dotfiles;
      # Read directory contents and filter out shell rc files and .config
      dotfilesContents = lib.filterAttrs
        (name: type:
          name != ".config" &&
          name != ".bashrc.shared" &&
          name != ".profile.shared" &&
          name != ".zshrc.shared" &&
          name != ".utils.sh"
        )
        (builtins.readDir dotfilesDir);

      # Create file mappings - regular files get direct source, directories get recursive
      autoMappings = lib.mapAttrs' (name: type: {
        name = name;
        value = {
          source = dotfilesDir + "/${name}";
        } // lib.optionalAttrs (type == "directory") { recursive = true; };
      }) dotfilesContents;
    in
    autoMappings // {
      # Create an empty .hushlogin to prevent the "last login" message in the terminal.
      ".hushlogin".text = "";

      # --- .profile.shared ---
      # Nix-managed shared profile configuration (loaded from external file)
      ".profile.shared" = {
        text = builtins.readFile ./shell/profile.sh;
        force = true;
      };

      # --- .bashrc.shared ---
      # Nix-managed shared bash configuration (loaded from external file)
      ".bashrc.shared" = {
        text = builtins.replaceStrings
          [ "@atuin@" "@direnv@" ]
          [ "${pkgs.atuin}/bin/atuin" "${pkgs.direnv}/bin/direnv" ]
          (builtins.readFile ./shell/bashrc.sh);
        force = true;
      };

      # --- .zshrc.shared ---
      # Nix-managed shared zsh configuration (loaded from external file)
      ".zshrc.shared" = {
        text = builtins.replaceStrings
          [ "@zsh-syntax-highlighting@" "@zsh-autocomplete@" "@atuin@" "@direnv@" "@starship@" ]
          [ "${inputs.zsh-syntax-highlighting}" "${inputs.zsh-autocomplete}" "${pkgs.atuin}/bin/atuin" "${pkgs.direnv}/bin/direnv" "${pkgs.starship}/bin/starship" ]
          (builtins.readFile ./shell/zshrc.sh);
        force = true;
      };

      # --- .utils.sh ---
      # Nix-managed shared utils configuration (loaded from external file)
      ".utils.sh" = {
        text = builtins.replaceStrings
          [ "@aichat@" ]
          [ "${pkgs.aichat}/bin/aichat" ]
          (builtins.readFile ./shell/utils.sh);
        force = true;
      };
    } // (if pkgs.stdenv.isDarwin then {
      "Library/Fonts/managed-by-nix".source = ../fonts;
      "Library/Fonts/managed-by-nix".recursive = true;
    } else {
      ".local/share/fonts/managed-by-nix".source = ../fonts;
      ".local/share/fonts/managed-by-nix".recursive = true;
    });

  # --- Files in .config (XDG_CONFIG_HOME) ---
  # Automatically link all files and directories from dotfiles/.config
  xdg.configFile =
    let
      configDir = ../dotfiles/.config;
      configContents = builtins.readDir configDir;
    in
    lib.mapAttrs' (name: type: {
      name = name;
      value = {
        source = configDir + "/${name}";
      } // lib.optionalAttrs (type == "directory") { recursive = true; };
    }) configContents;

  # --- 3. Fonts ---
  fonts.fontconfig.enable = true; # Ensures font cache is updated on Linux

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
