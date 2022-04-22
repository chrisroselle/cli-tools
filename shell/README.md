### To bootstrap (WSL)
```shell
cp shell/env_template_wsl.sh shell/env.sh
# review configuration
vi shell/env.sh
echo "source /path/to/shell/main.sh" >> ~/.bash_profile
```

### To bootstrap (docker/windows)
```shell
cp shell/env_template_docker.sh shell/env.sh
# review configuration
vi shell/env.sh
# see powershell/lib/docker.ps1 for function to launch
```

for list of all functions and scripts run `help__`

style guide: https://google.github.io/styleguide/shellguide.html