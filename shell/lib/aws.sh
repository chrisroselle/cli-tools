#!/bin/bash

agp() {
    echo $AWS_PROFILE $AWS_DEFAULT_REGION
}

asp() {
    export AWS_PROFILE="$1"
    if [[ -n $2 ]]; then
        export AWS_DEFAULT_REGION="$2"
    else
        export AWS_DEFAULT_REGION="us-east-1"
    fi
}

alp() {
    aws configure list-profile
}
