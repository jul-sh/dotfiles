export PATH="/usr/local/bin:$PATH"
path+="/opt/homebrew/bin"
# start ZSH shell
WHICH_ZSH="$(which ZSH)"
if [[ "$-" =~ i && -x "${WHICH_ZSH}" && ! "${SHELL}" -ef "${WHICH_ZSH}" ]]; then
    # Safeguard to only activate ZSH for interactive shells and only if ZSH
    # shell is present and executable. Verify that this is a new session by
    # checking if $SHELL is set to the path to ZSH. If it is not, we set
    # $SHELL and start ZSH.
    #
    # If this is not a new session, the user probably typed 'bash' into their
    # console and wants bash, so we skip this.
    exec env SHELL="${WHICH_ZSH}" "${WHICH_ZSH}" -i
fi
