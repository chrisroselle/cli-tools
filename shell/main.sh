#!/bin/bash

# get folder that main.sh is in
_DIR="$(dirname "$(readlink -f "$BASH_SOURCE")")"
source $_DIR/env.sh

for f in $_DIR/lib/*.sh; do
  source $f
done

help__() {
    help_aws
    echo
    help_git
    echo
    help_k8s
    echo
    help_misc
    echo
    help_notes
    echo
    help_ssl
    echo
    help_ssl-selfsigned
    echo
    help_wsl
    echo
    help_scripts
}

help_scripts() {
    echo "$_DIR/script/generate_getopt/generate_getopt.py       - generate argument parsing boilerplate for shell scripts and functions"
    echo "$_DIR/script/dedup.py                                 - remove duplicate entries in a file"
}