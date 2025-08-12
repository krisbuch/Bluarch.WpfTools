# Load your module & WPF bits
Import-Module Bluarch.WpfTools -Force
Load-WpfAssembly -Preset Standard -Silent

# Create the window with the “Default” template and apply a theme at window scope
$mw = Add-WpfMainWindow -Type Default -Title "Bluarch" -Theme 'NordBlue' -PassThru

# Inject your header into the HeaderHost
$null = Add-WpfHeader -Type Simple `
    -LogoPath (Join-Path $PSScriptRoot 'Assets\Icons\Home.png') `
    -Title 'BLUARCH' `
    -Subtitle 'WPF Tools for PowerShell' `
    -Icons @(
        @{ Icon = [Icons]::Github;   ToolTip = 'GitHub';   Click = { Start-Process 'https://github.com/krisbuch' } },
        @{ Icon = [Icons]::LinkedIn; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
    ) `
    -Into $mw.HeaderHost

# Show it
$null = $mw.Window.ShowDialog()
