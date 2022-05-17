git=/git
notes=/notes
cli_out=/data

export HISTSIZE=99999
export HISTFILESIZE=99999
export HISTIGNORE="exit"
export HISTCONTROL="erasedups"

export CLI_TOOLS='python yq kubectl helm node maven aws codefresh pulumi github ripgrep gron'

python "$_DIR/script/dedup.py" ~/.bash_history
