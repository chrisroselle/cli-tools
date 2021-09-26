#!/bin/bash

ssl_trust_pem_centos() {
    if [[ -z $1 ]]; then
        echo "trust_pem_centos: missing parameter" >&2
        echo "usage: trust_pem_centos <pem_encoded_certificate> [<pem_encoded_certificate> ...]" >&2
        echo "example: trust_pem_centos certificate.pem certificate2.crt" >&2
        return 1
    fi
    local cert
    for cert in $@; do
        cp $cert /etc/pki/ca-trust/source/anchors/
    done
    update-ca-trust
}

ssl_trust_pem_jdk() {
    if [[ -z $2 ]]; then
        echo "trust_pem_jdk: missing parameter(s)" >&2
        echo "usage: trust_pem_jdk <java_home> <pem_encoded_certificate> [<pem_encoded_certificate> ...]" >&2
        echo "example: trust_pem_jdk /home/user/jdk-11.0.8 certificate.pem certificate2.crt" >&2
        return 1
    fi
    local JAVA_HOME=$1
    shift
    for cert in $@; do
        $JAVA_HOME/bin/keytool -import -noprompt -keystore $JAVA_HOME/lib/security/cacerts -storepass changeit -file $cert -alias ${cert%.*}
    done
}

ssl_keystore_contains_certificate() {
    if [[ -z $2 ]]; then
        echo "keystore_contains_certificate: missing parameter(s)" >&2
        echo "usage: keystore_contains_certificate <keystore> <certificate>" >&2
        echo "example: keystore_contains_certificate keystore.jks trust.crt" >&2
        return 255
    fi
    local KEYSTORE=$1
    local CERT=$2
    local KEYTOOL=keytool
    if [[ -n $JAVA_HOME ]]; then
        local KEYTOOL=$JAVA_HOME/bin/keytool
    fi
    if ! $KEYTOOL -printcert -v -file $CERT > /dev/null; then
        echo "certificate $CERT could not be read by keytool" >&2
        return 255
    fi
    local FINGERPRINT=$($KEYTOOL -printcert -v -file $CERT | grep "SHA256:" | cut -f3 -d " ")
    $KEYTOOL -list -v -keystore $KEYSTORE -storepass changeit | grep -Fq "$FINGERPRINT"
}