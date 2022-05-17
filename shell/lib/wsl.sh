help_wsl() {
    echo "wsl.sh:"
    echo "---------"
    echo "wsl_patch                                 - Install software updates"
    echo "wsl_configs                               - Pull latest config updates from windows home to WSL home"
    echo "--shorthand:"
    echo "np            notepad++.exe"
}

np() {
    "/mnt/c/Program Files (x86)/Notepad++/notepad++.exe" $@
}

wsl_patch() {
    for tool in system ${CLI_TOOLS:?\$CLI_TOOLS is not set - please set in $_DIR/env.sh}; do
        if ! _update_$tool; then
            echo "$tool update failed - aborting remaining updates" >&2
            return 1
        fi
    done
    date +%s > /tmp/last_patch.txt
}

wsl_configs() {
    local wdir="/mnt/c/users/${WIN_USERNAME:?\$WIN_USERNAME is not set - please set in $_DIR/env.sh}"
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

_update_system() {
    echo "updating system packages..."
    sudo dnf -y update || return 1
}

_update_python() {
    echo "updating python, pip, pipx..."
    local link
    if [[ ! -f /usr/bin/python ]]; then
        sudo ln -s /usr/bin/python3 /usr/bin/python
    fi
    if [[ ! -f /usr/bin/pip ]]; then
        ln -s /usr/bin/pip3 /usr/bin/pip
    fi
    if [[ ! -f /usr/bin/pydoc ]]; then
        ln -s /usr/bin/pydoc3 /usr/bin/pydoc
    fi
    pip install --upgrade pip
    pip install --upgrade pipx
    pipx upgrade-all
}

_update_yq() {
    # yq --version
    echo "updating yq..."
    (
        set -euo pipefail
        sudo curl -Ls $(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -o /usr/local/bin/yq.new
        sudo chmod +x /usr/local/bin/yq.new
        sudo mv /usr/local/bin/yq.new /usr/local/bin/yq
    )
}

_update_kubectl() {
    # kubectl version
    echo "updating kubectl..."
    (
        set -euo pipefail
        sudo curl -Ls "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl.new
        sudo chmod +x /usr/local/bin/kubectl.new
        sudo mv /usr/local/bin/kubectl.new /usr/local/bin/kubectl
    )
}

_update_helm() {
    # helm version
    echo "updating helm..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/helm
        cd /tmp/helm
        HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name')
        curl -LJs "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o "helm.tar.gz"
        tar xzf helm.tar.gz
        sudo mv linux-amd64/helm /usr/local/bin/helm
        sudo chmod +x /usr/local/bin/helm
    ) || RET=1
    rm -rf /tmp/helm
    return ${RET:?}
}

_update_node() {
    # node --version
    # yarn --version
    echo "updating node..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/node
        cd /tmp/node
        NODEJS_FILE=$(curl -s https://nodejs.org/download/release/latest-v14.x/ | grep "linux-x64.tar.xz" | cut -f2 -d '>' | cut -f1 -d '<')
        curl -Ls "https://nodejs.org/download/release/latest-v14.x/${NODEJS_FILE}" -o "nodejs.tar.xz"
        sudo tar -xJf "nodejs.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
        sudo rm /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md nodejs.tar.xz
        # /usr/local/bin is not in sudo path, so we workaround by adding node to /usr/bin temporarily
        sudo ln -s /usr/local/bin/node /usr/bin/node
        sudo ln -s /usr/local/bin/npm /usr/bin/npm
        sudo ln -s /usr/local/bin/npx /usr/bin/npx
        sudo npm update --global yarn
        sudo rm /usr/bin/node /usr/bin/npm /usr/bin/npx
    ) || RET=1
    rm -rf /tmp/node
    return ${RET:?}
}

_update_maven() {
    # mvn --version
    echo "updating maven..."
    local RET=0
    local MAVEN_VERSION
    MAVEN_VERSION=$(set -o pipefail; curl -s https://apache.osuosl.org/maven/maven-3/ | grep "<img" | tail -n 1 | cut -f3 -d '>' | cut -f1 -d '/') || return 1
    [[ -d /usr/local/apache-maven-${MAVEN_VERSION} ]] && return 0
    (
        set -euo pipefail
        mkdir /tmp/maven
        cd /tmp/maven
        curl -s "https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o "maven.tar.gz"
        sudo tar xzf maven.tar.gz -C /usr/local
        sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn
        sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnDebug /usr/local/bin/mvnDebug
        sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnyjp /usr/local/bin/mvnyjp
    ) || RET=1
    rm -rf /tmp/maven
    return ${RET:?}
}

_update_aws() {
    # aws --version
    echo "updating aws cli..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/aws
        cd /tmp/aws
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O
        unzip awscli-exe-linux-x86_64.zip
        sudo ./aws/install --update
        curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
        sudo dnf install -y ./session-manager-plugin.rpm
    ) || RET=1
    rm -rf /tmp/aws
    return ${RET:?}
}

_update_codefresh() {
    # codefresh version
    echo "updating codefresh cli..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/codefresh
        cd /tmp/codefresh
        CODEFRESH_URL=$(curl -s https://api.github.com/repos/codefresh-io/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url')
        curl -sLJ "$CODEFRESH_URL" -o "codefresh.tar.gz"
        tar xzf codefresh.tar.gz
        sudo mv ./codefresh /usr/local/bin
        sudo chmod 755 /usr/local/bin/codefresh
    ) || RET=1
    rm -rf /tmp/codefresh
    return ${RET:?}
}

_update_pulumi() {
    # pulumi version
    echo "updating pulumi cli..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/pulumi/
        cd /tmp/pulumi
        PULUMI_URL=$(curl -s https://api.github.com/repos/pulumi/pulumi/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url')
        curl -sLJ "$PULUMI_URL" -o "pulumi.tar.gz"
        tar xzf pulumi.tar.gz
        sudo mv pulumi/pulumi* /usr/local/bin
        sudo chmod 755 /usr/local/bin/pulumi*
    ) || RET=1
    rm -rf /tmp/pulumi
    return ${RET:?}
}

_update_github() {
    # gh version
    echo "updating github cli..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/github
        cd /tmp/github
        GITHUB_URL=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux_amd64.tar.gz")) | .browser_download_url')
        curl -LJs "$GITHUB_URL" -o "github.tar.gz"
        tar xzf "github.tar.gz"
        sudo mv gh_*_linux_amd64/bin/gh /usr/local/bin/gh
        sudo chmod +x /usr/local/bin/gh
    ) || RET=1
    rm -rf /tmp/github
    return ${RET:?}
}

_update_ripgrep() {
    # rg --version
    echo "updating ripgrep..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/ripgrep
        cd /tmp/ripgrep
        RIPGREP_URL=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.assets[] | select(.name | contains("linux-musl")) | .browser_download_url')
        curl -LJs "$RIPGREP_URL" -o "ripgrep.tar.gz"
        tar xzf "ripgrep.tar.gz"
        sudo mv ripgrep-*/rg /usr/local/bin/rg
        sudo chmod +x /usr/local/bin/rg
    ) || RET=1
    rm -rf /tmp/ripgrep
    return ${RET:?}
}

_update_gron() {
    # gron --version
    echo "updating gron..."
    local RET=0
    (
        set -euo pipefail
        mkdir /tmp/gron
        cd /tmp/gron
        GRON_URL=$(curl -s https://api.github.com/repos/tomnomnom/gron/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url')
        curl -LJs "$GRON_URL" -o "gron.tar.gz"
        tar xzf "gron.tar.gz"
        sudo mv gron /usr/local/bin/gron
        sudo chmod +x /usr/local/bin/gron
    ) || RET=1
    rm -rf /tmp/gron
    return ${RET:?}
}
