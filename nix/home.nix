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
          name != ".zshrc.shared"
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
      # Nix-managed shared profile configuration
      ".profile.shared" = {
        text = ''
          alias ai='aichat -e'

          # Add user-level package manager binaries to PATH
          # These directories allow installing tools without sudo/Nix for quick iteration

          # Cargo: cargo install <crate>
          export PATH="$HOME/.cargo/bin:$PATH"

          # UV: uv tool install <package> (Python tools)
          export PATH="$HOME/.local/bin:$PATH"

          # Go: go install <package>
          export PATH="$HOME/go/bin:$PATH"

          # NPM: npm install -g <package> (when configured with prefix=~/.npm-global)
          export PATH="$HOME/.npm-global/bin:$PATH"

          export PATH="/usr/local/bin:$PATH"

          if command -v python3 &> /dev/null; then
            # Set these if python3 is available
            export PATH="$(python3 -m site --user-base)/bin:$PATH"
            alias python='python3'
          fi


          # A smart zellij attach/create function.
          # Usage:
          #   za          - Attaches to a session for the current directory, or creates one.
          #   za <name>   - Attaches to or creates a session with a specific name.
          za() {
            # If an argument is provided, use it as the session name directly.
            if [[ -n "$1" ]]; then
              zellij attach "$1" || zellij --session "$1"
              return
            fi

            # --- ZSH Version ---
            # Uses ZSH's built-in parameter expansion for conciseness.
            if [ -n "$ZSH_VERSION" ]; then
              local parent_dir="''${PWD:h:t}"   # Parent directory's name
              local current_dir="''${PWD:t}"   # Current directory's name
              local sanitized_path=$(echo "$PWD" | tr '/' '_') # Full path with '/' -> '_'

            # --- Bash Version ---
            # Uses standard commands for compatibility.
            elif [ -n "$BASH_VERSION" ]; then
              local current_dir=$(basename "$(pwd)")
              local parent_dir=$(basename "$(dirname "$(pwd)")")
              local sanitized_path=$(pwd | tr '/' '_') # Full path with '/' -> '_'

            else
              echo "Unsupported shell. This function works with ZSH or Bash."
              return 1
            fi

            # Combine them into a descriptive and unique session name.
            # Example: projects-my-app--_home_user_projects_my-app
            local session_name="''${parent_dir}-''${current_dir}--''${sanitized_path}"

            # Attach to the session if it exists, otherwise create it with the new name.
            zellij attach "$session_name" || zellij --session "$session_name"
          }
        '';
        force = true;
      };

      # --- .bashrc.shared ---
      # Nix-managed shared bash configuration
      ".bashrc.shared" = {
        text = ''
          # Source shared profile configuration
          if [ -f "$HOME/.profile.shared" ]; then
            . "$HOME/.profile.shared"
          fi

          # Source Nix multi-user profile if it exists
          if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
          fi
          # Source Nix single-user profile if it exists
          if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            . "$HOME/.nix-profile/etc/profile.d/nix.sh"
          fi

          # Start ZSH shell if available (bash is primarily just a fallback launcher for zsh)
          WHICH_ZSH="$(which zsh)"
          if [[ "$-" =~ i && -x "''${WHICH_ZSH}" && ! "''${SHELL}" -ef "''${WHICH_ZSH}" ]]; then
            exec env SHELL="''${WHICH_ZSH}" "''${WHICH_ZSH}" -i
          fi

          # Initialize atuin for bash (using Nix-managed binary)
          eval "$(${pkgs.atuin}/bin/atuin init bash)"

          # Initialize direnv for bash
          eval "$(${pkgs.direnv}/bin/direnv hook bash)"
        '';
        force = true;
      };

      # --- .zshrc.shared ---
      # Nix-managed shared zsh configuration
      ".zshrc.shared" = {
        text = ''
          # Source Nix multi-user profile if it exists
          if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
          fi
          # Source Nix single-user profile if it exists
          if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            . "$HOME/.nix-profile/etc/profile.d/nix.sh"
          fi

          # Source shared profile if it exists
          if [ -f "$HOME/.profile.shared" ]; then
            source "$HOME/.profile.shared"
          fi

          # Print a greeting message
          echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

          # --------------------------------
          # ZSH Other Configuration
          # --------------------------------

          # Show hidden files in completions
          setopt globdots

          # Don't error on comments in shell
          setopt interactivecomments

          # Disable Ctrl+D to close session
          setopt ignoreeof

          # --------------------------------
          # ZSH Plugins (Nix-managed)
          # --------------------------------

          # Initialize completion system
          autoload -Uz compinit
          # Avoid recompiling .zcompdump too often, check if it's older than 1 day
          if [[ ! -f ~/.zcompdump || -z $(find ~/.zcompdump -mtime -1) ]]; then
            compinit -d ~/.zcompdump # Specify dump file path
          else
            compinit -i -d ~/.zcompdump # Use existing dump file without checks
          fi

          # Load zsh-syntax-highlighting plugin from Nix flake input
          source ${inputs.zsh-syntax-highlighting}/zsh-syntax-highlighting.plugin.zsh

          # Load zsh-autocomplete plugin from Nix flake input
          source ${inputs.zsh-autocomplete}/zsh-autocomplete.plugin.zsh
          bindkey '^I' menu-select
          bindkey -M menuselect '^I' menu-complete
          zstyle ':autocomplete:tab:*' widget-style menu-complete
          bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
          zstyle ':autocomplete:*' min-input 3
          # Don't prompt for confirmation if there's many completions to show
          zstyle ':completion:*' menu yes select
          # Esc to exit autocomplete menu
          bindkey -M menuselect '^[' undo
          # Restore default history binding, otherwise occupied by zsh autocomplete
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

          # Use atuin for history search
          eval "$(${pkgs.atuin}/bin/atuin init zsh)"

          # Check for dotfile updates
          if [ -f "$HOME/.dotfiles_update.sh" ]; then
            source "$HOME/.dotfiles_update.sh"
          fi

          if [ -f "$HOME/.utils.sh" ]; then
            source "$HOME/.utils.sh"
          fi

          # Initialize direnv for zsh
          eval "$(${pkgs.direnv}/bin/direnv hook zsh)"

          # Initialize starship prompt
          eval "$(${pkgs.starship}/bin/starship init zsh)"
        '';
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
