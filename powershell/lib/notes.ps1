function help-notes() {
    echo "note <name>               - open note with matching name. print possible notes if more than one matches"
    echo "notes <search> ...        - search all notes (case insensitive - multiple terms performs 'and' match)"
    echo "notes-or <search> ...     - search all notes (case insensitive - multiple terms performs 'or' match)"
    echo "new-note <name>           - create a new note"
    echo "new-meeting-note <name>   - create a new meeting note in ${notes}/meeting-note"
    echo "todo                      - open todo list"
}

function note($name) {
    $count = $((where.exe /r $notes "*$name*" 2>$null | Measure-Object -line).Lines)
    if ( $count -eq 0) {
        echo "no note files matching $name found"
    } elseif ( $count -gt 1) {
        where.exe /r $notes "*$name*"
    } else {
        $matches = $(where.exe /r $notes "*$name*")
        np $matches
    }
}

function notes($search) {
    $command = "get-childitem -path $notes -recurse | select-string -pattern '$search'"
    foreach ($arg in $args) {
        $command = "$command | select-string -pattern '$arg'"
    }
    $command = "$command | %{@(`$_.Filename, `$_.Line) -join ':'}"
    invoke-expression $command
}

function notes-or() {
    get-childitem -path $notes -recurse | select-string -pattern $args | %{@($_.Filename, $_.Line) -join ':'}
}

function new-note($name) {
    np "${notes}\${name}.txt"
}

function new-meeting-note($name) {
    $datestring = $(get-date -uformat "%Y-%m-%d")
    np "${notes}\meeting-notes\${datestring}-${name}.txt"
}

function todo() {
    np "${notes}\TODO"
}