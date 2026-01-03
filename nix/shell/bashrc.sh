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
if [[ "$-" =~ i && -x "${WHICH_ZSH}" && ! "${SHELL}" -ef "${WHICH_ZSH}" ]]; then
  exec env SHELL="${WHICH_ZSH}" "${WHICH_ZSH}" -i
fi

# Initialize atuin for bash (using Nix-managed binary)
eval "$(@atuin@ init bash)"

# Initialize direnv for bash
eval "$(@direnv@ hook bash)"
