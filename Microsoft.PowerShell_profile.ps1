# Custom PS Profile inspired from theme - robbyrussell
# Author: r3yc0n1c

# clear startup text
clear

function Write-BranchName () {
    try {
        $branch = git rev-parse --abbrev-ref HEAD

        if ($branch -eq "HEAD") {
            # we're probably in detached HEAD state, so print the SHA
            $branch = git rev-parse --short HEAD
            Write-Host " git:($branch)" -ForegroundColor "red"
        }
        else {
            # we're on an actual branch, so print it
            Write-Host " git:($branch)" -ForegroundColor "blue"
        }
    } catch {
        # we'll end up here if we're in a newly initiated git repo
        Write-Host " git:(no branches yet)" -ForegroundColor "yellow"
    }
}

function prompt {
    $base = "PS "    
    # $path = "($(Get-Location)) "
    $path = "($(((Get-Location) | Get-Item).Name))"
    # $time = "($(Get-Date))"
    # $dt = "($(Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss"))"
    # $userPrompt = "$("(>^-^)>" * ($nestedPromptLevel + 1)) "
    $userPrompt = "(>"

    Write-Host $base -NoNewline -ForegroundColor "red"

    if (Test-Path .git) {
        Write-Host $path -NoNewline -ForegroundColor "green"
        # Write-Host $dt -ForegroundColor "yellow"
        Write-BranchName
    }
    else {
        # we're not in a repo so don't bother displaying branch name/sha
        Write-Host $path -ForegroundColor "green"
        # Write-Host $dt -ForegroundColor "yellow"
    }

    Write-Host $userPrompt -NoNewline -ForegroundColor "red"
    return " "
}

# MY ALIASES
function launchIPython { python -m IPython }
# function execTime { (Measure-Command { echo $args | Out-Default }).ToString() }
# function execTime { Measure-Command {cmd /c $args | Out-Host} }
function launchBash { & 'C:\Program Files\Git\bin\sh.exe' --login }

Set-Alias ipy launchIPython
Set-Alias sh launchBash
# Set-Alias time execTime