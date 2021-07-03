#!/bin/bash

# References for configuration choices
# https://stackoverflow.com/questions/589834/what-rsa-key-length-should-i-use-for-my-ssl-certificates
# https://www.ssl.com/blogs/398-day-browser-limit-for-ssl-tls-certificates-begins-september-1-2020/
# https://security.stackexchange.com/questions/70495/ssl-certificate-is-passphrase-necessary-and-how-does-apache-know-it

make_root_certificate() {
    if [[ -z $1 ]]; then
        echo "make_root_certificate: missing parameter(s)" >&2
        echo "usage: make_root_certificate <common_name> [<file_name>]" >&2
        echo "example: make_root_certificate 'My Example Root CA'" >&2
        echo "example: make_root_certificate 'My Example Root CA' root" >&2
        return 1
    fi
    local CN=$1
    local FILENAME=$2
    if [[ -z $FILENAME ]]; then
        FILENAME=$(echo "$CN" | sed 's/ //g')
    fi
    openssl genrsa -out $FILENAME.key 2048
    openssl req -x509 -new -nodes -key $FILENAME.key -sha256 -days 3970 -out $FILENAME.crt -subj "/CN=$CN"
}

make_intermediate_certificate() {
    if [[ -z $3 ]]; then
        echo "make_intermediate_certificate: missing parameter(s)" >&2
        echo "usage: make_intermediate_certificate <signing_certificate> <signing_key> <common_name> [<file_name>]" >&2
        echo "example: make_intermediate_certificate root.crt root.key 'My Example Intermediate CA' intermediate" >&2
        return 1
    fi
    local SIGNING_CERT=$1
    local SIGNING_KEY=$2
    local CN=$3
    local FILENAME=$4
    if [[ -z $FILENAME ]]; then
        FILENAME=$(echo "$CN" | sed 's/ //g')
    fi
    cat <<EOF >$FILENAME.cfg
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[dn]
CN = $CN
[extensions]
basicConstraints=critical,@basic_constraints
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
[basic_constraints]
CA=true
EOF
    openssl req -new -nodes -keyout $FILENAME.key -out $FILENAME.csr -config $FILENAME.cfg
    openssl x509 -req -in $FILENAME.csr -CA $SIGNING_CERT -CAkey $SIGNING_KEY -CAcreateserial -out $FILENAME.crt -extensions extensions -extfile $FILENAME.cfg -days 3970
    rm $FILENAME.csr $FILENAME.cfg
}

make_signed_certificate() {
    if [[ -z $3 ]]; then
        echo "make_signed_certificate: missing parameter(s)" >&2
        echo "usage: make_signed_certificate <signing_certificate> <signing_key> <common_name> [<alternative_name> ...]" >&2
        echo "example: make_signed_certificate intermediate.crt intermediate.key example.internal www.example.internal" >&2
        return 1
    fi
    local SIGNING_CERT=$1
    local SIGNING_KEY=$2
    local CN=$3
    local FILENAME=$CN
    cat <<EOF >$FILENAME.cfg
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[dn]
CN = $CN
[extensions]
basicConstraints=critical,@basic_constraints
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
subjectAltName = @alt_names
[basic_constraints]
CA=false
[alt_names]
EOF
    count=1
    shift 2
    for SAN in $@; do
        echo "DNS.$count = $SAN" >> $FILENAME.cfg
        count=$((count + 1))
    done
    openssl req -new -nodes -keyout $FILENAME.key -out $FILENAME.csr -config $FILENAME.cfg
    openssl x509 -req -in $FILENAME.csr -CA $SIGNING_CERT -CAkey $SIGNING_KEY -CAcreateserial -out $FILENAME.crt -extensions extensions -extfile $FILENAME.cfg -days 397
    rm $FILENAME.csr $FILENAME.cfg
}

make_self_signed_certificate() {
    if [[ -z $1 ]]; then
        echo "make_self_signed_certificate: missing parameter(s)" >&2
        echo "usage: make_self_signed_certificate <common_name> [<alternative_name> ...]" >&2
        echo "example: make_self_signed_certificate example.internal www.example.internal" >&2
        return 1
    fi
    local CN=$1
    cat <<EOF >$CN.cfg
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
[dn]
CN = $CN
[req_ext]
subjectAltName = @alt_names
[alt_names]
EOF
    count=1
    for SAN in $@; do
        echo "DNS.$count = $SAN" >> $CN.cfg
        count=$((count + 1))
    done
    openssl req -x509 -newkey rsa:2048 -sha256 -days 397 -nodes -keyout $CN.key -out $CN.crt -config $CN.cfg -extensions req_ext -config $CN.cfg
    rm $CN.cfg
}