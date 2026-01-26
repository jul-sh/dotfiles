# Source shared profile early to prioritize Nix packages over /usr/local/bin
# This runs after /etc/profile but before .bashrc
[ -f "${HOME}/.profile.shared" ] && . "${HOME}/.profile.shared"

# Source .ENV (case invariant) if it exists
if command -v find >/dev/null 2>&1; then
    _env_file=$(find "$HOME" -maxdepth 1 -iname ".env" -type f | head -n 1)
    [ -n "$_env_file" ] && . "$_env_file"
    unset _env_file
fi
