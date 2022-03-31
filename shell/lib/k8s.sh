help_k8s_cr() {
    echo "k8s.sh:"
    echo "-------shorthand:"
    echo "k             kubectl"
    echo "kuc           kubectl config use-context"
    echo "kgc           kubectl config get-contexts"
    echo "kcc           kubectl config current-context"
    echo "kgp           kubectl get pods"
}

alias k="kubectl"

kgc() {
    kubectl config get-contexts
}

kcc() {
    kubectl config current-context
}

kuc() {
    local context=$1
    [[ -z $context ]] && context="ip-app-dev"
    kubectl config use-context $context
}

kgp() {
    local namespace=$1
    if [[ -z $namespace ]]; then
        kubectl get pods --all-namespaces
    else
        kubectl get pods -n $namespace
    fi
}

