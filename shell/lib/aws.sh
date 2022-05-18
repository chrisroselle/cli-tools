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

elb() {
    (
        set +m
        local search=$1
        local elb arn list
        local threads=8
        if [[ -n $search ]]; then
            list_classic=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.LoadBalancerName | test("'$search'";"i")) | .LoadBalancerName')
            list=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[] | select(.LoadBalancerArns[] | test("'$search'";"i")) | select(.LoadBalancerArns | length > 0) | (.LoadBalancerArns[0] | split("/") | .[2]) + "(" + .TargetGroupName + ")" + "|" + .TargetGroupArn')
        else
            list_classic=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | .LoadBalancerName')
            list=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[] | select(.LoadBalancerArns | length > 0) | (.LoadBalancerArns[0] | split("/") | .[2]) + "(" + .TargetGroupName + ")" + "|" + .TargetGroupArn')
        fi
        local i=0
        local tmpdir=$(mktemp -d)
        for elb in $list_classic; do
            (
                ih=$(aws elb describe-instance-health --load-balancer $elb)
                echo "$elb $(echo "$ih" | jq -r '([.InstanceStates[] | select(.State == "InService")] | length | tostring) + "/" + (.InstanceStates | length | tostring)') $(echo "$ih" | jq -r '.InstanceStates[] | select(.State != "InService") | .InstanceId + "=" + .State' | sed 's/\n/ /g')" > $tmpdir/$i.out
            ) &
            if (( $(jobs -r -p | wc -l) > $threads )); then
                wait -n
            fi
            i=$((i + 1))
        done
        for tg in $list; do
            (
                elb=${tg%|*}
                tgarn=${tg#*|}
                th=$(aws elbv2 describe-target-health --target-group-arn $tgarn)
                echo "$elb $(echo "$th" | jq -r '([.TargetHealthDescriptions[] | select(.TargetHealth
        .State == "healthy")] | length | tostring) + "/" + (.TargetHealthDescriptions | length | tostring)') $(echo "$th" | jq -r '.TargetHealthDescriptions[] | select(.TargetHealth.State != "healthy") | .Target.Id + "=" + .TargetHealth.State' | sed 's/\n/ /g')" > $tmpdir/$i.out
            ) &
            if (( $(jobs -r -p | wc -l) > $threads )); then
                wait -n
            fi
            i=$((i + 1))
        done
        wait
        
        (
            i=0
            while [[ -f $tmpdir/$i.out ]]; do
                cat $tmpdir/$i.out
                i=$((i + 1))
            done
            rm -rf $tmpdir
        ) | column -t
    )
}