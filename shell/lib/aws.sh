#!/bin/bash

help_aws() {
    echo "aws.sh:"
    echo "--shorthand:"
    echo "asp           export AWS_PROFILE='\$1' AWS_REGION='\$2'"
    echo "agp           echo \$AWS_PROFILE \$AWS_REGION"
    echo "alp           aws configure list-profiles"
}

agp() {
    echo $AWS_PROFILE $AWS_REGION
}

asp() {
    export AWS_PROFILE="$1"
    if [[ -n $2 ]]; then
        export AWS_REGION="$2"
    else
        export AWS_REGION="us-east-1"
    fi
}

alp() {
    aws configure list-profiles
}
