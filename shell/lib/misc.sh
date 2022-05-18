help_misc() {
    echo "misc.sh:"
    echo "---------"
    echo "hist                                      - search command history"
    echo "check_route                               - check network route using telnet"
    echo "continue_prompt                           - prompt before continuing"
    echo "--shorthand:"
    echo "mgrep         grep -i '\$1' | grep -i '\$2' | ..."
    echo "cgrep         grep -iR '\$1' $git | grep -i '\$2' | ..."
}

mgrep() {
    [[ -z $1 || $1 == "--help" ]] && { echo "usage: $FUNCNAME <pattern> ..." >&2; return 1; }
    local command="rg -i '$1'"
    shift
    for pattern in "$@"; do
        command+=" | rg -i '$pattern'"
    done
    eval $command
}

cgrep() {
    [[ -z $1 || $1 == "--help" ]] && { echo "usage: $FUNCNAME <pattern> ..." >&2; return 1; }
    local command="rg -i -g '!notes/' '$1' $git"
    shift
    for pattern in "$@"; do
        command+=" | rg -i '$pattern'"
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

_check_route_usage() {
    echo "usage: check_route HOST:PORT [HOST:PORT ...]

Check network route using telnet

Note that no data is exchanged over the connection, so devices which inspect request content
before deciding whether to allow or deny a connection may give a false positive success, such
as a corporate firewall

Examples:
    check_route google.com:443 espn.com:443" >&2
}

check_route()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "" --longoptions "help" -- "$@")
    [[ $? != "0" ]] && { _check_route_usage; return 1; }
    eval set -- "$opts"
    while :; do
        case "$1" in
            --help) _check_route_usage; return 1 ;;
            --) shift; break ;;
            *) _check_route_usage; return 1 ;;
        esac
    done

    # Input Validation
    [[ -z "$1" ]] && { _check_route_usage; return 1; }

    # Function
    local pair host port
    local returncode=0
    for pair in "$@"; do
        host=${pair%:*}
        port=${pair#*:}
        echo -e '\x1dclose' | telnet "$host" "$port" || returncode=$((returncode + 1))
    done
    return $returncode
}

continue_prompt() {
    [[ -z $1 || $! == "--help" ]] && { echo "usage: $FUNCNAME <message>" >&2; return 1; }
    local cont
    while [[ $cont != "y" && $cont != "n" ]]; do
        read -p "$@ - continue? (y/n): " cont
    done
    if [[ $cont != "y" ]]; then
        return 1
    fi
}