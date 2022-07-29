help_k8s() {
    echo "k8s.sh:"
    echo "--shorthand:"
    echo "k             kubectl"
    echo "kuc           kubectl config use-context"
    echo "kgc           kubectl config get-contexts"
    echo "kcc           kubectl config current-context"
    echo "kgp           kubectl get pods"
    echo "---------"
    echo "k_shell                           - launch a shell in a container"
    echo "k_log                             - get the log from a container"
    echo "k_access_log                      - get the istio proxy log from a pod"
    echo "k_nodes                           - print the node that each pod is running on"
    echo "k_images                          - print the image running in each container"
    echo "k_services                        - print summary of virtual services"
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
    [[ -z $context ]] && context="$DEFAULT_KUBE_CONTEXT"
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

_k_params_usage() {
    echo "usage: _k_params
  [-c, --context=CONTEXT]
  [-n, --namespace=NAMESPACE]
  [-A, --all-namespaces]

helper function for optionally adding parameters to kubectl" >&2
}

_k_params() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:n:A" --longoptions "context:,namespace:,all-namespaces,help" -- "$@")
    [[ $? != "0" ]] && { _k_params_usage; return 1; }
    eval set -- "$opts"
    local all context namespace
    while :; do
        case "$1" in
            -A|--all-namespaces) all=y; shift ;;
            -c|--context) context=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            --help) _k_params_usage; return 1 ;;
            --) shift; break ;;
            *) _k_params_usage; return 1 ;;
        esac
    done

    # Function
    local output=""
    [[ -n $context ]] && output+="--context $context"
    [[ -n $namespace ]] && output+=" --namespace $namespace"
    [[ -n $all ]] && output+=" --all-namespaces"
    echo $output
}

_helm_params_usage() {
    echo "usage: _helm_params
  [-c, --context=CONTEXT]
  [-n, --namespace=NAMESPACE]
  [-A, --all-namespaces]

helper function for optionally adding parameters to helm" >&2
}

_helm_params() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:n:A" --longoptions "context:,namespace:,all-namespaces" -- "$@")
    [[ $? != "0" ]] && { _helm_params_usage; return 1; }
    eval set -- "$opts"
    local all context namespace
    while :; do
        case "$1" in
            -A|--all-namespaces) all=y; shift ;;
            -c|--context) context=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            --help) _helm_params_usage; return 1 ;;
            --) shift; break ;;
            *) _helm_params_usage; return 1 ;;
        esac
    done

    # Function
    local output=""
    [[ -n $context ]] && output+="--kube-context $context"
    [[ -n $namespace ]] && output+=" --namespace $namespace"
    [[ -n $all ]] && output+=" --all-namespaces"
    echo $output
}

_k_get_pods_usage() {
    echo "usage: _k_get_pods [OPTIONS] SEARCH [SEARCH ...]
  [-c, --context=CONTEXT]
  [-n, --namespace=NAMESPACE]
  [-A, --all-namespaces]

helper function for getting full name of one or more pods matching search term
each of the following will be searched in order, and if any results are found the
result will be returned and no further search will occur
 - exact match of '.metadata.name'
 - exact match of '.metadata.labels.app'
 - contains match of '.metadata.name'" >&2
}

_k_get_pods() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:n:A" --longoptions "context:,namespace:,all-namespaces,help" -- "$@")
    [[ $? != "0" ]] && { _k_get_pods_usage; return 1; }
    eval set -- "$opts"
    local all context namespace
    while :; do
        case "$1" in
            -A|--all-namespaces) all="-A"; shift ;;
            -c|--context) context=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            --help) _k_get_pods_usage; return 1 ;;
            --) shift; break ;;
            *) _k_get_pods_usage; return 1 ;;
        esac
    done

    # Input Validation
    local params
    params=$(_k_params -c "$context" -n "$namespace" $all) || return 1
    [[ -z "$@" ]] && { _k_get_pods_usage; return 1; }

    # Function
    local output pods test_pod
    output=""
    for search in "$@"; do
        test_pod=$(kubectl get pod $search --ignore-not-found $params)
        [[ -n $test_pod ]] && { output+=" $search"; continue; }
        pods=$(kubectl get pods -o jsonpath="{.items[?(@.metadata.labels.app=='$search')].metadata.name}" $params)
        [[ -n $pods ]] && { output+=" $pods"; continue; }
        pods=$(kubectl get pods -o json $params | jq -r ".items[] |select(.metadata.name |contains(\"$search\")) | .metadata.name" | sed 's/\n/ /g')
        [[ -n $pods ]] && { output+=" $pods"; continue; }
        if [[ -n $all ]]; then
            echo "warn: no pods matching '${search}' found in any namespace" >&2
        elif [[ -n $namespace ]]; then
            echo "warn: no pods matching '${search}' found in '${namespace}' namespace" >&2
        else
            echo "warn: no pods matching '${search}' found in default namespace" >&2
        fi
    done
    if [[ -n $output ]]; then
        # trim the leading space
        echo ${output:1}
        return 0
    else
        echo ""
        return 1
    fi
}

