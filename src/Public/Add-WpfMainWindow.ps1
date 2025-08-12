function Add-WpfMainWindow
{
    <#
.SYNOPSIS
    Create a WPF main window with Header/Sidebar/Body/Footer hosts (or variants) and optionally merge a theme.

.DESCRIPTION
    Loads a built-in XAML template (Default/NoSidebar/HeaderOnly/SinglePane), optionally merges a theme via
    Initialize-WpfApplication (if present), sets basic window properties, and returns an object containing:
      - Window
      - HeaderHost, SidebarHost, BodyHost, FooterHost  (may be $null depending on template)
    You can then inject your views, e.g. Add-WpfHeader -Into $result.HeaderHost ...

.PARAMETER Type
    Default layout to use.
    - Default     : Header + Sidebar + Body + Footer (your posted layout)
    - NoSidebar   : Header + Body + Footer (no sidebar column)
    - HeaderOnly  : Header + Body (footer omitted, no sidebar)
    - SinglePane  : Just a single Body host filling the window

.PARAMETER Title
    Window Title.

.PARAMETER Width
.PARAMETER Height
    Window size in device pixels.

.PARAMETER CenterOnScreen
    Center the window on screen (default: On).

.PARAMETER Topmost
    Keep window on top.

.PARAMETER ShowInTaskbar
    Show in taskbar (default: On).

.PARAMETER IconPath
    Optional .ico/.png file for the Window icon.

.PARAMETER Theme
    Optional theme name (e.g. 'NordBlue'). If Initialize-WpfApplication exists, it will be called
    as: Initialize-WpfApplication -Theme $Theme -Scope Window -Window $win

.PARAMETER ThemePath
    Optional explicit ResourceDictionary path. If provided, Initialize-WpfApplication will be called as:
    Initialize-WpfApplication -ThemePath $ThemePath -Scope Window -Window $win

.PARAMETER Show
    Immediately show the window with ShowDialog().

.PARAMETER PassThru
    Return the object (Window + host refs). Returned regardless of -Show, so you can further manipulate.
#>
    [CmdletBinding()]
    param(
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
        [string]$IconPath,

        [Parameter()]
        [string]$Theme,

        [Parameter()]
        [string]$ThemePath,

        [Parameter()]
        [switch]$Show,

        [Parameter()]
        [switch]$PassThru
    )

    # --- Ensure WPF bits are around ---
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
        # Fallback minimal set
        Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml
    }

    # --- Templates ---
    $xamlDefault = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Width="$Width" Height="$Height"
        WindowStartupLocation="CenterScreen"
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

    # --- Load XAML ---
    [xml]$xml = $xaml
    $win = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]$xml)

    # --- Theme merge if requested (Window scope) ---
    if ((Get-Command Initialize-WpfApplication -ErrorAction SilentlyContinue))
    {
        if ($ThemePath)
        {
            Initialize-WpfApplication -ThemePath $ThemePath -Scope Window -Window $win | Out-Null
        }
        elseif ($Theme)
        {
            Initialize-WpfApplication -Theme $Theme -Scope Window -Window $win | Out-Null
        }
    }

    # --- Apply basic properties ---
    $win.Topmost = [bool]$Topmost
    $win.ShowInTaskbar = [bool]$ShowInTaskbar
    if (-not $CenterOnScreen.IsPresent -or $CenterOnScreen)
    {
        $win.WindowStartupLocation = 'CenterScreen'
    }

    if ($IconPath -and (Test-Path -LiteralPath $IconPath))
    {
        try
        {
            $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bi.BeginInit()
            $bi.UriSource = [Uri]$IconPath
            $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bi.EndInit()
            $bi.Freeze()
            $win.Icon = $bi
        }
        catch
        {

        }
    }

    # --- Collect host references (may be $null in some templates) ---
    $out = [pscustomobject]@{
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
        return $out
    }
}
