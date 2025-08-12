$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module "C:\Users\KRIST\Bluarch\Bluarch.WpfTools\output\module\Bluarch.WpfTools\1.0.0\Bluarch.WpfTools.psm1" -Force

Load-WpfAssembly -Preset All



$win = New-Object System.Windows.Window
Initialize-WpfApplication -Theme NordBlue -Scope Window -Window $win -SetShutdownOnMainWindowClose
Set-WpfWindow -Title "Bluarch"
$null = Add-WpfHeader -Type Simple `
    -LogoPath (Join-Path $PSScriptRoot 'Assets\Icons\Home.png') `
    -Title 'BLUARCH' `
    -Subtitle 'WPF Tools for PowerShell' `
    -Icons @(
        @{ Icon = [Icons]::Github;   ToolTip = 'GitHub';   Click = { Start-Process 'https://github.com/krisbuch' } },
        @{ Icon = [Icons]::LinkedIn; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
    ) `
    -Into $win -GridRow 0

$win.ShowDialog() | Out-Null
