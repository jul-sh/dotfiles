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
    zellij
    aichat
    git
    gh
    rustup
  ];

  # --- 2. Dotfiles ---
  # This section declaratively manages your configuration files, replacing the
  # need for manual symlinking scripts. It links files from your repository's
  # 'dotfiles' directory into your home directory.

  # --- Files in HOME (~) ---
  # Automatically link all files from dotfiles directory (excluding .config)
  home.file =
    let
      dotfilesDir = ../dotfiles;
      # Read directory contents and filter out .config
      dotfilesContents = lib.filterAttrs (name: type: name != ".config") (builtins.readDir dotfilesDir);

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


  # --- 4. Shell Configuration (ZSH) ---
  programs.zsh = {
    enable = true;

    # We disable the default completion to use your exact custom logic.
    enableCompletion = false;

    # Replicates `setopt` commands
    setOptions = [
      "GLOB_DOTS"
      "INTERACTIVE_COMMENTS"
      "IGNORE_EOF"
    ];

    # Replicates your `load_plugin` function using declarative inputs.
    # The commits are pinned in flake.nix for perfect reproducibility.
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = inputs.zsh-syntax-highlighting;
        file = "zsh-syntax-highlighting.plugin.zsh";
      }
      {
        name = "zsh-autocomplete";
        src = inputs.zsh-autocomplete;
      }
    ];

    # This block runs at the beginning of the Nix-generated .zshrc.
    # Perfect for sourcing profiles and setting up compinit.
    initExtraBeforeCompInit = ''
      # Source Nix multi-user profile if it exists
      if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
      fi
      # Source Nix single-user profile if it exists
      if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      # Add /nix/var/nix/profiles/default/bin to PATH if it exists
      if [ -f "/nix/var/nix/profiles/default/bin/nix" ]; then
        export PATH="/nix/var/nix/profiles/default/bin:$PATH"
      fi

      # Source .profile if it exists
      if [ -f "$HOME/.profile" ]; then
        source "$HOME/.profile"
      fi

      # Source .local_profile if it exists
      if [ -f "$HOME/.local_profile" ]; then
        source "$HOME/.local_profile"
      fi



      # --- Custom Completion Initialization (from your .zshrc) ---
      autoload -Uz compinit
      # Avoid recompiling .zcompdump too often
      if [[ ! -f ~/.zcompdump || -z $(find ~/.zcompdump -mtime -1) ]]; then
        compinit -d ~/.zcompdump # Specify dump file path
      else
        compinit -i -d ~/.zcompdump # Use existing dump file
      fi
    '';

    # This block runs after plugins are loaded.
    # Perfect for greetings, keybindings, and sourcing custom scripts.
    initExtra = ''
      # --- Greeting Message ---
      echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

      # --- Autocomplete Keybindings and Styles ---
      bindkey '^I' menu-select
      bindkey -M menuselect '^I' menu-complete
      zstyle ':autocomplete:tab:*' widget-style menu-complete
      zmodload zsh/terminfo # Ensure terminfo is loaded
      [[ -n "$terminfo[kcbt]" ]] && bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
      zstyle ':autocomplete:*' min-input 3
      zstyle ':completion:*' menu yes select
      bindkey -M menuselect '^[' undo

      # --- Restore Default History Bindings ---
      bindkey -M emacs \
          "^[p"   .history-search-backward \
          "^[n"   .history-search-forward \
          "^P"    .up-line-or-history \
          "^[OA"  .up-line-or-history \
          "^[[A"  .up-line-or-history \
          "^N"    .down-line-or-history \
          "^[OB"  .down-line-or-history \
          "^[[B"  .down-line-or-history \
          "^R"    .history-incremental-search-backward \
          "^S"    .history-incremental-search-forward \
          #
      bindkey -a \
          "^P"    .up-history \
          "^N"    .down-history \
          "k"     .up-line-or-history \
          "^[OA"  .up-line-or-history \
          "^[[A"  .up-line-or-history \
          "j"     .down-line-or-history \
          "^[OB"  .down-line-or-history \
          "^[[B"  .down-line-or-history \
          "/"     .vi-history-search-backward \
          "?"     .vi-history-search-forward \
          #

      # --- Source Custom Utility Scripts ---
      if [ -f "$HOME/.dotfiles_update.sh" ]; then
        source "$HOME/.dotfiles_update.sh"
      fi

      if [ -f "$HOME/.utils.sh" ]; then
        source "$HOME/.utils.sh"
      fi
    '';
  };

  # Declarative initialization for tools
  programs.starship.enable = true;
  programs.atuin.enable = true;
  programs.atuin.enableZshIntegration = true;

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;
}
