_g_sanity() {
    git status >/dev/null 2>&1 || {
        echo "not in a git repository" >&2
        return 1
    }
}

_g_default_branch() {
    _g_sanity || return 1
    local default_branch
    default_branch=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p' 2>/dev/null)
    if [[ -z $default_branch ]]; then
        echo "warning: could not detect default branch, assuming 'main'" >&2
        default_branch="main"
    fi
    echo "$default_branch"
}

g_feature() {
    _g_sanity || return 1
    local new_branch="$1"
    [[ -z $new_branch ]] && {
        echo "usage: g_feature <new_branch_name>" >&2
        return 1
    }
    local current_branch default_branch
    current_branch=$(git branch --show-current)
    default_branch=$(_g_default_branch)
    if [[ $current_branch != $default_branch ]]; then
        local status
        status=$(git status --short)
        [[ -z $status ]] && git checkout "$default_branch"
    fi
    git pull
    git checkout -b "$new_branch" || return 1
}

#g_wip() {
#    _g_sanity || return 1
#    if [[ $1 == "-A" ]]; then
#        echo "unimplemented" >&2
#        return 1
#    else
#        local default_branch
#        default_branch=$(_g_default_branch)
#
#    fi
#}