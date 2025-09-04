{
  description = "Declarative Home Configuration";

  inputs = {
    # Nix Packages collection, pinned to the unstable channel for latest packages
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Home Manager for managing user environments
    home-manager = {
      url = "github:nix-community/home-manager";
      # Make sure Home Manager uses the same Nixpkgs version as we do
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- ZSH Plugins as Inputs ---
    # Nix tracks the exact commit in flake.lock for reproducibility.
    zsh-syntax-highlighting = {
      url = "github:zsh-users/zsh-syntax-highlighting";
      flake = false; # This is just source code, not a flake
    };

    zsh-autocomplete = {
      url = "github:marlonrichert/zsh-autocomplete";
      flake = false; # This is just source code, not a flake
    };
  };

  # The output of the flake
  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # Define supported systems
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Helper function to generate attribute sets for all systems
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Helper function to create a Home Manager configuration for a given system and user
      mkHomeConfiguration = system: username: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to modules
        modules = [
          ./home.nix
          {
            home.username = username;
            home.homeDirectory =
              if (nixpkgs.lib.hasSuffix "darwin" system)
              then "/Users/${username}"
              else "/home/${username}";
          }
        ];
      };

      # List of users to generate configurations for
      users = [ "julsh" ];

      # Generate all user@system combinations.
      userConfigurations = builtins.listToAttrs (
        nixpkgs.lib.flatten (
          map (user:
            map (system: {
              name = "${user}@${system}";
              value = mkHomeConfiguration system user;
            }) supportedSystems
          ) users
        )
      );

    in
    {
      # Expose the generated configurations to home-manager.
      homeConfigurations = userConfigurations;

      # Make home-manager available as a runnable app for each system.
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
        };
      });
    };
}
