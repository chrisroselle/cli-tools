np() {
    "/mnt/c/Program Files (x86)/Notepad++/notepad++.exe" $@
}

wsl_configs() {
    if [[ -z $win_username ]]; then
        echo "\$win_username is not set - please set in $_DIR/env.sh"
        return 1
    fi
    local wdir="/mnt/c/users/$win_username"
    if [[ -f "$wdir/.aws/config" ]]; then
        mkdir ~/.aws
        cp "$wdir/.aws/config" ~/.aws/
    fi
    if [[ -f "$wdir/.pulumi/credentials.json" ]]; then
        mkdir ~/.pulumi
        cp "$wdir/.pulumi/credentials.json" ~/.pulumi/
    fi
    if [[ -d "$wdir/.kube" ]]; then
        mkdir ~/.kube
        find "$wdir/.kube" -maxdepth 1 -type f -exec cp {} ~/.kube/ \;
    fi
    if [[ -f "$wdir/AppData/Roaming/GitHub CLI/hosts.yml" ]]; then
        mkdir -p ~/.config/gh
        cp "$wdir/AppData/Roaming/GitHub CLI/hosts.yml" ~/.config/gh/
    fi
    if [[ -f "$wdir/.cfconfig" ]]; then
        cp "$wdir/.cfconfig" ~/.cfconfig
    fi
}
