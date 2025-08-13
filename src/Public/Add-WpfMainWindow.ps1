function Add-WpfMainWindow
{
    <#
.SYNOPSIS
    Create a WPF main window with Header/Sidebar/Body/Footer hosts and merge BaseStyles + Theme
    in the correct order (BaseStyles first, then Theme).

.DESCRIPTION
    - Ensures WPF assemblies are loaded and an Application exists (ShutdownMode=OnExplicitShutdown).
    - Merges ResourceDictionaries BEFORE XAML load so StaticResource works:
        1) BaseStyles (if provided)
        2) Theme (by enum name or explicit path)
      Uses Set-WpfTheme if available; otherwise falls back to XamlReader.Load + MergedDictionaries.
    - Loads one of four XAML templates:
        Default, NoSidebar, HeaderOnly, SinglePane
    - Returns a PSCustomObject with Window + named hosts (HeaderHost/SidebarHost/BodyHost/FooterHost).

.PARAMETER Type
    'Default' (Header+Sidebar+Body+Footer),
    'NoSidebar' (Header+Body+Footer),
    'HeaderOnly' (Header+Body),
    'SinglePane' (single Body host)

.PARAMETER Title
.PARAMETER Width
.PARAMETER Height
    Basic window settings.

.PARAMETER CenterOnScreen
    Center the window (default: On).

.PARAMETER Topmost
.PARAMETER ShowInTaskbar

.PARAMETER IconPath
    .ico/.png path for Window.Icon.

.PARAMETER BaseStylesPath
    ResourceDictionary with base styles (merged FIRST at Application scope before XAML).
    Default: "$PSScriptRoot\Themes\BaseStyles.xaml" (if exists)

.PARAMETER Theme
    Logical theme name (your [Themes] enum, e.g. NordBlue, DarkSlate, etc.).
    Resolved as "$PSScriptRoot\Themes\Theme.<Theme>.xaml" when -ThemePath is not provided.

.PARAMETER ThemePath
    Explicit ResourceDictionary path for the theme (overrides -Theme).

.PARAMETER ThemeScope
    Where to merge theme/base:
    - Application : pre-merge only (recommended for StaticResource)  [default]
    - Window      : only merge on window after XAML (overrides)
    - Both        : pre-merge + window-merge (useful for per-window overrides)

.PARAMETER ExtraResourcePaths
    Any additional dictionaries to merge AFTER Theme (you can use ThemeScope to decide where).

.PARAMETER ClearExisting
    Clear existing merged dictionaries (at the chosen scope(s)) before adding.

.PARAMETER ReplaceExisting
    Remove any existing merged dictionaries with the same Source before adding.

.PARAMETER Show
    Show window with ShowDialog() immediately.

.PARAMETER PassThru
    Return object with Window and host references.

