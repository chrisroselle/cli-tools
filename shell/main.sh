#!/bin/bash

# get folder that main.sh is in
_DIR="$(dirname "$(readlink -f "$BASH_SOURCE")")"
source $_DIR/env.sh

for f in $_DIR/lib/*.sh; do
  source $f
done
