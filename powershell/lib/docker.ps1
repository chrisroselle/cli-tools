function docker-cli-tools($data = $tmp, $command = $null) {
    # ensure bash_history exists
    $null | out-file -encoding ascii -append ${HOME}\.bash_history_docker
    if ($null -eq $command) {
        docker run -it `
            --mount "type=bind,source=${PSScriptRoot}\..\..,target=/cli-tools" `
            --mount "type=bind,source=${data},target=/data" `
            --mount "type=bind,source=${notes},target=/notes" `
            #--mount "type=bind,source=${HOME}\.ssh,target=/root/.ssh" `
            #--mount "type=bind,source=${HOME}\.kube,target=/root/.kube" `
            #--mount "type=bind,source=${HOME}\.aws,target=/root/.aws" `
            --mount "type=bind,source=${HOME}\.bash_history_docker,target=/root/.bash_history" `
            chrisroselle/cli-tools:latest
    } else {
        docker run -it `
            --mount "type=bind,source=${PSScriptRoot}\..\..,target=/cli-tools" `
            --mount "type=bind,source=${data},target=/data" `
            --mount "type=bind,source=${notes},target=/notes" `
            #--mount "type=bind,source=${HOME}\.ssh,target=/root/.ssh" `
            #--mount "type=bind,source=${HOME}\.kube,target=/root/.kube" `
            #--mount "type=bind,source=${HOME}\.aws,target=/root/.aws" `
            --mount "type=bind,source=${HOME}\.bash_history_docker,target=/root/.bash_history" `
            chrisroselle/cli-tools:latest /bin/bash -c "$command"
    }
}

set-alias -name docker-cr -value docker-cli-tools
