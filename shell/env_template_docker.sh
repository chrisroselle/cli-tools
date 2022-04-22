git=/git
notes=/notes
cli_out=/data

export HISTSIZE=99999
export HISTFILESIZE=99999
export HISTIGNORE="exit"
export HISTCONTROL="erasedups"

python $_ROOT/scripts/dedup.py ~/.bash_history
