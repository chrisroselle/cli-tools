function Check-Exe() {
    if ($LASTEXITCODE -gt 0) {
        throw "last command failed"
    }
}

function IDiff($file1, $file2) {
    &"C:\Program Files\JetBrains\IntelliJ IDEA Community Edition 2020.2.1\bin\idea.bat" diff $file1 $file2
}

function lsf($search) {
    get-command -type function | findstr $search
}

function np() {
    &"C:\Program Files (x86)\Notepad++\notepad++.exe" $args.split(" ")
}

function utc() {
    [datetime]::Now.ToUniversalTime()
}

function Which($command) {
    where.exe $command
}