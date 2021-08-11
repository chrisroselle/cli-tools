FROM registry.access.redhat.com/ubi8/ubi

RUN yum -y install \
        --disableplugin=subscription-manager \
        ca-certificates \
        curl \
        diffutils \
        dos2unix \
        git \
        java-11-openjdk-devel \
        jq \
        # aws cli dependency
        less \
        openssl \
        python3 \
        unzip \
        vim \
        xz \
    && yum --disableplugin=subscription-manager clean all \
    && ln -s /usr/bin/python3 /usr/bin/python

# install root certificates
#COPY ../resources/ssl/* /etc/pki/ca-trust/source/anchors/
#RUN chmod 644 /etc/pki/ca-trust/source/anchors/* \
#    && update-ca-trust \
#    && echo "NODE_EXTRA_CA_CERTS='/etc/pki/ca-trust/"

# install ripgrep
RUN cd /tmp \
    && curl -LJs $(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep browser_download_url | grep linux-musl | cut -d '"' -f 4) -o ripgrep.tar.gz \
    && tar xzf ripgrep.tar.gz \
    && mv ripgrep-*/rg /usr/local/bin/rg \
    && chmod +x /usr/local/bin/rg

# install yq
RUN curl -LJs $(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4) -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# install kubectl
RUN curl -LS  "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# install helm
ARG HELM_VERSION="3.5.4"
RUN cd /tmp \
    && curl -LJs "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" -o "helm.tar.gz" \
    && tar xzf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -r ./*

## install nodejs + yarn
#ARG NODEJS_VERSION="14.17.0"
#RUN cd /tmp \
#    && curl -s "https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz" -o nodejs.tar.xz \
#    && tar xJf "nodejs.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
#    && rm /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md \
#    && rm -r ./* \
#    && npm install --global yarn
#
## install maven
#ARG MAVEN_VERSION="3.6.3"
#RUN cd /tmp \
#    && curl -s "https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o maven.tar.gz \
#    && tar xzf maven.tar.gz -C /usr/local \
#    && ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn \
#    && ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnDebug /usr/local/bin/mvnDebug \
#    && ln -s /usr/local/apache-maven-${MAVEN_VERSION}/bin/mvnyjp /usr/local/bin/mvnyjp
#
# install AWS CLI
RUN cd /tmp \
    && curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O \
    && unzip awscli-exe-linux-x86_64.zip \
    && ./aws/install \
    && rm -r ./*

## install AWS CLI Session Manager Plugin
## https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#RUN cd /tmp \
#    && curl -s "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -O \
#    && yum --disableplugin=subscription-manager install -y ./session-manager-plugin.rpm \
#    && rm ./session-manager-plugin.rpm

# update bash profile
RUN echo "[[ -f /scripts/main.sh ]] && source /scripts/main.sh" >> /root/.bashrc \
    && echo "source /root/.bashrc" >> /root/.bash_profile

CMD /bin/bash
