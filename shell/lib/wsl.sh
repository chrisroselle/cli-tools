wsl_patch() {
    sudo dnf -y update
    sudo pip install --upgrade pip
    _update_yq
    _update_kubectl
    _update_helm
    _update_node
    _update_maven
    _update_aws
    _update_codefresh
    _update_pulumi
    _update_github
    _update_ripgrep
    _update_gron
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

_update_yq() {
    # yq --version
    sudo curl -LJs $(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -o /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
}

_update_kubectl() {
    # kubectl version
    sudo curl -sL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
        && sudo chmod +x /usr/local/bin/kubectl
}

_update_helm() {
    # helm version
    (
        mkdir /tmp/helm \
            && cd /tmp/helm \
            && HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name') \
            && curl -LJs "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o "helm.tar.gz" \
            && tar xzf helm.tar.gz \
            && sudo mv linux-amd64/helm /usr/local/bin/helm \
            && sudo chmod +x /usr/local/bin/helm
    )
    rm -rf /tmp/helm
}

_update_node() {
    # node --version
    # yarn --version
    (
        mkdir /tmp/node \
        && cd /tmp/node \
        && NODEJS_FILE=$(curl -s https://nodejs.org/download/release/latest-v14.x/ | grep "linux-x64.tar.xz" | cut -f2 -d '>' | cut -f1 -d '<') \
        && curl -Ls "https://nodejs.org/download/release/latest-v14.x/${NODEJS_FILE}" -o "nodejs.tar.xz" \
        && sudo tar -xJf "nodejs.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
        && sudo rm /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md nodejs.tar.xz \
        && sudo npm install --global yarn
    )
    rm -rf /tmp/node
}

_update_maven() {
    # mvn --version
    local MAVEN_VERSION=$(curl -s https://apache.osuosl.org/maven/maven-3/ | grep "<img" | tail -n 1 | cut -f3 -d '>' | cut -f1 -d '/')
    [[ -d /usr/local/apache-maven-${MAVEN_VERSION} ]] && return 0
    (
        mkdir /tmp/maven \
            && cd /tmp/maven \
            && curl -s "https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o "maven.tar.gz" \
            && sudo tar xzf maven.tar.gz -C /usr/local \
            && sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn \
            && sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnDebug /usr/local/bin/mvnDebug \
            && sudo ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnyjp /usr/local/bin/mvnyjp
    )
    rm -rf /tmp/maven
}

_update_aws() {
    # aws --version
    (
        mkdir /tmp/aws \
            && cd /tmp/aws \
            && curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O \
            && unzip awscli-exe-linux-x86_64.zip \
            && sudo ./aws/install --update \
            && curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm" \
            && sudo dnf install -y ./session-manager-plugin.rpm
    )
    rm -rf /tmp/aws
}

_update_codefresh() {
    # codefresh version
    (
        mkdir /tmp/codefresh \
            && cd /tmp/codefresh \
            && CODEFRESH_URL=$(curl -s https://api.github.com/repos/codefresh-io/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url') \
            && curl -sLJ "$CODEFRESH_URL" -o "codefresh.tar.gz" \
            && tar xzf codefresh.tar.gz \
            && sudo mv ./codefresh /usr/local/bin \
            && sudo chmod 755 /usr/local/bin/codefresh
    )
    rm -rf /tmp/codefresh
}

_update_pulumi() {
    # pulumi version
    (
        mkdir /tmp/pulumi/ \
            && cd /tmp/pulumi \
            && PULUMI_URL=$(curl -s https://api.github.com/repos/pulumi/pulumi/releases/latest | jq -r '.assets[] | select(.name | contains("linux-x64")) | .browser_download_url') \
            && curl -sLJ "$PULUMI_URL" -o "pulumi.tar.gz" \
            && tar xzf pulumi.tar.gz \
            && sudo mv pulumi/pulumi* /usr/local/bin \
            && sudo chmod 755 /usr/local/bin/pulumi*
    )
    rm -rf /tmp/pulumi
}

_update_github() {
    # gh version
    (
        mkdir /tmp/github \
            && cd /tmp/github \
            && GITHUB_URL=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.assets[] | select(.name | contains("linux_amd64.tar.gz")) | .browser_download_url') \
            && curl -LJs "$GITHUB_URL" -o "github.tar.gz" \
            && tar xzf "github.tar.gz" \
            && sudo mv gh_*_linux_amd64/bin/gh /usr/local/bin/gh \
            && sudo chmod +x /usr/local/bin/gh
    )
    rm -rf /tmp/github
}

_update_ripgrep() {
    # rg --version
    (
        mkdir /tmp/ripgrep \
            && cd /tmp/ripgrep \
            && RIPGREP_URL=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq -r '.assets[] | select(.name | contains("linux-musl")) | .browser_download_url') \
            && curl -LJs "$RIPGREP_URL" -o "ripgrep.tar.gz" \
            && tar xzf "ripgrep.tar.gz" \
            && sudo mv ripgrep-*/rg /usr/local/bin/rg \
            && sudo chmod +x /usr/local/bin/rg
    )
    rm -rf /tmp/ripgrep
}

_update_gron() {
    # gron --version
    (
        mkdir /tmp/gron \
            && cd /tmp/gron \
            && GRON_URL=$(curl -s https://api.github.com/repos/tomnomnom/gron/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url') \
            && curl -LJs "$GRON_URL" -o "gron.tar.gz" \
            && tar xzf "gron.tar.gz" \
            && sudo mv gron /usr/local/bin/gron \
            && sudo chmod +x /usr/local/bin/gron
    )
    rm -rf /tmp/gron
}
