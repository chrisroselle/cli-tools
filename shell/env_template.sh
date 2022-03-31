git=/git
notes=/notes
cli_out=/data

export HISTSIZE=99999
export HISTFILESIZE=99999
export HISTIGNORE="exit"
export HISTCONTROL="erasedups"

# WSL
win_username="placeholder"
#export BROWSER="/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"

python "$_DIR/scripts/dedup.py" ~/.bash_history
