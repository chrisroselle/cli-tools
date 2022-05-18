help_notes() {
    echo "notes.sh:"
    echo "---------"
    echo "note <name>                               - open note with matching name. print possible notes if more than one matches"
    echo "notes <search> ...                        - search all notes (case insensitive - multiple terms performs 'and' match)"
    echo "notes_or <search> ...                     - search all notes (case insensitive - multiple terms performs 'or' match)"
    echo "new_note <name>                           - create a new note"
    echo "new_meeting_note <name>                   - create a new meeting note in ${notes}/meeting-note"
    echo "todo                                      - open todo list"
}

note() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <filename_search>" >&2; return 1; }
    local search=$1
    local count=$(find $notes -type f -name "*$search*" | wc -l)
    if ((count > 1)); then
        find $notes -type f -name "*$search*"
    elif ((count == 0)); then
        echo "no note files matching $search found" >&2
        return 1
    else
        local match=$(find $notes -type f -name "*$search*")
        vi $match
    fi
}

notes() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <content_search> ..." >&2; return 1; }
    local command="rg -iR '$1' $notes"
    for search in "$@"; do
        command+=" | rg -i '$search'"
    done
    eval $command
}

notes_or() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <content_search> ..." >&2; return 1; }
    local params=""
    for search_term in "$@"; do
        params+=" -e '$search_term'"
    done
    rg -iR $params $notes
}

new_note() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <name>" >&2; return 1; }
    local name=$1
    vi "${notes}/$name.txt"
}

new_meeting_note() {
    [[ -z $1 ]] && { echo "usage: $FUNCNAME <name>" >&2; return 1; }
    local name=$1
    local datestring=$(date "+%Y-%m-%d")
    vi "${notes}/meeting-notes/${datestring}-${name}.txt"
}

todo() {
    vi "${notes}/TODO"
}