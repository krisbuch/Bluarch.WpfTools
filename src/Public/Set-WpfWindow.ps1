function Set-WpfWindow
{
    <#
.SYNOPSIS
    Configure an existing WPF Window (System.Windows.Window) in a single, idempotent call.

.DESCRIPTION
    Sets common Window properties (title, size, location, style, opacity, fonts, brushes, state, owner, etc.),
    optionally merges one or more ResourceDictionary XAML files at Window scope, optionally loads Content from a XAML file,
    and can set the window icon from a file, a Base64 string, or an ImageSource.
    Also supports hiding Min/Max buttons via Win32 styles after the window handle is created.

.PARAMETER Window
    The Window instance to configure. (Mandatory)

.PARAMETER Title
    Window title text.

.PARAMETER Width
.PARAMETER Height
.PARAMETER MinWidth
.PARAMETER MinHeight
.PARAMETER MaxWidth
.PARAMETER MaxHeight
    Size constraints (device-independent pixels).

.PARAMETER Left
.PARAMETER Top
    Window position (screen coordinates).

.PARAMETER SizeToContent
    System.Windows.SizeToContent (Manual, Width, Height, WidthAndHeight).

.PARAMETER ResizeMode
    System.Windows.ResizeMode (NoResize, CanMinimize, CanResize, CanResizeWithGrip).

.PARAMETER WindowStyle
    System.Windows.WindowStyle (None, SingleBorderWindow, ThreeDBorderWindow, ToolWindow).

.PARAMETER WindowStartupLocation
    System.Windows.WindowStartupLocation (Manual, CenterOwner, CenterScreen).

.PARAMETER WindowState
    System.Windows.WindowState (Normal, Minimized, Maximized).

.PARAMETER Topmost
    Whether the window stays on top.

.PARAMETER ShowInTaskbar
    Whether to show in taskbar.

.PARAMETER ShowActivated
    Whether to activate when shown.

.PARAMETER AllowsTransparency
    If true, the window can be transparent (requires WindowStyle=None).

.PARAMETER Opacity
    Opacity (0.0–1.0).

.PARAMETER Background
    Background brush. Accepts a color string (e.g. "#FF1E1E1E", "Transparent") or a Brush.

.PARAMETER Foreground
    Foreground brush (same rules as Background).

.PARAMETER FontFamily
.PARAMETER FontSize
.PARAMETER FontWeight
.PARAMETER FontStyle
.PARAMETER FontStretch
    Font settings for the Window.

.PARAMETER IconPath
    Path to an .ico/.png/.jpg file to use as window Icon.

.PARAMETER IconBase64
    Base64 string of an image to use as window Icon.

.PARAMETER IconSource
    An ImageSource/BitmapSource already built; takes precedence over IconPath/Base64.

.PARAMETER OwnerWindow
    An existing Window to set as Owner (enables CenterOwner, modal dialogs, etc.).

.PARAMETER ThemePaths
    One or more XAML ResourceDictionary files to merge into Window.Resources (duplicates by Source are removed first).

.PARAMETER ClearWindowResources
    If specified, clears Window.Resources.MergedDictionaries before adding ThemePaths.

.PARAMETER ContentXamlPath
    Path to a XAML file whose root element becomes the Window.Content.

.PARAMETER DisableMinimizeButton
.PARAMETER DisableMaximizeButton
    Hides the respective caption buttons via Win32 styles (applied when window handle is ready).

.PARAMETER Show
    Calls $Window.Show() at the end.

.PARAMETER ShowDialog
    Calls $Window.ShowDialog() at the end; returns the dialog result.

.OUTPUTS
    Returns the Window (unless -ShowDialog is used, in which case the dialog result is returned).

.NOTES
    📦 CONTENT
    Module     ▹ Bluarch.WpfTools
    Function   ▹ Set-WpfWindow
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
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [System.Windows.Window]$Window,

        [Parameter()]
        [string]$Title,

        [Parameter()]
        [double]$Width,

        [Parameter()]
        [double]$Height,

        [Parameter()]
        [double]$MinWidth,

        [Parameter()]
        [double]$MinHeight,

        [Parameter()]
        [double]$MaxWidth,

        [Parameter()]
        [double]$MaxHeight,

        [Parameter()]
        [double]$Left,

        [Parameter()]
        [double]$Top,

        [Parameter()]
        [System.Windows.SizeToContent]$SizeToContent,

        [Parameter()]
        [System.Windows.ResizeMode]$ResizeMode,

        [Parameter()]
        [System.Windows.WindowStyle]$WindowStyle,

        [Parameter()]
        [System.Windows.WindowStartupLocation]$WindowStartupLocation,

        [Parameter()]
        [System.Windows.WindowState]$WindowState,

        [Parameter()]
        [bool]$Topmost,

        [Parameter()]
        [bool]$ShowInTaskbar,

        [Parameter()]
        [bool]$ShowActivated,

        [Parameter()]
        [bool]$AllowsTransparency,

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Opacity,

        [Parameter()]
        [object]$Background,

        [Parameter()]
        [object]$Foreground,

        [Parameter()]
        [System.Windows.Media.FontFamily]$FontFamily,

        [Parameter()]
        [double]$FontSize,

        [Parameter()]
        [System.Windows.FontWeight]$FontWeight,

        [Parameter()]
        [System.Windows.FontStyle]$FontStyle,

        [Parameter()]
        [System.Windows.FontStretch]$FontStretch,

        [Parameter()]
        [string]$IconPath = (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Icons\BluarchAuthor.png"),

        [Parameter()]
        [string]$IconBase64,

        [Parameter()]
        [System.Windows.Media.ImageSource]$IconSource,

        [Parameter()]
        [System.Windows.Window]$OwnerWindow,

        [Parameter()]
        [string[]]$ThemePaths,

        [Parameter()]
        [switch]$ClearWindowResources,

        [Parameter()]
        [string]$ContentXamlPath,

        [Parameter()]
        [switch]$DisableMinimizeButton,

        [Parameter()]
        [switch]$DisableMaximizeButton,

        [Parameter()]
        [switch]$Show,

        [Parameter()]
        [switch]$ShowDialog
    )

    begin
    {
        # STA required
        if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')
        {
            throw "Set-WpfWindow: WPF requires STA. Start pwsh with -STA or run inside an STA runspace."
        }

        # Helpers
        function _ConvertToBrush([object]$v)
        {
            if ($null -eq $v)
            {
                return $null
            }
            if ($v -is [System.Windows.Media.Brush])
            {
                return $v
            }
            $bc = [System.Windows.Media.BrushConverter]::new()
            try
            {
                return [System.Windows.Media.Brush]$bc.ConvertFromString([string]$v)
            }
            catch
            {
                throw "Invalid brush value: '$v'"
            }
        }

        function _LoadImageSourceFromBase64([string]$b64)
        {
            if ([string]::IsNullOrWhiteSpace($b64))
            {
                return $null
            }
            if ($b64 -match '^data:image\/[a-zA-Z]+;base64,')
            {
                $b64 = $b64 -replace '^data:image\/[a-zA-Z]+;base64,', ''
            }
            try
            {
                $bytes = [Convert]::FromBase64String($b64)
                $ms = [System.IO.MemoryStream]::new($bytes)
                $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
                $bmp.BeginInit()
                $bmp.StreamSource = $ms
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.EndInit()
                $bmp.Freeze()
                return $bmp
            }
            catch
            {
                throw "IconBase64 could not be decoded: $($_.Exception.Message)"
            }
        }

        function _LoadImageSourceFromPath([string]$path)
        {
            if ([string]::IsNullOrWhiteSpace($path))
            {
                return $null
            }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf))
            {
                throw "IconPath not found: $path"
            }
            $uri = [System.Uri]::new((Resolve-Path -LiteralPath $path).ProviderPath)
            $bmp = [System.Windows.Media.Imaging.BitmapImage]::new($uri)
            $bmp.Freeze()
            return $bmp
        }

        # Win32 helpers for caption buttons
        Add-Type -Namespace Win32 -Name User32 -MemberDefinition @"
