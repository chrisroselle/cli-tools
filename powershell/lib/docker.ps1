function docker-cli-tools($data = $tmp, $command = $null) {
    if ($null -eq $command) {
        docker run -it `
            --mount "type=bind,source=${data},target=/data" `
            --mount "type=bind,source=${notes},target=/notes" `
            --mount "type=bind,source=${tmp},target=/root/tmp" `
            --mount "type=bind,source=${PSScriptRoot}\..\..\shell,target=/scripts" `
            --mount "type=bind,source=${HOME}\.ssh,target=/root/.ssh" `
            chrisroselle/cli-tools:latest
    } else {
        docker run -it `
            --mount "type=bind,source=${data},target=/data" `
            --mount "type=bind,source=${notes},target=/notes" `
            --mount "type=bind,source=${tmp},target=/root/tmp" `
            --mount "type=bind,source=${PSScriptRoot}]\..\..\shell,target=/scripts" `
            --mount "type=bind,source=${HOME}\.ssh,target=/root/.ssh" `
            chrisroselle/cli-tools:latest /bin/bash -c "$command"
    }
}

set-alias -name docker-cr -value docker-cli-tools
