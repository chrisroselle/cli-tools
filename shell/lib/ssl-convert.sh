#!/bin/bash

der2pem() {
    if [[ -z $1 ]]; then
        echo "der2pem: missing parameter(s)" >&2
        echo "usage: der2pem <der_encoded_certificate>" >&2
        echo "example: der2pem certificate.der" >&2
        return 1
    fi
    local DER=$1
    local PEM=${1%.*}.crt
    openssl x509 -inform der -in $DER -out $PEM
}

pem2der() {
    if [[ -z $1 ]]; then
        echo "pem2der: missing parameter(s)" >&2
        echo "usage: pem2der <der_encoded_certificate>" >&2
        echo "example: pem2der certificate.der" >&2
        return 1
    fi
    local PEM=$1
    local DER=${1%.*}.der
    openssl x509 -outform der -in $PEM -out $DER
}

pem2jks() {
    if [[ -z $2 ]]; then
        echo "pem2jks: missing parameter(s)" >&2
        echo "usage: pem2jks <pem_encoded_certificate> <pem_encoded_key> [<ca_chain> <output_file>]" >&2
        echo "example: pem2jks certificate.crt certificate.key" >&2
        return 1
    fi
    local CERT=$1
    local KEY=$2
    local CA_CHAIN=$3
    local KEYSTORE=$4
    if [[ -z $4 ]]; then
        KEYSTORE=keystore.jks
    fi
    pem2pkcs12 $CERT $KEY $CA_CHAIN tmp.p12
    keytool -importkeystore -destkeystore $KEYSTORE -deststoretype jks -deststorepass changeit -srckeystore tmp.p12 -srcstoretype pkcs12 -srcstorepass changeit
    rm tmp.p12
}

pem2pkcs12() {
    if [[ -z $3 ]]; then
        echo "pem2pkcs12: missing parameter(s)" >&2
        echo "usage: pem2pkcs12 <pem_encoded_certificate> <pem_encoded_key> <output_file> [<ca_chain>]" >&2
        echo "example: pem2pkcs12 certificate.crt certificate.key certificate.ca.crt certificate.p12" >&2
        return 1
    fi
    local CERT=$1
    local KEY=$2
    local OUTPUT=$3
    local CA_CHAIN=$4
    if [[ -n $4 ]]; then
        CA="-chain -CAfile $CA_CHAIN"
    fi
    openssl pkcs12 -export -in $CERT -inkey $KEY $CA -name private_key -out $OUTPUT -password pass:changeit
}

pkcs122pem() {
    if [[ -z $1 ]]; then
        echo "pkcs122pem: missing parameter(s)" >&2
        echo "usage: pkcs122pem <pkcs12_encoded_certificate>" >&2
        echo "example: pkcs122pem certificate.p12" >&2
        return 1
    fi
    local P12=$1
    local NAME=${P12%.*}
    openssl pkcs12 -in $P12 -out ${NAME}.ca.crt -cacerts -nokeys
    openssl pkcs12 -in $P12 -out ${NAME}.crt -clcerts -nokeys
    openssl pkcs12 -in $P12 -out ${NAME}.key -nocerts -nodes
}