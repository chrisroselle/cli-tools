#!/bin/bash

read_csr() {
    if [[ -z $1 ]]; then
        echo "read_csr: missing parameter(s)" >&2
        echo "usage: read_csr <csr_file>" >&2
        echo "example: read_csr mydomain.com.csr" >&2
        return 1
    fi
    openssl req -text -noout -verify -in $1
}

read_pem() {
    if [[ -z $1 ]]; then
        echo "read_pem: missing parameter(s)" >&2
        echo "usage: read_pem <pem_encoded_certificate>" >&2
        echo "example: read_pem certificate.pem" >&2
        return 1
    fi
    openssl x509 -in $1 -text -noout
}

read_p12() {
    if [[ -z $2 ]]; then
        echo "read_p12: missing parameter(s)" >&2
        echo "usage: read_p12 <pkcs12_encoded_certificate> <password>" >&2
        echo "example: read_p12 certificate.p12 mypassword" >&2
        return 1
    fi
    read_pkcs12 $@
}

read_pfx() {
    if [[ -z $2 ]]; then
        echo "read_pfx: missing parameter(s)" >&2
        echo "usage: read_pfx <pkcs12_encoded_certificate> <password>" >&2
        echo "example: read_pfx certificate.p12 mypassword" >&2
        return 1
    fi
    read_pkcs12 $@
}

read_pkcs12() {
    if [[ -z $2 ]]; then
        echo "read_pkcs12: missing parameter(s)" >&2
        echo "usage: read_pkcs12 <pkcs12_encoded_certificate> <password>" >&2
        echo "example: read_pkcs12 certificate.p12 mypassword" >&2
        return 1
    fi
    local P12=$1
    local PASS=$2
    openssl pkcs12 -info -in "$P12" -passin pass:"$PASS" -nokeys | openssl x509 -text -noout
}

read_crt() {
    if [[ -z $1 ]]; then
        echo "read_crt: missing parameter(s)" >&2
        echo "usage: read_crt <pem_encoded_certificate>" >&2
        echo "example: read_crt certificate.crt" >&2
        return 1
    fi
    read_pem $1
}

read_der() {
    if [[ -z $1 ]]; then
        echo "read_der: missing parameter(s)" >&2
        echo "usage: read_der <der_encoded_certificate>" >&2
        echo "example: read_der certificate.der" >&2
        return 1
    fi
    openssl x509 -in $1 -inform der -text -noout
}

check_tls10() {
    if [[ -z $1 ]]; then
        echo "check_tls10: missing parameter(s)" >&2
        echo "usage: check_tls10 <host:port>" >&2
        echo "example: check_tls10 google.com:443" >&2
        return 255
    fi
    local SERVER=$1
    openssl s_client -connect $SERVER -tls1
}

check_tls11() {
    if [[ -z $1 ]]; then
        echo "check_tls11: missing parameter(s)" >&2
        echo "usage: check_tls11 <host:port>" >&2
        echo "example: check_tls11 google.com:443" >&2
        return 255
    fi
    local SERVER=$1
    openssl s_client -connect $SERVER -tls1_1
}

check_tls12() {
    if [[ -z $1 ]]; then
        echo "check_tls12: missing parameter(s)" >&2
        echo "usage: check_tls12 <host:port>" >&2
        echo "example: check_tls12 google.com:443" >&2
        return 255
    fi
    local SERVER=$1
    openssl s_client -connect $SERVER -tls1_2
}

get_certificate() {
    if [[ -z $1 ]]; then
        echo "get_certificate: missing parameter(s)" >&2
        echo "usage: get_certificate <host:port>" >&2
        echo "example: get_certificate myserver.example.com:443" >&2
        return 1
    fi
    local SERVER=$1
    openssl s_client -connect $SERVER </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${SERVER%:*}.crt
}

get_certificate_sni() {
    if [[ -z $1 ]]; then
        echo "get_certificate_sni: missing parameter(s)" >&2
        echo "usage: get_certificate_sni <host:port>" >&2
        echo "example: get_certificate_sni myserver.example.com:443" >&2
        return 1
    fi
    local SERVER=$1
    openssl s_client -servername ${SERVER%:*} -connect $SERVER </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${SERVER%:*}.crt
}

get_expiration_pem() {
    if [[ -z $1 ]]; then
        echo "get_expiration_pem: missing parameter(s)" >&2
        echo "usage: get_expiration_pem <pem_encoded_certificate>" >&2
        echo "example: get_expiration_pem certificate.crt" >&2
        return 1
    fi
    local CRT=$1
    local tmp
    tmp=$(openssl x509 -enddate -noout -in $CRT) || return 1
    tmp="${tmp#*=}"
    date -d "$tmp" '+%Y-%m-%d'
}

get_san_pem() {
    if [[ -z $1 ]]; then
        echo "get_san_pem: missing parameter(s)" >&2
        echo "usage: get_san_pem <pem_encoded_certificate>" >&2
        echo "example: get_san_pem certificate.crt" >&2
        return 1
    fi
    local CRT=$1
    openssl x509 -ext subjectAltName -noout -in $CRT | tail -n -1 | sed 's/, DNS:/ /g' | sed 's/\s*DNS://'
}