using System;
using System.Runtime.InteropServices;
public static class User32 {
    [DllImport("user32.dll")] public static extern IntPtr GetActiveWindow();
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}
"@ -ErrorAction SilentlyContinue
        $GWL_STYLE = -16
        $WS_MINIMIZEBOX = 0x00020000
        $WS_MAXIMIZEBOX = 0x00010000

        # Apply caption style when handle exists
        $applyCaptionStyles = {
            param($w, $disableMin, $disableMax)
            $src = [System.Windows.Interop.HwndSource]::FromVisual($w)
            if ($null -eq $src)
            {
                return
            }
            $h = $src.Handle
            if ($h -eq [IntPtr]::Zero)
            {
                return
            }
            $style = [Win32.User32]::GetWindowLong($h, $GWL_STYLE)
            if ($disableMin)
            {
                $style = $style & (~$WS_MINIMIZEBOX)
            }
            if ($disableMax)
            {
                $style = $style & (~$WS_MAXIMIZEBOX)
            }
            [void][Win32.User32]::SetWindowLong($h, $GWL_STYLE, $style)
        }
    }

    process
    {
        if ($null -eq $Window)
        {
            throw "Set-WpfWindow: -Window cannot be null."
        }

        # Title
        if ($PSBoundParameters.ContainsKey('Title'))
        {
            $Window.Title = $Title
        }

        # Size & position
        foreach ($p in 'Width', 'Height', 'MinWidth', 'MinHeight', 'MaxWidth', 'MaxHeight', 'Left', 'Top')
        {
            if ($PSBoundParameters.ContainsKey($p))
            {
                $Window.$p = $PSBoundParameters[$p]
            }
        }

        # Layout-related enums
        foreach ($p in 'SizeToContent', 'ResizeMode', 'WindowStyle', 'WindowStartupLocation', 'WindowState')
        {
            if ($PSBoundParameters.ContainsKey($p))
            {
                $Window.$p = $PSBoundParameters[$p]
            }
        }

        # AllowsTransparency must have WindowStyle=None
        if ($PSBoundParameters.ContainsKey('AllowsTransparency'))
        {
            $Window.AllowsTransparency = $AllowsTransparency
            if ($AllowsTransparency -and $Window.WindowStyle -ne [System.Windows.WindowStyle]::None)
            {
                # Auto-fix to avoid runtime exception
                $Window.WindowStyle = [System.Windows.WindowStyle]::None
            }
        }

        # Behavior flags
        foreach ($p in 'Topmost', 'ShowInTaskbar', 'ShowActivated')
        {
            if ($PSBoundParameters.ContainsKey($p))
            {
                $Window.$p = $PSBoundParameters[$p]
            }
        }

        # Opacity
        if ($PSBoundParameters.ContainsKey('Opacity'))
        {
            $Window.Opacity = $Opacity
        }

        # Brushes
        if ($PSBoundParameters.ContainsKey('Background'))
        {
            $Window.Background = _ConvertToBrush $Background
        }
        if ($PSBoundParameters.ContainsKey('Foreground'))
        {
            $Window.Foreground = _ConvertToBrush $Foreground
        }

        # Fonts
        foreach ($p in 'FontFamily', 'FontSize', 'FontWeight', 'FontStyle', 'FontStretch')
        {
            if ($PSBoundParameters.ContainsKey($p))
            {
                $Window.$p = $PSBoundParameters[$p]
            }
        }

        # Owner
        if ($PSBoundParameters.ContainsKey('OwnerWindow'))
        {
            $Window.Owner = $OwnerWindow
        }

        # Icon (precedence: IconSource > IconPath > IconBase64)
        if ($PSBoundParameters.ContainsKey('IconSource') -and $IconSource)
        {
            $Window.Icon = $IconSource
        }
        elseif ($PSBoundParameters.ContainsKey('IconPath') -and $IconPath)
        {
            $Window.Icon = _LoadImageSourceFromPath $IconPath
        }
        elseif ($PSBoundParameters.ContainsKey('IconBase64') -and $IconBase64)
        {
            $Window.Icon = _LoadImageSourceFromBase64 $IconBase64
        }

        # Merge ResourceDictionaries at Window scope
        if ($PSBoundParameters.ContainsKey('ThemePaths') -and $ThemePaths)
        {
            if (-not $Window.Resources)
            {
                $Window.Resources = [System.Windows.ResourceDictionary]::new()
            }
            if ($ClearWindowResources)
            {
                $Window.Resources.MergedDictionaries.Clear()
            }

            foreach ($p in $ThemePaths)
            {
                if (-not (Test-Path -LiteralPath $p -PathType Leaf))
                {
                    throw "Theme not found: $p"
                }
                $abs = (Resolve-Path -LiteralPath $p).ProviderPath
                $uri = [System.Uri]::new($abs, [System.UriKind]::Absolute)

                # Remove duplicates by Source
                $dupes = @($Window.Resources.MergedDictionaries | Where-Object {
                        $_.Source -and $_.Source.AbsoluteUri -eq $uri.AbsoluteUri
                    })
                foreach ($d in $dupes)
                {
                    [void]$Window.Resources.MergedDictionaries.Remove($d)
                }

                $rd = [System.Windows.ResourceDictionary]::new()
                $rd.Source = $uri
                [void]$Window.Resources.MergedDictionaries.Add($rd)
            }
        }

        # Load Content from XAML if requested
        if ($PSBoundParameters.ContainsKey('ContentXamlPath') -and $ContentXamlPath)
        {
            if (-not (Test-Path -LiteralPath $ContentXamlPath -PathType Leaf))
            {
                throw "ContentXamlPath not found: $ContentXamlPath"
            }
            $xml = [xml](Get-Content -Raw -LiteralPath $ContentXamlPath)
            $node = [System.Xml.XmlNodeReader]::new($xml)
            $Window.Content = [System.Windows.Markup.XamlReader]::Load($node)
        }

        # Caption buttons (min/max) -> apply when handle exists
        if ($DisableMinimizeButton -or $DisableMaximizeButton)
        {
            if ($Window.IsInitialized)
            {
                & $applyCaptionStyles $Window $DisableMinimizeButton.IsPresent $DisableMaximizeButton.IsPresent
            }
            else
            {
                # Apply after SourceInitialized (first moment a handle exists)
                $handler = [System.EventHandler] {
                    & $applyCaptionStyles $Window $DisableMinimizeButton.IsPresent $DisableMaximizeButton.IsPresent
                }
                $Window.add_SourceInitialized($handler)
            }
        }

        # Show / ShowDialog
        if ($ShowDialog)
        {
            return $Window.ShowDialog()
        }
        elseif ($Show)
        {
            $Window.Show() | Out-Null
        }

        return $Window
    }
}
