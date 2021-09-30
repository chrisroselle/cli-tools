#!/bin/bash

DIR=$(dirname $0)
source $DIR/../../main.sh

fail() {
    echo "failure: $@" >&2
    RET=$((RET + 1))
}

test_get_format() {
    local f=$1
    local expected=$2
    local type=$(_ssl_get_format $f 2>&1)
    [[ $type != $expected ]] && fail "_ssl_get_format $f: expected '$expected' but got '$type'"
}

test_read() {
    ssl_read "$@" 2>&1 | egrep -q "^        Subject:" || fail "ssl_read $@"
}

test_san() {
    local expected="cr2.example another.example"
    local result=$(ssl_read "$@" --san 2>&1)
    [[ $result != $expected ]] && fail "ssl_read $@ --san: expected '$expected' but got '$result'"
}

test_expiration() {
    local result=$(ssl_read "$@" --expiration 2>&1)
    [[ $result != $EXPECTED_EXPIRATION ]] && fail "ssl_read $@ --expiration: expected '$expected' but got '$result'"
}

RET=0
TESTDIR=/tmp/cli-tools-test-ssl-$RANDOM$RANDOM
mkdir $TESTDIR && cd $TESTDIR || exit 1
EXPECTED_EXPIRATION=$(date -d '397 days' --utc '+%Y-%m-%d')
ssl_make_root_certificate cr.example >/dev/null 2>&1 || fail "ssl_make_root_certificate cr.example"
ssl_make_signed_certificate cr.example.crt cr.example.key cr2.example another.example >/dev/null 2>&1 || fail "ssl_make_signed_certificate cr.example.crt cr.example.key cr2.example another.example"
openssl x509 -outform der -in cr2.example.crt -out cr2.example.der || exit 1
openssl pkcs12 -export -in cr2.example.crt -inkey cr2.example.key -chain -CAfile cr.example.crt -out cr2.example.p12 -password pass: || exit 1
openssl pkcs12 -export -in cr2.example.crt -inkey cr2.example.key -chain -CAfile cr.example.crt -out cr2.example.something.p12 -password pass:something || exit 1
openssl crl2pkcs7 -nocrl -certfile cr2.example.crt -out cr2.example.p7b -certfile cr.example.crt || exit 1
keytool -importcert -noprompt -keystore cr2.example.p12.jks -storepass changeit -alias test -file cr2.example.crt >/dev/null 2>&1 || exit 1
keytool -importcert -noprompt -storetype jks -keystore cr2.example.jks -storepass changeit -alias test -file cr2.example.crt >/dev/null 2>&1 || exit 1

test_get_format cr2.example.der der
test_get_format cr2.example.crt pem
test_get_format cr2.example.p12 pkcs12
test_get_format cr2.example.something.p12 pkcs12
test_get_format cr2.example.p7b pkcs7
test_get_format cr2.example.p12.jks pkcs12
test_get_format cr2.example.jks jks

test_read cr2.example.crt
test_read cr2.example.der
test_read cr2.example.p7b
test_read cr2.example.p12 -p ""
test_read cr2.example.something.p12 -p something
test_read cr2.example.jks -p changeit -a test
test_read cr2.example.p12.jks -p changeit -a test

test_san cr2.example.crt
test_san cr2.example.der
test_san cr2.example.p7b
test_san cr2.example.p12 -p ""
test_san cr2.example.something.p12 -p something
test_san cr2.example.jks -p changeit -a test
test_san cr2.example.p12.jks -p changeit -a test

test_expiration cr2.example.crt
test_expiration cr2.example.der
test_expiration cr2.example.p7b
test_expiration cr2.example.p12 -p ""
test_expiration cr2.example.something.p12 -p something
test_expiration cr2.example.jks -p changeit -a test
test_expiration cr2.example.p12.jks -p changeit -a test

if (( RET > 0 )); then
    echo "$RET test cases failed" >&2
else
    echo "all test cases passed"
fi

rm -r $TESTDIR

exit $RET
