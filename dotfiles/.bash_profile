# Source shared profile early to prioritize Nix packages over /usr/local/bin
# This runs after /etc/profile but before .bashrc
[ -f "${HOME}/.profile.shared" ] && . "${HOME}/.profile.shared"
