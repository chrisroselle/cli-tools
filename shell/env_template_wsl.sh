git=/home/chris/git
notes=/mnt/c/users/chris/notes
cli_out=/home/chris/tmp

export HISTSIZE=99999
export HISTFILESIZE=99999
export HISTIGNORE="exit"
export HISTCONTROL="erasedups"

#export BROWSER='/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe'
export BROWSER='/mnt/c/Program Files/Mozilla Firefox/firefox.exe'
export CLI_EDITOR='np'
export CLI_TOOLS='python yq kubectl helm node maven aws codefresh pulumi github ripgrep gron'
export DEFAULT_KUBE_CONTEXT='default'
export WIN_USERNAME=chris

python "$_DIR/script/dedup.py" ~/.bash_history
