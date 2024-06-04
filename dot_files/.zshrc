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
znap install zsh-users/zsh-history-substring-search
znap source zsh-users/zsh-history-substring-search
znap install zsh-users/zsh-autosuggestions
znap source zsh-users/zsh-autosuggestions

ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

eval "$(starship init zsh)"
