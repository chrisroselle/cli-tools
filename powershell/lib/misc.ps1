set-alias -name np -value "C:\Program Files (x86)\Notepad++\notepad++.exe"
set-alias -name grep -value rg
set-alias -name which -value where.exe

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

function utc() {
    [datetime]::Now.ToUniversalTime()
}
