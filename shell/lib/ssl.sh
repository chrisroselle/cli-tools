#!/bin/bash

__ssl_get_format_usage() {
    echo "usage: _ssl_get_format [OPTIONS] CERTIFICATE

  CERTIFICATE   The certificate to check

Get SSL Certificate format

Examples:
    _ssl_get_format certificate.crt" >&2
}

_ssl_get_format()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "" --longoptions "help" -- "$@")
    [[ $? != "0" ]] && { __ssl_get_format_usage; return 1; }
    eval set -- "$opts"
    while :; do
        case "$1" in
            --help) __ssl_get_format_usage; return 1 ;;
            --) shift; break ;;
            *) __ssl_get_format_usage; return 1 ;;
        esac
    done
    local certificate="$1"

    # Input Validation
    [[ -z "$certificate" ]] && { __ssl_get_format_usage; return 1; }

    # Function
    openssl x509 -in "$certificate" -noout >/dev/null 2>&1 && {
        echo "pem"
        return 0
    }
    openssl x509 -in "$certificate" -inform der -noout >/dev/null 2>&1 && {
        echo "der"
        return 0
    }
    openssl pkcs7 -in "$certificate" -noout >/dev/null 2>&1 && {
        echo "pkcs7"
        return 0
    }
    openssl req -text -noout -verify -in "$certificate" >/dev/null 2>&1 && {
        echo "csr"
        return 0
    }
    local pkcs12=$(openssl pkcs12 -info -in "$certificate" -passin pass:wrong -nokeys 2>&1 | tail -n 1)
    [[ $pkcs12 == "Mac verify error: invalid password?" ]] && {
        echo "pkcs12"
        return 0
    }
    local jks=$(keytool -list -keystore "$certificate" -storetype jks -storepass wrong)
    [[ $jks == "keytool error: java.io.IOException: Keystore was tampered with, or password was incorrect" ]] && {
        echo "jks"
        return 0
    }
    echo "unable to infer type of '$certificate'" >&2
    return 1
}

_ssl_read_usage() {
    echo "usage: ssl_read [OPTIONS] [CERTIFICATE]

  CERTIFICATE                The certificate to read

Options:
  [-a,--alias=ALIAS]         (JKS only) The alias of the certificate within the keystore
  [-n,--sni]                 Use SNI when connecting to server
  [-p,--password=PASSWORD]   (JKS or PKCS12 only) The password to the certificate or keystore
  [-s,--server=SERVER]       Instead of reading CERTIFICATE, pull certificate from specified server in
                             the format <host>[:<port>]. If no port is provided, 443 will be used

Alternative Output Formats:
  [--expiration]             Print the expiration date only
  [--san]                    Print the subject alternative names only

Read certificate and print details to console

Examples:
    ssl_read certificate.crt
    ssl_read -s google.com
    ssl_read certificate.p12 -p myPassword
    ssl_read certificate.jks -a myAlias -p myPassword

See Also:
    ssl_get_certificate" >&2
}

ssl_read()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "a:np:s:" --longoptions "alias:,expiration,password:,san,server:,sni,help" -- "$@")
    [[ $? != "0" ]] && { _ssl_read_usage; return 1; }
    eval set -- "$opts"
    local alias expiration password san server sni
    while :; do
        case "$1" in
            --expiration) expiration="true"; shift ;;
            --san) san="true"; shift ;;
            -a|--alias) alias="$2"; shift 2 ;;
            -n|--sni) sni="true"; shift ;;
            -p|--password) password="$2"; shift 2 ;;
            -s|--server) server="$2"; shift 2 ;;
            --help) _ssl_read_usage; return 1 ;;
            --) shift; break ;;
            *) _ssl_read_usage; return 1 ;;
        esac
    done
    local certificate="$1"

    # Input Validation
        [[ -z $certificate && -z $server ]] && { _ssl_read_usage; return 1; }
        [[ -n $san && -n $expiration ]] && {
            echo "only one of --san and --expiration can be used" >&2
            return 1
        }
        [[ -n $certificate && ! -f $certificate ]] && {
            echo "no such file '$certificate'" >&2
            return 1
        }
        [[ -n $sni ]] && sni="--sni"
        [[ -n $server ]] && certificate="/tmp/tmp.crt"

        # Function
        [[ -n $server ]] && ssl_get_certificate $sni $server -o "$certificate"
        local format
        format=$(_ssl_get_format "$certificate") || return 1
        [[ $format == "csr" && (-n $san || -n $expiration) ]] && {
            echo "alternative formats cannot be used for CSRs" >&2
            return 1
        }
        local process="-text"
        [[ -n $san ]] && process="-ext subjectAltName | tail -n -1 | sed 's/, DNS:/ /g' | sed 's/\s*DNS://'"
        [[ -n $expiration ]] && process="-enddate | cut -d '=' -f 2 | date '+%Y-%m-%d' -f -"
        local command
        case $format in
            csr) command="openssl req -noout -verify -in '$certificate'" ;;
            der) command="openssl x509 -in '$certificate' -inform der -noout" ;;
            jks)
                [[ -z $alias ]] && {
                    echo "must provide -a/--alias for JKS" >&2
                    return 1
                }
                [[ -z $password ]] && password="changeit"
                command="keytool -exportcert -rfc -alias '$alias' -keystore '$certificate' -storepass '$password' | openssl x509 -noout"
                ;;
            pem) command="openssl x509 -in '$certificate' -noout" ;;
            pkcs7) command="openssl pkcs7 -in '$certificate' -print_certs | openssl x509 -noout" ;;
            pkcs12) command="openssl pkcs12 -info -in '$certificate' -passin pass:'$password' -nokeys 2>/dev/null | openssl x509 -noout" ;;
        esac
        eval "$command $process"
}

_ssl_check_usage() {
    echo "usage: ssl_check [OPTIONS] SERVER

  SERVER           The server to connect to in the format <host>[:<port>]. If no port is provided, 443 will be used
  [-0,--tls-1-0]   Check TLS 1.0
  [-1,--tls-1-1]   Check TLS 1.1
  [-2,--tls-1-2]   Check TLS 1.2
  [-3,--tls-1-3]   Check TLS 1.3

Check whether server accepts a specific TLS version.

Examples:
    ssl_check -0 google.com
    ssl_check --tls-1-3 192.168.1.15:9000

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

  SERVER                 The server to connect to in the format <host>[:<port>]. If no port is provided, 443 will be used
  [-f,--full-chain]      Get full certificate chain
  [-n,--sni]             Use SNI
  [-o,--output=OUTPUT]   The name of the file to output to. If no name is provided, <server>.crt will be used

Get SSL Certificate from remote server

Examples:
    ssl_get_certificate google.com

See Also:
    reference" >&2
}

ssl_get_certificate()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "fno:" --longoptions "full-chain,output:,sni,help" -- "$@")
    [[ $? != "0" ]] && { _ssl_get_certificate_usage; return 1; }
    eval set -- "$opts"
    local full_chain output sni
    while :; do
        case "$1" in
            -f|--full-chain) full_chain="true"; shift ;;
            -n|--sni) sni="true"; shift ;;
            -o|--output) output="$2"; shift 2 ;;
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
    [[ -z $output ]] && output="${server%:*}.crt"

    # Function
    openssl s_client -connect $server $options </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$output"
}

ssl_keystore_contains_certificate() {
    if [[ -z $2 ]]; then
        echo "ssl_keystore_contains_certificate: missing parameter(s)" >&2
        echo "usage: ssl_keystore_contains_certificate <keystore> <certificate>" >&2
        echo "example: ssl_keystore_contains_certificate keystore.jks trust.crt" >&2
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
