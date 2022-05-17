#!/bin/bash

fail() {
    local message="$1"
    shift
    echo "-----------
failure for input '$@'" >&2
    echo "$message" >&2
    rcode=$((rcode + 1))
}

testf_pass() {
    test_count=$((test_count + 1))
    local expected="$1"
    shift
    (set -o posix; set | egrep -v "^rcode") > env.before
    "$@" 2>/dev/null >result.txt || { fail "expected script or function to run but it did not" "$@"; rm env.before result.txt; return; }
    [[ $(cat result.txt) != $expected ]] && fail "actual output did not match expected
actual:
$result

expected:
$expected
" "$@"
    (set -o posix; set | egrep -v "^rcode") > env.after
    diff -u <(cat env.before) <(cat env.after) || fail "environment changed after execution" "$@"
    rm env.before env.after result.txt
}

testf_fail() {
    test_count=$((test_count + 1))
    "$@" 2>/dev/null && fail "expected script or function to fail but it did not" "$@"
}

test_count=0
rcode=0

python -m venv test-venv
source test-venv/bin/activate
pip install -r ../requirements.txt

python ../generate_getopt.py ./function.yaml > tmp.sh
sed -i '/implement_me/a \
    echo "example_flag = '\''$example_flag'\''" \
    echo "other_flag = '\''$other_flag'\''" \
    echo "thing = '\''$thing'\''" \
    echo "widget = '\''$widget'\''" \
    echo "input = '\''$input'\''"' tmp.sh

sed -i '/implement_me/d' tmp.sh

source tmp.sh
testf_fail example_function
testf_fail example_function -w testwidget
testf_fail example_function --widget testwidget
testf_fail example_function testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'true'
thing = 'value'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function --example-flag -w testwidget testinput

expected="example_flag = 'false'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function -z -t testthing -w testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function -f --no-other-flag --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function -f -z --thing testthing --widget testwidget testinput testinput2

python ../generate_getopt.py ./function2.yaml > tmp.sh
sed -i '/^    for/i \
    echo "example_flag = '\''$example_flag'\''" \
    echo "other_flag = '\''$other_flag'\''" \
    echo "thing = '\''$thing'\''" \
    echo "widget = '\''$widget'\''"' tmp.sh

sed -i '/implement_me/a \
    echo "input = '\''$input'\''"' tmp.sh

sed -i '/implement_me/d' tmp.sh
source tmp.sh

testf_fail example_function2
testf_fail example_function2 -w testwidget
testf_fail example_function2 --widget testwidget
testf_fail example_function2 testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function2 --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function2 --example-flag -t testthing -w testwidget testinput

expected="example_flag = 'false'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function2 -z -t testthing -w testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" example_function2 -f --no-other-flag --thing testthing --widget testwidget testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'
input = 'testinput2'"
testf_pass "$expected" example_function2 --thing testthing --widget testwidget testinput testinput2

python ../generate_getopt.py ./script.yaml > tmp.sh
sed -i '/implement_me/a \
    echo "example_flag = '\''$example_flag'\''" \
    echo "other_flag = '\''$other_flag'\''" \
    echo "thing = '\''$thing'\''" \
    echo "widget = '\''$widget'\''" \
    echo "input = '\''$input'\''"' tmp.sh

sed -i '/implement_me/d' tmp.sh

chmod 700 tmp.sh

testf_fail ./tmp.sh
testf_fail ./tmp.sh -w testwidget
testf_fail ./tmp.sh --widget testwidget
testf_fail ./tmp.sh testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'true'
thing = 'value'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh --example-flag -w testwidget testinput

expected="example_flag = 'false'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh -z -t testthing -w testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh -f --no-other-flag --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh -f -z --thing testthing --widget testwidget testinput testinput2

python ../generate_getopt.py ./script2.yaml > tmp.sh
sed -i '/^    for/i \
    echo "example_flag = '\''$example_flag'\''" \
    echo "other_flag = '\''$other_flag'\''" \
    echo "thing = '\''$thing'\''" \
    echo "widget = '\''$widget'\''"' tmp.sh

sed -i '/implement_me/a \
    echo "input = '\''$input'\''"' tmp.sh

sed -i '/implement_me/d' tmp.sh

chmod 700 tmp.sh

testf_fail ./tmp.sh
testf_fail ./tmp.sh -w testwidget
testf_fail ./tmp.sh --widget testwidget
testf_fail ./tmp.sh testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh --thing testthing --widget testwidget testinput

expected="example_flag = 'true'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh --example-flag -t testthing -w testwidget testinput

expected="example_flag = 'false'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh -z -t testthing -w testwidget testinput

expected="example_flag = 'true'
other_flag = 'false'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'"
testf_pass "$expected" ./tmp.sh -f --no-other-flag --thing testthing --widget testwidget testinput

expected="example_flag = 'false'
other_flag = 'true'
thing = 'testthing'
widget = 'testwidget'
input = 'testinput'
input = 'testinput2'"
testf_pass "$expected" ./tmp.sh --thing testthing --widget testwidget testinput testinput2

rm tmp.sh
rm -r test-venv

(( rcode > 0 )) && echo "$rcode/$test_count test cases failed" >&2
echo "$((test_count-rcode))/$test_count test cases passed"
exit $rcode
