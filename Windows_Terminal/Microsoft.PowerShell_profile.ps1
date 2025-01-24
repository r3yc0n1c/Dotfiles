oh-my-posh --init --shell pwsh --config "$env:POSH_THEMES_PATH/catppuccin_mocha.omp.json" | Invoke-Expression

# My Alias

function sage_shell {
    Start-Process "C:\Users\rey\AppData\Local\SageMath 9.3\runtime\bin\mintty.exe" -ArgumentList "/bin/bash --login -c '/opt/sagemath-9.3/sage -sh'"
}

function v {
    nvim $args
}

function e {
    explorer $args
}

function py3 {
    python $args
}
