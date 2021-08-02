mgrep() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <pattern> ..." >&2; return 1; }
    local command="grep -i '$1'"
    for pattern in "$@"; do
        command+=" | grep -i '$pattern'"
    done
    eval $command
}

_hist_usage() {
    echo "usage: hist [OPTIONS] [SEARCH SEARCH ...]

  SEARCH                  Search term
  [-n,--num-results=10]   Number of results to return

Search command history

Examples:
    hist

See Also:
    man bash
    mgrep
    note history" >&2
}

hist()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "n:" --longoptions "num-results:,help" -- "$@")
    [[ $? != "0" ]] && { _hist_usage; return 1; }
    eval set -- "$opts"
    local num_results="10"
    while :; do
        case "$1" in
            -n|--num-results) num_results="$2"; shift 2 ;;
            --help) _hist_usage; return 1 ;;
            --) shift; break ;;
            *) _hist_usage; return 1 ;;
        esac
    done

    # Input Validation

    # Function
    if [[ -z $1 ]]; then
        history $num_results
    else
        history | mgrep "$@" | tail -n $((num_results + 1)) | head -n -1
    fi
}
