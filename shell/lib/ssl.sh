#!/bin/bash

ssl_read_csr() {
    if [[ -z $1 ]]; then
        echo "read_csr: missing parameter(s)" >&2
        echo "usage: read_csr <csr_file>" >&2
        echo "example: read_csr mydomain.com.csr" >&2
        return 1
    fi
    openssl req -text -noout -verify -in $1
}

ssl_read_pem() {
    if [[ -z $1 ]]; then
        echo "read_pem: missing parameter(s)" >&2
        echo "usage: read_pem <pem_encoded_certificate>" >&2
        echo "example: read_pem certificate.pem" >&2
        return 1
    fi
    openssl x509 -in $1 -text -noout
}

ssl_read_p12() {
    if [[ -z $2 ]]; then
        echo "read_p12: missing parameter(s)" >&2
        echo "usage: read_p12 <pkcs12_encoded_certificate> <password>" >&2
        echo "example: read_p12 certificate.p12 mypassword" >&2
        return 1
    fi
    ssl_read_pkcs12 $@
}

ssl_read_pfx() {
    if [[ -z $2 ]]; then
        echo "read_pfx: missing parameter(s)" >&2
        echo "usage: read_pfx <pkcs12_encoded_certificate> <password>" >&2
        echo "example: read_pfx certificate.p12 mypassword" >&2
        return 1
    fi
    ssl_read_pkcs12 $@
}

ssl_read_pkcs12() {
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

ssl_read_crt() {
    if [[ -z $1 ]]; then
        echo "read_crt: missing parameter(s)" >&2
        echo "usage: read_crt <pem_encoded_certificate>" >&2
        echo "example: read_crt certificate.crt" >&2
        return 1
    fi
    ssl_read_pem $1
}

ssl_read_der() {
    if [[ -z $1 ]]; then
        echo "read_der: missing parameter(s)" >&2
        echo "usage: read_der <der_encoded_certificate>" >&2
        echo "example: read_der certificate.der" >&2
        return 1
    fi
    openssl x509 -in $1 -inform der -text -noout
}

_ssl_check_usage() {
    echo "usage: ssl_check [OPTIONS] SERVER

  SERVER           The server to connect to in the format <host>[:<port>]. If no port is provided, 443 will be used
  [-0,--tls-1-0]   Check TLS 1.0
  [-1,--tls-1-1]   Check TLS 1.1
  [-2,--tls-1-2]   Check TLS 1.2
  [-3,--tls-1-3]   Check TLS 1.3

Check whether server accepts a specific TLS version

Examples:
    ssl_check

See Also:
    reference" >&2
}

ssl_check()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "0123" --longoptions "tls-1-0,tls-1-1,tls-1-2,tls-1-3,help" -- "$@")
    [[ $? != "0" ]] && { _ssl_check_usage; return 1; }
    eval set -- "$opts"
    local tls_1_0 tls_1_1 tls_1_2 tls_1_3
    while :; do
        case "$1" in
            -0|--tls-1-0) tls_1_0="true"; shift ;;
            -1|--tls-1-1) tls_1_1="true"; shift ;;
            -2|--tls-1-2) tls_1_2="true"; shift ;;
            -3|--tls-1-3) tls_1_3="true"; shift ;;
            --help) _ssl_check_usage; return 1 ;;
            --) shift; break ;;
            *) _ssl_check_usage; return 1 ;;
        esac
    done
    local server="$1"

    # Input Validation
    [[ -z $server ]] && { _ssl_check_usage; return 1; }
    echo "$server" | grep -qv ":" && server="$server:443"
    local type
    [[ -n $tls_1_0 ]] && type+=" -tls1"
    [[ -n $tls_1_1 ]] && type+=" -tls1_1"
    [[ -n $tls_1_2 ]] && type+=" -tls1_2"
    [[ -n $tls_1_3 ]] && type+=" -tls1_3"

    # Function
    openssl s_client -connect $server $type < /dev/null
}

_ssl_get_certificate_usage() {
    echo "usage: ssl_get_certificate [OPTIONS] SERVER

  SERVER              The server to connect to in the format <host>[:<port>]. If no port is provided, 443 will be used
  [-f,--full-chain]   Get full certificate chain
  [-n,--sni]          Use SNI

Get SSL Certificate from remote server

Examples:
    ssl_get_certificate

See Also:
    reference" >&2
}

ssl_get_certificate()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "fn" --longoptions "full-chain,sni,help" -- "$@")
    [[ $? != "0" ]] && { _ssl_get_certificate_usage; return 1; }
    eval set -- "$opts"
    local full_chain sni
    while :; do
        case "$1" in
            -f|--full-chain) full_chain="true"; shift ;;
            -n|--sni) sni="true"; shift ;;
            --help) _ssl_get_certificate_usage; return 1 ;;
            --) shift; break ;;
            *) _ssl_get_certificate_usage; return 1 ;;
        esac
    done
    local server="$1"

    # Input Validation
    [[ -z $server ]] && { _ssl_get_certificate_usage; return 1; }
    echo "$server" | grep -qv ":" && server="$server:443"
    local options
    [[ -n $full_chain ]] && options+=" -showcerts"
    [[ -n $sni ]] && options+=" -servername ${server%:*}"

    # Function
    openssl s_client -connect $server $options </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${server%:*}.crt
}

ssl_get_expiration_pem() {
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

ssl_get_san_pem() {
    if [[ -z $1 ]]; then
        echo "get_san_pem: missing parameter(s)" >&2
        echo "usage: get_san_pem <pem_encoded_certificate>" >&2
        echo "example: get_san_pem certificate.crt" >&2
        return 1
    fi
    local CRT=$1
    openssl x509 -ext subjectAltName -noout -in $CRT | tail -n -1 | sed 's/, DNS:/ /g' | sed 's/\s*DNS://'
}