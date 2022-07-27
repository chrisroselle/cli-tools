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

ec2() {
    if [[ -z "$1" ]]; then
        aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | .InstanceId + " " + (.Tags[] | select(.Key == "Name")).Value + " " + .State.Name + " " + .NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress'
    else
        aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | .InstanceId + " " + (.Tags[] | select(.Key == "Name")).Value + " " + .State.Name + " " + .NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress' | mgrep "$@"
    fi
}

elb() {
    (
        set +m
        local search=$1
        local elb arn list list_classic
        local threads=8
        if [[ -n $search ]]; then
            list_classic=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | select(.LoadBalancerName | test("'$search'";"i")) | .LoadBalancerName')
            list=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[] | select(.LoadBalancerArns[] | test("'$search'";"i")) | select(.LoadBalancerArns | length > 0) | (.LoadBalancerArns[0] | split("/") | .[2]) + "(" + .TargetGroupName + ")|" + .TargetGroupArn')
        else
            list_classic=$(aws elb describe-load-balancers | jq -r '.LoadBalancerDescriptions[] | .LoadBalancerName')
            list=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[] | select(.LoadBalancerArns | length > 0) | (.LoadBalancerArns[0] | split("/") | .[2]) + "(" + .TargetGroupName + ")|" + .TargetGroupArn')
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
                echo "$elb $(echo "$th" | jq -r '([.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length | tostring) + "/" + (.TargetHealthDescriptions | length | tostring)') $(echo "$th" | jq -r '.TargetHealthDescriptions[] | select(.TargetHealth.State != "healthy") | .Target.Id + "=" + .TargetHealth.State' | sed 's/\n/ /g')" > $tmpdir/$i.out
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

acm-pca_print_cert() {
    local cert_arn="$1"
    if [[ -z $cert_arn || $1 == "--help" ]]; then
        echo "usage: $FUNC_NAME <certificate-arn>" >&2
        echo "example: $FUNC_NAME arn:aws:acm-pca:us-east-1:1234567890:certificate-authority/<uid>/certificate/<uid2>" >&2
        return 1
    fi
    local ca_arn=${cert_arn%/certificate*}
    aws acm-pca get-certificate --certificate-arn $cert_arn --certificate-authority-arn $ca_arn | jq -r '.Certificate' | openssl x590 -text -noout
}

