function Add-WpfFooter
{
    <#
.SYNOPSIS
    Adds a themed footer with: [Progress(100px)] [Status] | [Copyright centered] | [Icons right].

.DESCRIPTION
    Layout:
      - Left  : ProgressBar (fixed width 100) followed by Status (max 20 chars)
      - Center: Copyright text, centered
      - Right : Action icons (same behavior as Add-WpfHeader)

    Theme brushes (optional, with fallbacks):
      BrushFooterBG, BrushFooterFG, BrushFooterBorder, BrushFooterProgressBG,
      BrushSubtleFG, BrushAccent

.PARAMETER Into
    Parent container to insert into (Grid/Panel/Decorator/ContentControl).

.PARAMETER GridRow
.PARAMETER GridColumn
    Grid coordinates if -Into is a Grid.

.PARAMETER ShowProgress
    Show the left ProgressBar (100px wide).

.PARAMETER ShowStatus
    Show the status text next to the ProgressBar.

.PARAMETER Status
    Initial status text (0..20 chars). Only used if -ShowStatus.

.PARAMETER ShowCopyright
    Show centered copyright text.

.PARAMETER Copyright
    Copyright text (fallback: "© <year>").

.PARAMETER Icons
    Array of items like:
      @{ Icon='Github'; ToolTip='GitHub'; Click={ Start-Process 'https://github.com/...' } }
    If Icon is a bare name, the function looks for "$PSScriptRoot\Assets\Icons\<name>.png|.ico".

.PARAMETER Silent
    Pipe logs through Write-Msg -Silent:$Silent if available; otherwise Write-Host.

.OUTPUTS
    PSCustomObject:
      FooterBorder, RootGrid,
      LeftPanel, ProgressBar, StatusText,
      CenterText, IconsPanel, IconImages (list),
      SetStatus([string]), SetStatusVisible([bool]),
      SetProgress([double]), SetIndeterminate([bool]), SetProgressVisible([bool]),
      SetCopyright([string])
#>
    [CmdletBinding()]
    param(
        [System.Windows.FrameworkElement]$Into,
        [int]$GridRow = 0,
        [int]$GridColumn = 0,

        [switch]$ShowProgress,
        [switch]$ShowStatus,
        [ValidateLength(0, 20)]
        [string]$Status = "",

        [switch]$ShowCopyright,
        [string]$Copyright = ("© {0} - Kristian Holm Buch" -f (Get-Date).Year),

        [System.Collections.IEnumerable]$Icons = @(),

        [switch]$PassThru,
        [switch]$Silent
    )

    # --- logging shim ---
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
    function _log([string]$msg, [string]$symbol = '📚', [string]$color = 'Gray')
    {
        if ($haveWriteMsg)
        {
            Write-Msg $symbol $msg -Foreground $color -Silent:$Silent
        }
        elseif (-not $Silent)
        {
            Write-Host $msg -ForegroundColor $color
        }
    }
    function _warn([string]$msg)
    {
        _log $msg '⚠️' 'Yellow'
    }
    function _ok  ([string]$msg)
    {
        _log $msg '✅' 'Green'
    }

    # WPF
    Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue

    function Get-ResBrush
    {
        param([string]$Key, [System.Windows.Media.Brush]$Fallback)
        try
        {
            $b = [System.Windows.Application]::Current.Resources[$Key]
            if ($b -is [System.Windows.Media.Brush])
            {
                return $b
            }
        }
        catch
        {
        }
        return $Fallback
    }
    function New-BitmapImage([string]$pathOrUri)
    {
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        if ($pathOrUri -and (Test-Path -LiteralPath $pathOrUri))
        {
            $bmp.UriSource = [Uri]::new((Resolve-Path -LiteralPath $pathOrUri).ProviderPath)
        }
        else
        {
            $bmp.UriSource = [Uri]::new($pathOrUri, [UriKind]::RelativeOrAbsolute)
        }
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit(); $bmp.Freeze(); return $bmp
    }

    # Brushes
    $bg = Get-ResBrush -Key 'BrushFooterBG'         -Fallback ([System.Windows.Media.Brushes]::Transparent)
    $fg = Get-ResBrush -Key 'BrushFooterFG'         -Fallback ([System.Windows.Media.Brushes]::Gray)
    $borderB = Get-ResBrush -Key 'BrushFooterBorder'     -Fallback ([System.Windows.Media.Brushes]::Gray)
    $subtle = Get-ResBrush -Key 'BrushSubtleFG'         -Fallback ([System.Windows.Media.Brushes]::DarkGray)
    $accent = Get-ResBrush -Key 'BrushAccent'           -Fallback ([System.Windows.Media.Brushes]::DodgerBlue)
    $pbg = Get-ResBrush -Key 'BrushFooterProgressBG' -Fallback ([System.Windows.Media.Brushes]::LightGray)

    # Root container: Border -> Grid (Left | Center | Right)
    $footerBorder = [System.Windows.Controls.Border]@{
        Background          = $bg
        BorderBrush         = $borderB
        BorderThickness     = [System.Windows.Thickness]::new(0, 1, 0, 0)
        Padding             = [System.Windows.Thickness]::new(12, 6, 12, 6)
        SnapsToDevicePixels = $true
    }
    $rootGrid = [System.Windows.Controls.Grid]::new()
    $footerBorder.Child = $rootGrid
    $rootGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::Auto })                                # Left: progress+status
    $rootGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }) # Center: copyright
    $rootGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]@{ Width = [System.Windows.GridLength]::Auto })                                # Right: icons

    # LEFT: progress (100px) + status
    $leftPanel = [System.Windows.Controls.StackPanel]@{
        Orientation       = 'Horizontal'
        VerticalAlignment = 'Center'
    }
    [System.Windows.Controls.Grid]::SetColumn($leftPanel, 0)
    [void]$rootGrid.Children.Add($leftPanel)

    $progress = [System.Windows.Controls.ProgressBar]@{
        Minimum           = 0
        Maximum           = 100
        Width             = 100
        Height            = 6
        VerticalAlignment = 'Center'
        Foreground        = $accent
        Background        = $pbg
        Visibility        = 'Collapsed'
    }
    if ($ShowProgress)
    {
        $progress.Visibility = 'Visible'
    }
    [void]$leftPanel.Children.Add($progress)

    $statusText = [System.Windows.Controls.TextBlock]@{
        VerticalAlignment = 'Center'
        Foreground        = $fg
        FontSize          = 12
        TextTrimming      = [System.Windows.TextTrimming]::CharacterEllipsis
        Text              = ''
        Visibility        = 'Collapsed'
        Margin            = [System.Windows.Thickness]::new(0, 0, 0, 0)
    }
    if ($ShowStatus)
    {
        $statusText.Visibility = 'Visible'
        if ($Status.Length -gt 20)
        {
            $Status = $Status.Substring(0, 20)
        }
        $statusText.Text = $Status
        # Giv kun venstremargin hvis progress også vises
        if ($progress.Visibility -eq 'Visible')
        {
            $statusText.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        }
    }
    [void]$leftPanel.Children.Add($statusText)

    # CENTER: copyright (centreret)
    $centerText = [System.Windows.Controls.TextBlock]@{
        VerticalAlignment   = 'Center'
        HorizontalAlignment = 'Center'
        Foreground          = $subtle
        FontSize            = 12
        TextTrimming        = [System.Windows.TextTrimming]::CharacterEllipsis
        Text                = ''
        Visibility          = 'Collapsed'
    }
    if ($ShowCopyright)
    {
        if ([string]::IsNullOrWhiteSpace($Copyright))
        {
            $Copyright = "© $([DateTime]::Now.Year)"
        }
        $centerText.Text = $Copyright
        $centerText.Visibility = 'Visible'
    }
    [System.Windows.Controls.Grid]::SetColumn($centerText, 1)
    [void]$rootGrid.Children.Add($centerText)

    # RIGHT: icons (same behavior as header)
    $iconsPanel = [System.Windows.Controls.StackPanel]@{
        Orientation         = 'Horizontal'
        VerticalAlignment   = 'Center'
        HorizontalAlignment = 'Right'
    }
    [System.Windows.Controls.Grid]::SetColumn($iconsPanel, 2)
    [void]$rootGrid.Children.Add($iconsPanel)

    $iconImages = New-Object System.Collections.Generic.List[System.Windows.Controls.Image]
    foreach ($item in ($Icons ?? @()))
    {
        $iconName = [string]$item.Icon
        if ([string]::IsNullOrWhiteSpace($iconName))
        {
            continue
        }

        $iconPath = $iconName
        if (-not (Test-Path -LiteralPath $iconPath))
        {
            $iconPath = Join-Path $PSScriptRoot ("Assets\Icons\{0}.png" -f $iconName)
            if (-not (Test-Path -LiteralPath $iconPath))
            {
                $ico = [System.IO.Path]::ChangeExtension($iconPath, '.ico')
                if (Test-Path -LiteralPath $ico)
                {
                    $iconPath = $ico
                }
            }
        }
        if (-not (Test-Path -LiteralPath $iconPath))
        {
            _warn "Icon not found: $iconName"; continue
        }

        $img = [System.Windows.Controls.Image]::new()
        $img.Width = 24; $img.Height = 24
        $img.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $img.Opacity = 0.8
        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        $img.SnapsToDevicePixels = $true
        $img.Source = New-BitmapImage $iconPath
        if ($item.ToolTip)
        {
            $img.ToolTip = [string]$item.ToolTip
        }

        $img.Add_MouseEnter({ param($s, $e) $s.Opacity = 1.0 })
        $img.Add_MouseLeave({ param($s, $e) $s.Opacity = 0.8 })

        # CLICK behavior == Add-WpfHeader
        $clickVal = if ($item.PSObject.Properties['Click'])
        {
            $item.Click
        }
        else
        {
            $item['Click']
        }

        if ($clickVal -is [scriptblock])
        {
            $sb = $clickVal.GetNewClosure()
            $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] { param($s, $e) $e.Handled = $true; & $sb })
            $img.Add_KeyDown({ param($s, $e) if ($e.Key -in @([System.Windows.Input.Key]::Enter, [System.Windows.Input.Key]::Space))
                    {
                        & $sb; $e.Handled = $true
                    } })
        }
        elseif ($clickVal)
        {
            $clickStr = [string]$clickVal
            if ($clickStr -match '^(https?://)')
            {
                $urlLocal = $clickStr
                $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] { param($s, $e) $e.Handled = $true; Start-Process $urlLocal })
                $img.Add_KeyDown({ param($s, $e) if ($e.Key -in @([System.Windows.Input.Key]::Enter, [System.Windows.Input.Key]::Space))
                        {
                            Start-Process $urlLocal; $e.Handled = $true
                        } })
            }
            elseif ($clickStr.Trim().Length)
            {
                $sb = [scriptblock]::Create($clickStr).GetNewClosure()
                $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] { param($s, $e) $e.Handled = $true; & $sb })
                $img.Add_KeyDown({ param($s, $e) if ($e.Key -in @([System.Windows.Input.Key]::Enter, [System.Windows.Input.Key]::Space))
                        {
                            & $sb; $e.Handled = $true
                        } })
            }
        }

        [void]$iconsPanel.Children.Add($img)
        [void]$iconImages.Add($img)
    }

    # Insert into parent
    if ($Into)
    {
        if ($Into -is [System.Windows.Controls.Grid])
        {
            [System.Windows.Controls.Grid]::SetRow($footerBorder, $GridRow)
            [System.Windows.Controls.Grid]::SetColumn($footerBorder, $GridColumn)
            [void]$Into.Children.Add($footerBorder)
        }
        elseif ($Into.PSObject.Properties['Children'])
        {
            [void]$Into.Children.Add($footerBorder)
        }
        elseif ($Into.PSObject.Properties['Child'])
        {
            $Into.Child = $footerBorder
        }
        elseif ($Into.PSObject.Properties['Content'])
        {
            $Into.Content = $footerBorder
        }
        else
        {
            throw "Unsupported parent type '$($Into.GetType().Name)'."
        }
        _ok "Footer inserted into $($Into.GetType().Name) (Row=$GridRow, Column=$GridColumn)."
    }

    # API
    $api = [pscustomobject]@{
        FooterBorder       = $footerBorder
        RootGrid           = $rootGrid
        LeftPanel          = $leftPanel
        ProgressBar        = $progress
        StatusText         = $statusText
        CenterText         = $centerText
        IconsPanel         = $iconsPanel
        IconImages         = $iconImages

        SetStatus          = {
            param([string]$Text)
            if ($Text.Length -gt 20)
            {
                $Text = $Text.Substring(0, 20)
            }
            $statusText.Text = $Text
            if ($statusText.Visibility -ne 'Visible')
            {
                $statusText.Visibility = 'Visible'
            }
            # Only give left margin if progress is visible
            $statusText.Margin = if ($progress.Visibility -eq 'Visible')
            {
                [System.Windows.Thickness]::new(8, 0, 0, 0)
            }
            else
            {
                [System.Windows.Thickness]::new(0)
            }
        }
        SetStatusVisible   = {
            param([bool]$Visible)
            $statusText.Visibility = if ($Visible)
            {
                'Visible'
            }
            else
            {
                'Collapsed'
            }
            $statusText.Margin = if ($Visible -and $progress.Visibility -eq 'Visible')
            {
                [System.Windows.Thickness]::new(8, 0, 0, 0)
            }
            else
            {
                [System.Windows.Thickness]::new(0)
            }
        }
        SetProgress        = {
            param([double]$Value)
            if ($Value -lt 0)
            {
                $Value = 0
            }
            elseif ($Value -gt 100)
            {
                $Value = 100
            }
            $progress.IsIndeterminate = $false
            $progress.Value = $Value
            if ($progress.Visibility -ne 'Visible')
            {
                $progress.Visibility = 'Visible'
            }
            if ($statusText.Visibility -eq 'Visible')
            {
                $statusText.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            }
        }
        SetIndeterminate   = {
            param([bool]$On)
            $progress.IsIndeterminate = $On
            if ($progress.Visibility -ne 'Visible')
            {
                $progress.Visibility = 'Visible'
            }
            if ($statusText.Visibility -eq 'Visible')
            {
                $statusText.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            }
        }
        SetProgressVisible = {
            param([bool]$Visible)
            $progress.Visibility = if ($Visible)
            {
                'Visible'
            }
            else
            {
                'Collapsed'
            }
            # Adjust status margin depending on progress visibility
            $statusText.Margin = if ($Visible -and $statusText.Visibility -eq 'Visible')
            {
                [System.Windows.Thickness]::new(8, 0, 0, 0)
            }
            else
            {
                [System.Windows.Thickness]::new(0)
            }
        }
        SetCopyright       = {
            param([string]$Text)
            $centerText.Text = $Text
            if ($centerText.Visibility -ne 'Visible')
            {
                $centerText.Visibility = 'Visible'
            }
        }
    }

    if ($PassThru -or -not $Into)
    {
        return $api
    }
}