_k_shell_usage() {
    echo "usage: k_shell [OPTIONS] POD
  [-c, --container=CONTAINER]   The container in which to start the shell
  [-i, --index=0]               If multiple pods are returned by the search, the index (starting from 0) of the
                                pod in which to start the shell
  [-m, --command=COMMAND]       If a command is given, the command will be executed in the pod by /bin/sh -c '\$command'
                                If no command is given, then an interactive shell will be provided
  [--context=CONTEXT]
  [-n, --namespace=NAMESPACE]

Launch a shell in a pod

Examples:
    # Launch an interactive shell in pod-name pod in ns-name namespace
    k_shell pod-name -n ns-name

    # execute 'cat /tmp/example.txt' in the 3rd pod-name pod in ns-name namespace
    k_shell pod-name --index 2 -n ns-name --command 'cat /tmp/example.txt'

See Also:
    k_get_pods
    kubectl exec --help" >&2
}

k_shell() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:i:m:n:" --longoptions "command:,container:,context:,index:,namespace:,help" -- "$@")
    [[ $? != "0" ]] && { _k_shell_usage; return 1; }
    eval set -- "$opts"
    local command container context index namespace
    while :; do
        case "$1" in
            -c|--container) container=$2; shift 2 ;;
            --context) context=$2; shift 2 ;;
            -i|--index) index=$2; shift 2 ;;
            -m|--command) command=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            --help) _k_shell_usage; return 1 ;;
            --) shift; break ;;
            *) _k_shell_usage; return 1 ;;
        esac
    done

    # Input Validation
    local pod=$1
    [[ -z $pod ]] && { _k_shell_usage; return 1; }
    local params
    params=$(_k_params -c "$context" -n "$namespace") || return 1

    # Function
    local apods pods kopts
    kopts+=" $params"
    pods=$(_k_get_pods -c "$context" -n "$namespace" $pod)
    apods=($pods)
    if [[ -z $index ]]; then
        index=0
        (( ${#apods[@]} > 1 )) && echo "k_shell: connecting to ${apods[$index]} (pod $((index + 1)) of ${#apods[@]})" >&2
    fi
    if ((index > $((${#apods[@]} - 1)))); then
        echo "k_shell: error - requested index ${index} but there are only ${#apods} pods" >&2
        return 1
    fi
    [[ -n $container ]] && kopts+=" -c $container"
    [[ -z $command ]] && kopts+=" --stdin --tty"
    if [[ -n $command ]]; then
        kubectl exec ${apods[$index]} $kopts -- /bin/sh -c "$command"
    else
        kubectl exec ${apods[$index]} $kopts -- /bin/sh
    fi
}

_k_log_usage() {
    echo "usage: k_log [OPTIONS] POD ...
  [-c, --container=CONTAINER]   The container whose log you wish to pull
                                    if no container is provided, the value of '.metadata.labels.app' from pod is used
  [--no-open]                   Do not open the log in editor after pulling
  [-o,--output-dir=\$sre_out]   The directory to write the log to
  [-p,--previous]               Get the log of the previous pod instead of the current one
                                    useful if the pod is in a crash loop
  [-s,--since=SINCE]            Only include logs from the time frame specified
  [--context=CONTEXT]
  [-n, --namespace=NAMESPACE]

Pull a container log for one or more pods and write to local storage
Optionally open the log using \$CLI_EDITOR or vi if \$CLI_EDITOR is not defined

Examples:
    # Get the app log for all pod-name pods
    k_log -n ns-name pod-name

    # Get the istio sidecar log from only the last hour for a single pod
    k_log --container istio-proxy --since 1h -n ns-name pod-name-55f4dcf68-czcmk

    # Get the log for multiple pods without opening
    k_log -n ns-name --no-open pod-name another-pod-name

See Also:
    k_get_pods
    kubectl logs --help" >&2
}

k_log() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:n:o:ps:" --longoptions "container:,context:,no-open,output-dir:,previous,namespace:,since:,help" -- "$@")
    [[ $? != "0" ]] && { _k_log_usage; return 1; }
    eval set -- "$opts"
    local container context namespace output_dir previous since
    local open="true"
    local output_dir="$sre_out"
    local previous="false"
    while :; do
        case "$1" in
            -c|--container) container=$2; shift 2 ;;
            --context) context=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            --no-open) open="false"; shift ;;
            -o|--output-dir) output_dir="$2"; shift 2 ;;
            --previous) previous="true"; shift ;;
            -s|--since) since="$2"; shift 2 ;;
            --help) _k_log_usage; return 1 ;;
            --) shift; break ;;
            *) _k_log_usage; return 1 ;;
        esac
    done

    # Input Validation
    if [[ ! -d $output_dir ]]; then
        echo "no such directory '$output_dir'" >&2
        return 1
    fi
    local pods="$@"
    [[ -z $pods ]] && { _k_log_usage; return 1; }
    local params
    params=$(_k_params -c "$context" -n "$namespace") || return 1

    # Function
    local _container _pod _pods _previous pod
    [[ -n $since ]] && since="--since $since"
    [[ $previous == "true" ]] && _previous="--previous"
    local _container _pod _pods pod
    for pod in $pods; do
        _pods=$(_k_get_pods -c "$context" -n "$namespace" $pod)
        for _pod in $_pods; do
            if [[ -n $container ]]; then
                _container="$container"
            else
                _container="$(kubectl get pod $_pod $params -o jsonpath='{.metadata.labels.app}')"
                if [[ -z $_container ]]; then
                    _container="$(kubectl get pod $pod $params -o jsonpath='{.spec.containers[0].name}')"
                fi
            fi
            kubectl logs $_pod --container $_container $_previous $since $params > "${output_dir}/${_pod}_${_container}.log" && echo "wrote ${output_dir}/${_pod}_${_container}.log"
            if [[ $open == "true" ]]; then
                if [[ -n $CLI_EDITOR ]]; then
                    $CLI_EDITOR "${output_dir}/${_pod}_${_container}.log"
                else
                    vi "${output_dir}/${_pod}_${_container}.log"
                fi
            fi
        done
    done
}