.PARAMETER Silent
    Suppress logging output.

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
    param (
        [Parameter()]
        [ValidateSet('Default', 'NoSidebar', 'HeaderOnly', 'SinglePane')]
        [string]$Type = 'Default',

        [Parameter()]
        [string]$Title = 'Bluarch App',

        [Parameter()]
        [int]$Width = 1100,

        [Parameter()]
        [int]$Height = 720,

        [Parameter()]
        [switch]$CenterOnScreen = $true,

        [Parameter()]
        [switch]$Topmost,

        [Parameter()]
        [switch]$ShowInTaskbar = $true,

        [Parameter()]
        [string]$BaseStylesPath,     # default resolved below if not provided

        [Parameter()]
        [Themes]$Theme,              # e.g. NordBlue / DarkSlate / CleanLight / HighContrast / None

        [Parameter()]
        [string]$ThemePath,          # explicit full path (overrides -Theme)

        [Parameter()]
        [ValidateSet('Application', 'Window', 'Both')]
        [string]$ThemeScope = 'Application',

        [Parameter()]
        [string[]]$ExtraResourcePaths,

        [Parameter()]
        [switch]$ClearExisting,

        [Parameter()]
        [switch]$ReplaceExisting,

        [Parameter()]
        [switch]$Show,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [string]$IconPath = (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Favicon\Favicon.ico"),

        [Parameter()]
        [switch]$Silent
    )

    # ---------- helpers ----------
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
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
    function _ok([string]$msg)
    {
        _log $msg '✅' 'Green'
    }
    function _warn([string]$msg)
    {
        _log $msg '⚠️' 'Yellow'
    }
    function _err([string]$msg)
    {
        _log $msg '❗' 'Red'
    }

    function Resolve-AbsolutePath([string]$path)
    {
        if ([string]::IsNullOrWhiteSpace($path))
        {
            return $null
        }
        if (Test-Path -LiteralPath $path)
        {
            return (Resolve-Path -LiteralPath $path).ProviderPath
        }
        if ($PSScriptRoot)
        {
            $try = Join-Path $PSScriptRoot $path
            if (Test-Path -LiteralPath $try)
            {
                return (Resolve-Path -LiteralPath $try).ProviderPath
            }
        }
        return $null
    }

    function Ensure-App
    {
        if ($IsWindows -ne $true)
        {
            throw "WPF is only supported on Windows."
        }
        if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')
        {
            throw "WPF requires STA. Start PowerShell with -STA or use an STA runspace."
        }
        if (Get-Command Load-WpfAssembly -ErrorAction SilentlyContinue)
        {
            Load-WpfAssembly -Preset Standard -Silent | Out-Null
        }
        else
        {
            Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml
        }
        $app = [System.Windows.Application]::Current
        if (-not $app)
        {
            $app = [System.Windows.Application]::new()
        }
        if ($app.Dispatcher.HasShutdownStarted -or $app.Dispatcher.HasShutdownFinished)
        {
            throw "The WPF dispatcher has already shut down in this session. Start a new session."
        }
        $app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
        return $app
    }

    # Fallback XAML-load merge (if Set-WpfTheme not available)
    function Merge-RD-XamlReader
    {
        param(
            [Parameter(Mandatory)][string]$Path,
            [ValidateSet('Application', 'Window')][string]$Scope,
            [System.Windows.Window]$Window,
            [switch]$ReplaceExisting
        )
        $abs = Resolve-AbsolutePath $Path
        if (-not $abs)
        {
            _warn "ResourceDictionary not found: $Path"; return
        }
        try
        {
            $rd = [Windows.Markup.XamlReader]::Load(
                [System.Xml.XmlNodeReader]::new([xml](Get-Content -Raw -LiteralPath $abs))
            )
            $target = if ($Scope -eq 'Application')
            {
                $app = [System.Windows.Application]::Current
                if (-not $app.Resources)
                {
                    $app.Resources = [System.Windows.ResourceDictionary]::new()
                }
                $app.Resources
            }
            else
            {
                if (-not $Window)
                {
                    throw "Merge-RD-XamlReader: -Window is required for Window scope."
                }
                if (-not $Window.Resources)
                {
                    $Window.Resources = [System.Windows.ResourceDictionary]::new()
                }
                $Window.Resources
            }
            if ($ReplaceExisting -and $rd.Source)
            {
                $u = $rd.Source.AbsoluteUri
                $dupes = @($target.MergedDictionaries | Where-Object { $_.Source -and $_.Source.AbsoluteUri -eq $u })
                foreach ($d in $dupes)
                {
                    [void]$target.MergedDictionaries.Remove($d)
                }
            }
            [void]$target.MergedDictionaries.Add($rd)
            _ok "Merged RD ($Scope): $abs"
        }
        catch
        {
            _err "Failed to merge RD '$Path' ($Scope): $($_.Exception.Message)"
        }
    }

    # ---------- ensure app ----------
    $app = Ensure-App

    # Default BaseStyles if not provided (only if file exists)
    if (-not $BaseStylesPath)
    {
        $candidate = Join-Path $PSScriptRoot 'Themes\BaseStyles.xaml'
        if (Test-Path -LiteralPath $candidate)
        {
            $BaseStylesPath = $candidate
        }
    }

    # Resolve theme file if only enum is provided
    if (-not $ThemePath -and $PSBoundParameters.ContainsKey('Theme') -and $Theme -and ($Theme.ToString() -ne 'None'))
    {
        $ThemePath = Join-Path $PSScriptRoot ("Themes\Theme.{0}.xaml" -f $Theme)
    }

    # ---------- PRE-MERGE (Application scope) BEFORE XAML ----------
    if ($ThemeScope -in @('Application', 'Both'))
    {
        if (Get-Command Set-WpfTheme -ErrorAction SilentlyContinue)
        {
            Set-WpfTheme -BaseStylesPath $BaseStylesPath `
                -Theme $Theme `
                -ThemePath $ThemePath `
                -Scope Application `
                -ClearExisting:$ClearExisting `
                -ReplaceExisting:$ReplaceExisting `
                -Silent:$Silent | Out-Null
        }
        else
        {
            if ($ClearExisting)
            {
                $app.Resources.MergedDictionaries.Clear()
            }
            if ($BaseStylesPath)
            {
                _log "Merging BaseStyles (Application scope) BEFORE XAML..."
                Merge-RD-XamlReader -Path $BaseStylesPath -Scope Application -ReplaceExisting:$ReplaceExisting
            }
            if ($ThemePath)
            {
                _log "Merging Theme (Application scope) BEFORE XAML..."
                Merge-RD-XamlReader -Path $ThemePath -Scope Application -ReplaceExisting:$ReplaceExisting
            }
            foreach ($extra in ($ExtraResourcePaths ?? @()))
            {
                Merge-RD-XamlReader -Path $extra -Scope Application -ReplaceExisting:$ReplaceExisting
            }
        }
    }
    # ---------- XAML templates ----------
    $xamlDefault = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Width="$Width" Height="$Height"
        WindowStartupLocation="CenterScreen"
        ThemeMode="Dark"
        Background="{DynamicResource BrushWindowBG}">
    <Grid x:Name="RootGrid">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <ContentControl x:Name="HeaderHost" Grid.Row="0" Grid.ColumnSpan="2"/>
        <ContentControl x:Name="SidebarHost" Grid.Row="1" Grid.Column="0"/>
        <ContentControl x:Name="BodyHost"    Grid.Row="1" Grid.Column="1"/>
        <ContentControl x:Name="FooterHost"  Grid.Row="2" Grid.ColumnSpan="2"/>
    </Grid>
</Window>
"@

    $xamlNoSidebar = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Width="$Width" Height="$Height"
        ThemeMode="Dark"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource BrushWindowBG}">
    <Grid x:Name="RootGrid">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <ContentControl x:Name="HeaderHost" Grid.Row="0"/>
        <ContentControl x:Name="BodyHost"   Grid.Row="1"/>
        <ContentControl x:Name="FooterHost" Grid.Row="2"/>
    </Grid>
