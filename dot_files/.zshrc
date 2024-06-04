# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Download Znap, if it's not there yet.
[[ -r ~/Repos/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/Repos/znap
source ~/Repos/znap/znap.zsh

znap prompt sindresorhus/pure

znap install zsh-users/zsh-syntax-highlighting
znap source zsh-users/zsh-syntax-highlighting

znap install marlonrichert/zsh-autocomplete
znap source marlonrichert/zsh-autocomplete

bindkey "$terminfo[kcbt]" menu-select
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
zstyle ':autocomplete:tab:*' widget-style menu-complete
zstyle ':autocomplete:*' min-input 3
bindkey '^R' .history-incremental-search-backward
bindkey '^S' .history-incremental-search-forward