k_access_log() {
    k_log "$@" --container istio-proxy
}

k_nodes() {
    local namespace="$1"
    if [[ -z $namespace ]]; then
        namespace="-A"
    else
        namespace="-n $namespace"
    fi
    kubectl get pods -o jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.spec.nodeName}{'\n'}" $namespace | column -t
}

_k_apps_usage() {
    echo "usage: _k_apps
  [--istio-only]                only include namespaces with istio injection enabled
  [-c, --context=CONTEXT]
  [-n, --namespace=NAMESPACE]
  [-A, --all-namespaces]
  [-t, --type=list]             return type (list or table)

get all deployments" >&2
}

_k_apps() {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:n:t:A" --longoptions "context:,istio-only,namespace:,all-namespaces,type:,help" -- "$@")
    [[ $? != "0" ]] && { _k_apps_usage; return 1; }
    eval set -- "$opts"
    local all context namespace
    local istio_only="false"
    local type="table"
    while :; do
        case "$1" in
            --istio-only) istio_only="true"; shift ;;
            -A|--all-namespaces) all="-A"; shift ;;
            -c|--context) context=$2; shift 2 ;;
            -n|--namespace) namespace=$2; shift 2 ;;
            -t|--type) type=$2; shift 2 ;;
            --help) _k_apps_usage; return 1 ;;
            --) shift; break ;;
            *) _k_apps_usage; return 1 ;;
        esac
    done

    # Input Validation
    [[ -z $namespace && -z $all ]] && { _k_apps_usage; return 1; }


    # Function
    local namespaces
    if [[ -n $all && $istio_only == "true" ]]; then
        namespaces=$(kubectl get namespace -o jsonpath='{.items[?(@.metadata.labels.istio-injection=="enabled")].metadata.name}')
    elif [[ -n $namespace ]]; then
        namespaces="$namespace"
    else
        namespaces=$(kubectl get namespace -o jsonpath='{.items[*].metadata.name}')
    fi
    local params
    if [[ $type != "list" ]]; then
        {
            for ns in $namespaces; do
                params=$(_k_params -c "$context" -n "$ns") || return 1
                kubectl get deployment -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\n'}{end}" $params
            done
        } | column -t
    else
        for ns in $namespaces; do
            params=$(_k_params -c "$context" -n "$ns") || return 1
            kubectl get deployment -o jsonpath="{range .items[*]}{.metadata.namespace}{':'}{.metadata.name}{' '}{end}" $params
        done
    fi
}

