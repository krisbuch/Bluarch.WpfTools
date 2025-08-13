# --- Setup ---
$project = Split-Path -Parent $PSScriptRoot
. (Join-Path -Path $project -ChildPath "Enum\enum.Themes.ps1")
Import-Module "C:\Users\KRIST\Bluarch\Bluarch.WpfTools\output\module\Bluarch.WpfTools\1.0.0\Bluarch.WpfTools.psm1" -Force

function Start-WpfDefault
{
    Param (
        [string]$Title = "Bluarch",
        [string]$SubTitle = "Powered by PowerShell 7+, WPF & .NET 10.0",
        $Icons = @(
            @{ Icon = 'Github'; ToolTip = 'GitHub'; Click = { Start-Process 'https://github.com/krisbuch' } },
            @{ Icon = 'LinkedIn'; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
        ),
        [switch]$Silent = $false,
        [Themes]$Theme = "DarkSlate"
    )
    function _log([string]$msg, [string]$symbol = '📚', [string]$color = 'Gray')
    {
        if ($Silent)
        {
            return
        }
        if ($haveWriteMsg)
        {
            Write-Msg $symbol $msg -Foreground $color -UseRuntime
        }
        else
        {
            Write-Host $msg -ForegroundColor $color
        }
    }
    try
    {
        Import-Module Bluarch.WpfTools -Force
    }
    catch
    {
        _log "Failed to import module: 'Bluarch.WpfTools'" ❗
        -log "$($_)" ⛔
    }


    Load-WpfAssembly -Preset Standard -Silent:$false

    Set-WpfTheme -Theme $Theme -ReplaceExisting

    $mw = Add-WpfMainWindow -Type Default `
        -Title "Bluarch" `
        -Theme $Theme `
        -ThemeScope Application `
        -ReplaceExisting `
        -PassThru

    Set-WpfWindow -Window $mw.Window `
                -WindowStyle SingleBorderWindow `
                -ShowInTaskbar $true

    $hdr = Add-WpfHeader -Type Advanced `
        -Title $Title `
        -Subtitle $SubTitle `
        -Icons @(
        @{ Icon = 'Github'; ToolTip = 'GitHub'; Click = { Start-Process 'https://github.com/krisbuch' } },
        @{ Icon = 'LinkedIn'; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
    ) `
        -Into $mw.HeaderHost `
        -PassThru

    $ftr = Add-WpfFooter -Into $mw.FooterHost `
        -ShowStatus -Status "Loading..." -ShowProgress `
        -Icons @(
            @{ Icon='Github';   ToolTip='GitHub';   Click={ Start-Process 'https://github.com/krisbuch' } },
            @{ Icon='LinkedIn'; ToolTip='LinkedIn'; Click={ Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
        ) -PassThru
    Set-WpfStatus -Footer $mw.FooterHost -Message "Deploying…" -Level Info `
                -TimeoutSeconds 3 -To 100 -AutoColor -ClearMessageOnCompletion



    $mw.Window.ShowDialog() | Out-Null
}
Start-WpfDefault -Theme DarkSlate
