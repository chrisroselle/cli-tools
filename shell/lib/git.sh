help_git() {
    echo "git.sh:"
    echo "---------"
    echo "g_feature                                 - create a new feature branch"
    echo "g_pr_feature                              - push current branch and open pr"
    echo "--shorthand:"
    echo "gs            git status"
}

_g_is_clean() {
    local status
    status=$(git status --short)
    if [[ -z $status ]]; then
        return 0
    fi
    return 1
}

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

gs() {
    git status
}

g_feature() {
    local repo="$1"
    local new_branch="$2"
    [[ -z $new_branch ]] && {
        echo "usage: g_feature <repo> <new_branch_name>" >&2
        return 1
    }
    cd $git/$repo || return 1
    _g_sanity || return 1
    local current_branch default_branch
    current_branch=$(git branch --show-current)
    default_branch=$(_g_default_branch)
    if [[ $current_branch != $default_branch ]]; then
        if _g_is_clean; then
            git checkout "$default_branch"
        else
            git status --short
            echo "error: working tree is unclean" >&2
            return 1
        fi
    fi
    git pull
    git checkout -b "$new_branch" || return 1
}

g_pr_feature() {
    _g_sanity || return 1
    if ! _g_is_clean; then
        git status --short
        echo "error: working tree is unclean" >&2
        return 1
    fi
    git push --set-upstream origin
    gh pr create --title "$(git branch --show-current)" --body ""
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