# Set path to oh-my-zsh installation
export ZSH="${HOME}/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Plugins to load
plugins=(
  git
  zsh-autosuggestions
  history-substring-search
  zsh-syntax-highlighting
)

# Plugin settings
ZSH_AUTOSUGGEST_STRATEGY=(completion history)

# Source the oh-my-zsh.sh script
source "${ZSH}/oh-my-zsh.sh"

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Initialize starship prompt
eval "$(starship init zsh)"
