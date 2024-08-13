# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

source_github_file() {
  local repo_url="$1"
  local file_name="$2"

  # Extract the repository name from the URL
  local repo_name=$(basename "$repo_url" .git)

  # Define the destination directory based on the repository name
  local dest_dir="$HOME/.zsh/$repo_name"

  # Check if the directory exists, if not, clone the repository
  [[ -d "$dest_dir" ]] || git clone --depth 1 -- "$repo_url" "$dest_dir"

  # Source the specified file
  source "$dest_dir/$file_name"
}

source_github_file https://github.com/marlonrichert/zsh-snap.git znap.zsh

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

eval "$(direnv hook zsh)"
