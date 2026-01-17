# Source shared profile early to prioritize Nix packages over /usr/local/bin
# This runs after /etc/zprofile (path_helper) but before .zshrc
[ -f "${HOME}/.profile.shared" ] && . "${HOME}/.profile.shared"
