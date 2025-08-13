function Initialize-WpfApplication
{
    <#
.SYNOPSIS
    Ensure a single WPF Application exists (STA), keep it alive across runs, and merge a theme (by name or path).

.DESCRIPTION
    - Reuses Application.Current if present; otherwise creates it.
    - ShutdownMode defaults to OnExplicitShutdown (closing a window won't kill the app),
      or set -SetShutdownOnMainWindowClose to opt into normal dialog behavior.
    - Merges BaseStyles.xaml + one of four built-in themes (DarkSlate, CleanLight, HighContrast, NordBlue),
      or a custom theme path.
    - Prevents duplicates by removing existing ResourceDictionaries with the same Source.
    - Optionally replaces any previous "Theme.*.xaml" + "BaseStyles.xaml" on the target scope.

.PARAMETER Theme
    Named theme to load (ValidateSet). Use 'None' to skip theme load entirely. Ignored if -ThemePath is specified.

.PARAMETER ThemePath
    Custom full path to a ResourceDictionary (overrides -Theme). Useful for your own theme files.

.PARAMETER ThemeRoot
    Folder that contains BaseStyles.xaml and Theme.*.xaml (defaults to "<script folder>\Themes" if not set).

.PARAMETER IncludeBase
    Whether to include BaseStyles.xaml before the chosen theme. Default: $true (use -IncludeBase:$false to skip).

.PARAMETER ReplaceExisting
    Remove any previously merged "Theme.*.xaml" and "BaseStyles.xaml" on the chosen scope before adding new ones.
    Default: $true (use -ReplaceExisting:$false to only dedupe exact same Source).

.PARAMETER Scope
    Where to merge the theme: 'Application' (default) or 'Window'.

.PARAMETER Window
    Target FrameworkElement when using -Scope Window.

.PARAMETER SetShutdownOnMainWindowClose
    If set, uses OnMainWindowClose (typical app behavior). Otherwise default is OnExplicitShutdown.

.PARAMETER PassThru
    Return the Application object and whether it was created by this call.

.EXAMPLE
    Initialize-WpfApplication -Theme DarkSlate

.EXAMPLE
    $win = New-Object System.Windows.Window
    Initialize-WpfApplication -Theme NordBlue -Scope Window -Window $win
    $win.ShowDialog() | Out-Null

.EXAMPLE
    Initialize-WpfApplication -ThemePath "$PSScriptRoot\Themes\MyCustom.xaml" -ReplaceExisting

.EXAMPLE
    # App-scope, BaseStyles + DarkSlate (default) fra .\Themes
    Initialize-WpfApplication

    # App-scope, CleanLight
    Initialize-WpfApplication -Theme CleanLight

    # Window-scope, NordBlue
    $win = New-Object System.Windows.Window
    Initialize-WpfApplication -Theme NordBlue -Scope Window -Window $win
    $win.ShowDialog() | Out-Null

    # App-scope, HighContrast, bevar tidligere dictionaries (kun dedupe nøjagtig samme Source)
    Initialize-WpfApplication -Theme HighContrast -ReplaceExisting:$false

    # Custom theme path + BaseStyles fra ThemeRoot
    Initialize-WpfApplication -ThemePath "$PSScriptRoot\Themes\MyCustom.xaml"

    # Sæt normal dialog-adfærd (luk hovedvindue => afslut app)
    Initialize-WpfApplication -Theme CleanLight -SetShutdownOnMainWindowClose

.NOTES
    📦 CONTENT
    Module     ▹ Bluarch.WpfTools
    Function   ▹ Initialize-WpfApplication
    Version    ▹ 1.0.0
    Published  ▹ 2025-08-12

    🪪 AUTHOR
    Name       ▹ Kristian Holm Buch
    Company    ▹ Bluagentis
    Location   ▹ Copenhagen, Denmark
    GitHub     ▹ https://github.com/krisbuch
    LinkedIn   ▹ https://linkedin.com/in/kristianbuch

    ©️ COPYRIGHT
    Bluarch © 2025 by Kristian Holm Buch. All rights reserved.

    🧾 LICENSE
    Licensed under Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International.
    To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-nd/4.0/

    This license requires that reusers give credit to the creator.
    It allows reusers to copy and distribute the material in any medium or
    format in unadapted form and for noncommercial purposes only.
#>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Themes]$Theme = 'DarkSlate',

        [Parameter()]
        [string]$ThemePath,

        [Parameter()]
        [string]$ThemeRoot,

        [Parameter()]
        [bool]$IncludeBase = $true,

        [Parameter()]
        [bool]$ReplaceExisting = $true,

        [Parameter()]
        [ValidateSet('Application', 'Window')]
        [string]$Scope = 'Application',

        [Parameter()]
        [System.Windows.FrameworkElement]$Window,

        [Parameter()]
        [switch]$SetShutdownOnMainWindowClose,

        [Parameter()]
        [switch]$PassThru
    )

    # --- Must be STA
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')
    {
        throw "WPF requires STA. Start pwsh with -STA or use an STA runspace."
    }

    # --- Get/Create Application
    $app = [System.Windows.Application]::Current
    $created = $false
    if ($null -eq $app)
    {
        $app = [System.Windows.Application]::new()
        $created = $true
    }

    # --- Dispatcher must be alive
    if ($app.Dispatcher.HasShutdownStarted -or $app.Dispatcher.HasShutdownFinished)
    {
        throw "The WPF dispatcher has already shut down in this session. Start a new PowerShell session."
    }

    # --- Shutdown behavior
    $app.ShutdownMode = if ($SetShutdownOnMainWindowClose)
    {
        [System.Windows.ShutdownMode]::OnMainWindowClose
    }
    else
    {
        [System.Windows.ShutdownMode]::OnExplicitShutdown
    }

    # --- Target resources (Application or Window scope)
    $targetRD = if ($Scope -eq 'Window')
    {
        if (-not $Window)
        {
            throw "When -Scope Window is used, you must pass -Window."
        }
        if (-not $Window.Resources)
        {
            $Window.Resources = [System.Windows.ResourceDictionary]::new()
        }
        $Window.Resources
    }
    else
    {
        if (-not $app.Resources)
        {
            $app.Resources = [System.Windows.ResourceDictionary]::new()
        }
        $app.Resources
    }

    # --- Resolve theme root (default: "<script folder>\Themes")
    if (-not $ThemeRoot -or $ThemeRoot.Trim() -eq '')
    {
        $scriptFolder = if ($PSCommandPath)
        {
            Split-Path -Parent $PSCommandPath
        }
        else
        {
            (Get-Location).Path
        }
        $ThemeRoot = Join-Path $scriptFolder 'Themes'
    }

    # --- Build list of dictionaries to add
    $dictPaths = New-Object System.Collections.Generic.List[string]

    # If a custom ThemePath is provided, it wins
    if ($ThemePath)
    {
        if (-not (Test-Path -LiteralPath $ThemePath -PathType Leaf))
        {
            throw "Theme not found: $ThemePath"
        }
        if ($IncludeBase)
        {
            $basePath = Join-Path $ThemeRoot 'BaseStyles.xaml'
            if (Test-Path -LiteralPath $basePath -PathType Leaf)
            {
                [void]$dictPaths.Add((Resolve-Path -LiteralPath $basePath).ProviderPath)
            }
            else
            {
                Write-Verbose "BaseStyles.xaml not found at '$basePath' – skipping base."
            }
        }
        [void]$dictPaths.Add((Resolve-Path -LiteralPath $ThemePath).ProviderPath)
    }
    else
    {
        if ($Theme -ne 'None')
        {
            if ($IncludeBase)
            {
                $basePath = Join-Path $ThemeRoot 'BaseStyles.xaml'
                if (Test-Path -LiteralPath $basePath -PathType Leaf)
                {
                    [void]$dictPaths.Add((Resolve-Path -LiteralPath $basePath).ProviderPath)
                }
                else
                {
                    Write-Verbose "BaseStyles.xaml not found at '$basePath' – skipping base."
                }
            }
            $fileName = switch ($Theme)
            {
                'DarkSlate'
                {
                    'Theme.DarkSlate.xaml'
                }
                'CleanLight'
                {
                    'Theme.CleanLight.xaml'
                }
                'HighContrast'
                {
                    'Theme.HighContrast.xaml'
                }
                'NordBlue'
                {
                    'Theme.NordBlue.xaml'
                }
            }
            if ($fileName)
            {
                $themeFile = Join-Path $ThemeRoot $fileName
                if (-not (Test-Path -LiteralPath $themeFile -PathType Leaf))
                {
                    throw "Theme '$Theme' not found at: $themeFile"
                }
                [void]$dictPaths.Add((Resolve-Path -LiteralPath $themeFile).ProviderPath)
            }
        }
    }

    # Nothing to merge? Exit early.
    if ($dictPaths.Count -eq 0)
    {
        if ($PassThru)
        {
            return [pscustomobject]@{ Application = $app; Created = $created }
        }
        return
    }

    # --- Optional: remove any previously merged Theme.*.xaml / BaseStyles.xaml (ReplaceExisting)
    if ($ReplaceExisting)
    {
        $existing = @($targetRD.MergedDictionaries)
        foreach ($d in $existing)
        {
            try
            {
                if ($d.Source)
                {
                    $name = [System.IO.Path]::GetFileName($d.Source.LocalPath)
                    if ($name -and ($name -like 'Theme.*.xaml' -or $name -ieq 'BaseStyles.xaml'))
                    {
                        [void]$targetRD.MergedDictionaries.Remove($d)
                    }
                }
            }
            catch
            {
            }
        }
    }

    # --- De-dupe exact same Source and add new dictionaries
    foreach ($path in $dictPaths)
    {
        $uri = [System.Uri]::new($path, [System.UriKind]::Absolute)

        # Remove any existing with same AbsoluteUri
        $dupes = @($targetRD.MergedDictionaries | Where-Object {
                $_.Source -and $_.Source.AbsoluteUri -eq $uri.AbsoluteUri
            })
        foreach ($d in $dupes)
        {
            [void]$targetRD.MergedDictionaries.Remove($d)
        }

        $rd = [System.Windows.ResourceDictionary]::new()
        $rd.Source = $uri
        [void]$targetRD.MergedDictionaries.Add($rd)
    }

    if ($PassThru)
    {
        [pscustomobject]@{
            Application = $app
            Created     = $created
        }
    }
}
