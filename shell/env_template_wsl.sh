git=/home/chris/git
notes=/mnt/c/users/chris/notes
cli_out=/home/chris/tmp

export HISTSIZE=99999
export HISTFILESIZE=99999
export HISTIGNORE="exit"
export HISTCONTROL="erasedups"

export WIN_USERNAME=chris
#export BROWSER='/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe'
export BROWSER='/mnt/c/Program Files/Mozilla Firefox/firefox.exe'
python "$_DIR/script/dedup.py" ~/.bash_history
