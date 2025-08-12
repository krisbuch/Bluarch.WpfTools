# Load your module & WPF bits
Import-Module Bluarch.WpfTools -Force
Load-WpfAssembly -Preset Standard -Silent

# Create the window with the “Default” template and apply a theme at window scope
$mw = Add-WpfMainWindow -Type Default -Title "Bluarch" -Theme 'NordBlue' -PassThru


# Tilføj header med dynamisk ikonresolution
$null = Add-WpfHeader -Type Simple `
    -Title 'BLUARCH' `
    -Subtitle 'WPF Tools for PowerShell' `
    -Icons @(
        @{ Icon = 'Github';   ToolTip = 'GitHub';   Click = { Start-Process 'https://github.com/krisbuch' } },
        @{ Icon = 'LinkedIn'; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
    ) `
    -Into $mw.HeaderHost

$mw.Window.ShowDialog() | Out-Null
