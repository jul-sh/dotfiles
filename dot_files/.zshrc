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

source_github_file https://github.com/zsh-users/zsh-history-substring-search.git zsh-history-substring-search.zsh
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

source_github_file https://github.com/marlonrichert/zsh-snap.git znap.zsh

znap install zsh-users/zsh-syntax-highlighting
znap source zsh-users/zsh-syntax-highlighting
znap install zsh-users/zsh-autosuggestions
znap source zsh-users/zsh-autosuggestions

eval "$(starship init zsh)"