</Window>
"@

    $xamlHeaderOnly = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Width="$Width" Height="$Height"
        ThemeMode="Dark"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource BrushWindowBG}">
    <Grid x:Name="RootGrid">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <ContentControl x:Name="HeaderHost" Grid.Row="0"/>
        <ContentControl x:Name="BodyHost"   Grid.Row="1"/>
    </Grid>
</Window>
"@

    $xamlSinglePane = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Width="$Width" Height="$Height"
        ThemeMode="Dark"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource BrushWindowBG}">
    <Grid x:Name="RootGrid">
        <ContentControl x:Name="BodyHost"/>
    </Grid>
</Window>
"@

    switch ($Type)
    {
        'Default'
        {
            $xaml = $xamlDefault
        }
        'NoSidebar'
        {
            $xaml = $xamlNoSidebar
        }
        'HeaderOnly'
        {
            $xaml = $xamlHeaderOnly
        }
        'SinglePane'
        {
            $xaml = $xamlSinglePane
        }
    }

    # ---------- Load XAML now ----------
    try
    {
        [xml]$xml = $xaml
        $win = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]$xml)
    }
    catch
    {
        throw "Failed to load main window XAML: $($_.Exception.Message)"
    }

    # ---------- (Optional) extra/window merges AFTER XAML ----------
    if ($ThemeScope -in @('Window', 'Both'))
    {
        if (Get-Command Set-WpfTheme -ErrorAction SilentlyContinue)
        {
            Set-WpfTheme -BaseStylesPath $BaseStylesPath `
                -Theme $Theme `
                -ThemePath $ThemePath `
                -Scope Window -Window $win `
                -ReplaceExisting:$ReplaceExisting `
                -Silent:$Silent | Out-Null
        }
        else
        {
            if ($BaseStylesPath)
            {
                Merge-RD-XamlReader -Path $BaseStylesPath -Scope Window -Window $win -ReplaceExisting:$ReplaceExisting
            }
            if ($ThemePath)
            {
                Merge-RD-XamlReader -Path $ThemePath -Scope Window -Window $win -ReplaceExisting:$ReplaceExisting
            }
        }
        foreach ($extra in ($ExtraResourcePaths ?? @()))
        {
            Merge-RD-XamlReader -Path $extra -Scope Window -Window $win -ReplaceExisting:$ReplaceExisting
        }
    }

    # ---------- Window props ----------
    $win.Topmost = [bool]$Topmost
    $win.ShowInTaskbar = [bool]$ShowInTaskbar
    if ($CenterOnScreen)
    {
        $win.WindowStartupLocation = 'CenterScreen'
    }

    if ($IconPath)
    {
        $absIcon = Resolve-AbsolutePath $IconPath
        if ($absIcon)
        {
            try
            {
                $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
                $bi.BeginInit()
                $bi.UriSource = [Uri]$absIcon
                $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bi.EndInit()
                $bi.Freeze()
                $win.Icon = $bi
            }
            catch
            {
                _warn "Failed to set window icon: $($_.Exception.Message)"
            }
        }
        else
        {
            _warn "Icon not found: $IconPath"
        }
    }

    # ---------- collect hosts ----------
    $result = [pscustomobject]@{
        Window      = $win
        HeaderHost  = $win.FindName('HeaderHost')
        SidebarHost = $win.FindName('SidebarHost')
        BodyHost    = $win.FindName('BodyHost')
        FooterHost  = $win.FindName('FooterHost')
    }

    if ($Show)
    {
        $null = $win.ShowDialog()
    }

    if ($PassThru -or -not $Show)
    {
        return $result
    }
}