_k_images_usage() {
    echo "usage: k_images [OPTIONS]

  [-i,--init-containers]           Print init containers instead of containers
  [-c,--context=CONTEXT]           Kubectl context, or a space separated list of kubectl contexts if using -a
  [-n,--namespace=NAMESPACE]       Kubernetes namespace
                                    if no namespace is provided, all namespaces are printed
  [-a,--application=APPLICATION]   Look at one application across multiple contexts
  [-f,--image-filter=FILTER]       A space separated list of images to filter out of the results

Print images of each container

Examples:
    k_images
    k_images -n ns-name
    k_images -a deployment-name -n ns-name
    k_images -n ns-name -f 'istio-proxy my-sidecar-image'" >&2
}

k_images()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "ic:n:a:f:" --longoptions "all,init-containers,context:,namespace:,application:,image-filter:,help" -- "$@")
    [[ $? != "0" ]] && { _k_images_usage; return 1; }
    eval set -- "$opts"
    local application context namespace image_filter
    local all_images="false"
    local init_containers="false"
    while :; do
        case "$1" in
            -i|--init-containers) init_containers="true"; shift ;;
            -c|--context) context="$2"; shift 2 ;;
            -n|--namespace) namespace="$2"; shift 2 ;;
            -a|--application) application="$2"; shift 2 ;;
            -f|--image-filter) image_filter="$2"; shift 2 ;;
            --all) all_images="true"; shift ;;
            --help) _k_images_usage; return 1 ;;
            --) shift; break ;;
            *) _k_images_usage; return 1 ;;
        esac
    done

    # Input Validation
    [[ -n $1 ]] && { _k_images_usage; return 1; }
    local all_namespaces params
    [[ -z $namespace ]] && all_namespaces="-A"

    # Function
    local filter="column -t"
    if [[ -n "$image_filter" ]]; then
        local i
        for i in $image_filter; do
            filter+=" | grep -v '$i'"
        done
    fi
    local selection=".spec.containers[]?"
    [[ $init_containers == "true" ]] && selection=".spec.initContainers[]?"
    if [[ -n $application ]]; then
        [[ -z $context ]] && { _k_images_usage; return 1; }
        for ctx in $context; do
            params=$(_k_params -c "$ctx" -n "$namespace" $all_namespaces) || return 1
            echo -e "\n$ctx:"
            (
                echo -e "Pod\tContainer\tImage"
                kubectl get pods $params -o json | jq -r "
                    .items[]
                    | select(.metadata.labels.app != null)
                    | select(.metadata.labels.app | contains(\"$application\"))
                    | . as \$root
                    | $selection
                    | \$root.metadata.name + \"\t\" + .name + \"\t\"+ .image
                "
            ) | eval $filter
        done
    else
        params=$(_k_params -c "$context" -n "$namespace" $all_namespaces) || return 1
        (
            echo -e "Pod\tContainer\tImage"
            kubectl get pods $params -o json | jq -r "
                .items[]
                | . as \$root
                | $selection
                | \$root.metadata.name + \"\t\" + .name + \"\t\" + .image
            "
        ) | eval $filter
    fi
}

_k_services_usage() {
    echo "usage: k_services [OPTIONS]

  [-c,--context=CONTEXT]           Kubectl context, or a space separated list of kubectl contexts if using -a or -u
  [-a,--application=APPLICATION]   Look at one application across multiple contexts
  [-u,--url=URL]                   Look at specific url pattern across multiple contexts

Print all virtual service configurations

Examples:
    k_services
    k_services -a deployment-name
    k_services -u /path

See Also:
    https://istio.io/latest/docs/reference/config/networking/virtual-service/" >&2
}

k_services()  {
    # Input Parsing
    local opts
    opts=$(getopt --options "c:a:u:" --longoptions "context:,application:,url:,help" -- "$@")
    [[ $? != "0" ]] && { _k_services_usage; return 1; }
    eval set -- "$opts"
    local application context url
    while :; do
        case "$1" in
            -c|--context) context="$2"; shift 2 ;;
            -a|--application) application="$2"; shift 2 ;;
            -u|--url) url="$2"; shift 2 ;;
            --help) _k_services_usage; return 1 ;;
            --) shift; break ;;
            *) _k_services_usage; return 1 ;;
        esac
    done

    # Input Validation
    local all_namespaces params
    all_namespaces="-A"
    [[ -n $1 ]] && { _k_services_usage; return 1; }

    # Function
    if [[ -n $application ]]; then
        [[ -z $context ]] && { _k_services_usage; return 1; }
        for ctx in $context; do
            params=$(_k_params -c "$ctx" -n "" $all_namespaces) || return 1
            echo -e "\n$ctx:"
            (
                echo -e "VS Name\tGateway\tURL [-> Rewrite]\tDestination"
                kubectl get virtualservice $params -o json | python -c "
import json
import sys

vs = json.load(sys.stdin)
for i in vs['items']:
    name = i['metadata']['name']
    if not '$application' in name:
        continue
    for gateway in i['spec']['gateways']:
        for http in i['spec']['http']:
            if 'rewrite' in http:
                rewrite = f' -> {http[\"rewrite\"][\"uri\"]}'
            else:
                rewrite = ''
            if 'redirect' in http:
                destination = f'redirect to {http[\"redirect\"][\"uri\"]}'
            else:
                destination = http['route'][0]['destination']['host']
            if 'match' in http:
                for match in http['match']:
                    if 'prefix' in match['uri']:
                        url = f'{match[\"uri\"][\"prefix\"]}{rewrite}'
                    else:
                        url = f'(exact) {match[\"uri\"][\"exact\"]}{rewrite}'
                    print(f'{name}\t{gateway}\t{url}\t{destination}')
            else:
                url = f'/{rewrite}'
                print(f'{name}\t{gateway}\t{url}\t{destination}')
" | sort -k2,3
            ) | column -t -s $'\t'
        done
    elif [[ -n $url ]]; then
        [[ -z $context ]] && { _k_images_usage; return 1; }
        for ctx in $context; do
            params=$(_k_params -c "$ctx" -n "" $all_namespaces) || return 1
            echo -e "\n$ctx:"
            (
                echo -e "VS Name\tGateway\tURL [-> Rewrite]\tDestination"
                kubectl get virtualservice $params -o json | python -c "
import json
import sys

vs = json.load(sys.stdin)
for i in vs['items']:
    name = i['metadata']['name']
    for gateway in i['spec']['gateways']:
        for http in i['spec']['http']:
            if 'rewrite' in http:
                rewrite = f' -> {http[\"rewrite\"][\"uri\"]}'
            else:
                rewrite = ''
            if 'redirect' in http:
                destination = f'redirect to {http[\"redirect\"][\"uri\"]}'
            else:
                destination = http['route'][0]['destination']['host']
            if 'match' in http:
                for match in http['match']:
                    if 'prefix' in match['uri']:
                        if not '$url' in match['uri']['prefix']:
                            continue
                        url = f'{match[\"uri\"][\"prefix\"]}{rewrite}'
                    else:
                        if not '$url' in match['uri']['exact']:
                            continue
                        url = f'(exact) {match[\"uri\"][\"exact\"]}{rewrite}'
                    print(f'{name}\t{gateway}\t{url}\t{destination}')
" | sort -k2,3
            ) | column -t -s $'\t'
        done
    else
        params=$(_k_params -c "$context" -n "" $all_namespaces) || return 1
        (
            echo -e "VS Name\tGateway\tURL [-> Rewrite]\tDestination"
            kubectl get virtualservice $params -o json | python -c "
import json
import sys

vs = json.load(sys.stdin)
for i in vs['items']:
    name = i['metadata']['name']
    for gateway in i['spec']['gateways']:
        for http in i['spec']['http']:
            if 'rewrite' in http:
                rewrite = f' -> {http[\"rewrite\"][\"uri\"]}'
            else:
                rewrite = ''
            if 'redirect' in http:
                destination = f'redirect to {http[\"redirect\"][\"uri\"]}'
            else:
                destination = http['route'][0]['destination']['host']
            if 'match' in http:
                for match in http['match']:
                    if 'prefix' in match['uri']:
                        url = f'{match[\"uri\"][\"prefix\"]}{rewrite}'
                    else:
                        url = f'(exact) {match[\"uri\"][\"exact\"]}{rewrite}'
                    print(f'{name}\t{gateway}\t{url}\t{destination}')
            else:
                url = f'/{rewrite}'
                print(f'{name}\t{gateway}\t{url}\t{destination}')
" | sort -k2,3
        ) | column -t -s $'\t'
    fi
}