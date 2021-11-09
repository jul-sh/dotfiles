#
# Configure CLI
touch ~/.hushlogin

for filename in $(find dot_files/.* -depth 0 -type f); do
  [[ -e "$filename" ]] || continue
  [[ $filename != "dot_files/.DS_Store" ]] || continue
  cp -v "$filename" ~/
done

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
/bin/bash -c "$(curl -fsSL https://starship.rs/install.sh)"
/opt/homebrew/bin/brew install starship

#
# Apps
/opt/homebrew/bin/brew install --cask brave-browser raycast transmission iina visual-studio-code

#
# Set some OSX System preferences
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain AppleShowScrollBars -string WhenScrolling
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true &&
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true &&
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true &&
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write com.apple.dock "show-recents" -int 0
defaults write com.apple.dock "minimize-to-application" -int 1
defaults write com.apple.dock "tilesize" -int 34
defaults write com.apple.dock "orientation" -string "left"
killall Dock
sudo killall Finder

#
# Configure Terminal
open ./julsh.terminal
defaults write com.apple.terminal "Default Window Settings" "julsh"

#
# Launch agents
/bin/bash ./launchagent_remap_capslock_to_backspace/setup.sh

echo "All done! Pls see the manual_taks dir for remaining manual setup tasks."
