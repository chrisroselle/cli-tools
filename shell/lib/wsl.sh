help_wsl() {
    echo "wsl.sh:"
    echo "---------"
    echo "wsl_patch                                 - Install software updates"
    echo "wsl_configs                               - Pull latest config updates from windows home to WSL home"
    echo "--shorthand:"
    echo "np            notepad++.exe"
}

wsl_patch() {
    sudo dnf -y update
    for tool in ${CLI_TOOLS:?CLI_TOOLS is unset - check env.sh}; do
        if !_update_$tool; then
            echo "$tool update failed - aborting remaining updates" >&2
            return 1
        fi
    done
    date +%s > /tmp/last_patch.txt
}

np() {
    "/mnt/c/Program Files (x86)/Notepad++/notepad++.exe" $@
}

wsl_configs() {
    if [[ -z $WIN_USERNAME ]]; then
        echo "\$WIN_USERNAME is not set - please set in $_DIR/env.sh"
        return 1
    fi
    local wdir="/mnt/c/users/$WIN_USERNAME"
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
    sudo pip install --upgrade pip
    pip install --upgrade pipx
    pipx upgrade-all
}

_update_yq() {
    echo "updating yq..."
    # yq --version
    sudo curl -LJs $(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -o /usr/local/bin/yq \
    && sudo chmod +x /usr/local/bin/yq
}

_update_kubectl() {
    echo "updating kubectl..."
    # kubectl version
    sudo curl -sL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
        && sudo chmod +x /usr/local/bin/kubectl
}

_update_helm() {
    echo "updating helm..."
    # helm version
    (
        set -euo pipefail
        mkdir /tmp/helm
        cd /tmp/helm
        HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name')
        curl -LJs "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o "helm.tar.gz"
        tar xzf helm.tar.gz
        sudo mv linux-amd64/helm /usr/local/bin/helm
        sudo chmod +x /usr/local/bin/helm
    )
    rm -rf /tmp/helm
}

_update_node() {
    echo "updating node..."
    # node --version
    # yarn --version
    (
        set -euo pipefail
        mkdir /tmp/node
        cd /tmp/node
        NODEJS_FILE=$(curl -s https://nodejs.org/download/release/latest-v14.x/ | grep "linux-x64.tar.xz" | cut -f2 -d '>' | cut -f1 -d '<')
        curl -Ls "https://nodejs.org/download/release/latest-v14.x/${NODEJS_FILE}" -o "nodejs.tar.xz"
        sudo tar -xJf "nodejs.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
        sudo rm /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md nodejs.tar.xz
        sudo npm install --global yarn
    )
    rm -rf /tmp/node
}

_update_maven() {
    echo "updating maven..."
    # mvn --version
    local MAVEN_VERSION=$(curl -s https://apache.osuosl.org/maven/maven-3/ | grep "<img" | tail -n 1 | cut -f3 -d '>' | cut -f1 -d '/')
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
    )
    rm -rf /tmp/maven
}

_update_aws() {
    echo "updating aws cli..."
    # aws --version
    (
        set -euo pipefail
        mkdir /tmp/aws
        cd /tmp/aws
        curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O
        unzip awscli-exe-linux-x86_64.zip
        sudo ./aws/install --update
        curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
        sudo dnf install -y ./session-manager-plugin.rpm
    )
    rm -rf /tmp/aws
}

_update_codefresh() {
    echo "updating codefresh cli..."
    # codefresh version
    (
        set -euo pipefail
        mkdir /tmp/codefresh
        cd /tmp/codefresh
        CODEFRESH_URL=$(curl -s https://api.github.com/repos/codefresh-io/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url')
        curl -sLJ "$CODEFRESH_URL" -o "codefresh.tar.gz"
        tar xzf codefresh.tar.gz
        sudo mv ./codefresh /usr/local/bin
        sudo chmod 755 /usr/local/bin/codefresh
    )
    rm -rf /tmp/codefresh
}

_update_pulumi() {
    echo "updating pulumi cli..."
    # pulumi version
    (
        set -euo pipefail
        mkdir /tmp/pulumi/
        cd /tmp/pulumi
        PULUMI_URL=$(curl -s https://api.github.com/repos/pulumi/pulumi/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url')
        curl -sLJ "$PULUMI_URL" -o "pulumi.tar.gz"
        tar xzf pulumi.tar.gz
        sudo mv pulumi/pulumi* /usr/local/bin
        sudo chmod 755 /usr/local/bin/pulumi*
    )
    rm -rf /tmp/pulumi
}

_update_github() {
    echo "updating github cli..."
    # gh version
    (
        set -euo pipefail
        mkdir /tmp/github
        cd /tmp/github
        GITHUB_URL=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux_amd64.tar.gz")) | .browser_download_url')
        curl -LJs "$GITHUB_URL" -o "github.tar.gz"
        tar xzf "github.tar.gz"
        sudo mv gh_*_linux_amd64/bin/gh /usr/local/bin/gh
        sudo chmod +x /usr/local/bin/gh
    )
    rm -rf /tmp/github
}

_update_ripgrep() {
    echo "updating ripgrep..."
    # rg --version
    (
        set -euo pipefail
        mkdir /tmp/ripgrep
        cd /tmp/ripgrep
        RIPGREP_URL=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.assets[] | select(.name | contains("linux-musl")) | .browser_download_url')
        curl -LJs "$RIPGREP_URL" -o "ripgrep.tar.gz"
        tar xzf "ripgrep.tar.gz"
        sudo mv ripgrep-*/rg /usr/local/bin/rg
        sudo chmod +x /usr/local/bin/rg
    )
    rm -rf /tmp/ripgrep
}

_update_gron() {
    echo "updating gron..."
    # gron --version
    (
        set -euo pipefail
        mkdir /tmp/gron
        cd /tmp/gron
        GRON_URL=$(curl -s https://api.github.com/repos/tomnomnom/gron/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url')
        curl -LJs "$GRON_URL" -o "gron.tar.gz"
        tar xzf "gron.tar.gz"
        sudo mv gron /usr/local/bin/gron
        sudo chmod +x /usr/local/bin/gron
    )
    rm -rf /tmp/gron
}
