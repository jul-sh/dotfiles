. "$HOME/.cargo/env"


alias ai='aichat -e'
export PATH="/usr/local/bin:$PATH"

if command -v python3 &> /dev/null; then
  # Set these if python3 is available
  export PATH="$(python3 -m site --user-base)/bin:$PATH"
  alias python='python3'
fi
