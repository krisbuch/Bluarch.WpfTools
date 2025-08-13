function Add-WpfHeader
{
    <#
.SYNOPSIS
Adds a header view (from Views\Header.<Type>.xaml) to a container, or returns it for manual placement.

.DESCRIPTION
- Loads the XAML for the requested header Type (e.g. "Simple" / "Advanced").
- Sets Logo, Title, Subtitle.
- Adds right-side action icons (image + tooltip + click action).
- If -Into is provided, inserts into that container (Grid/Panel/Decorator/ContentControl supported),
  otherwise returns the created control.

.PARAMETER Type
Header view type (matches XAML file "Views\Header.<Type>.xaml"). Default: Simple.

.PARAMETER LogoPath
Path/URI to a logo image. Optional.

.PARAMETER Title
Header title text. Default: BLUARCH.

.PARAMETER Subtitle
Header subtitle text. Optional.

.PARAMETER Icons
Array of items with properties (hashtable or PSCustomObject):
- Icon     : Name or file path. If Resolve-WpfIcon exists, it will be used ("Github" -> <module>\Assets\Icons\Github.png)
- ToolTip  : string (optional)
- Click    : scriptblock or string (optional) – executed on MouseLeftButtonUp
             If string begins with http/https, it opens via Start-Process.
             Otherwise treated as PowerShell code and compiled to a scriptblock.
- Size     : optional numeric size (defaults to 28)
- Margin   : optional Thickness (string "L,T,R,B" or single number)
- Opacity  : optional double 0..1

Examples:
@(
  @{ Icon='Github';   ToolTip='Open GitHub';   Click = { Start-Process 'https://github.com/bluagentis' } },
  @{ Icon='LinkedIn'; ToolTip='LinkedIn';      Click = 'Start-Process https://www.linkedin.com/in/kristianbuch/' }
)

.PARAMETER Into
Parent to insert the header into. Supports: Grid (Children), Panel (Children), Decorator (Child), ContentControl (Content).
If omitted, the control is returned.

.PARAMETER GridRow
Row index if -Into is a Grid. Default: 0.

.PARAMETER GridColumn
Column index if -Into is a Grid. Default: 0.

.PARAMETER PassThru
Return the created header control even if it was inserted into a parent.

.PARAMETER Silent
Suppress informational logging (uses Write-Msg if available).

.NOTES
Module : Bluarch.WpfTools
#>
    [CmdletBinding()]
    param(
        [ValidateSet('Simple', 'Advanced')]
        [string]$Type = 'Simple',

        [string]$LogoPath = (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Images\BluarchAuthor.png"),
        [string]$Title = 'BLUARCH',
        [string]$Subtitle = "Powered by Pwsh 7+, WPF & .NET - Developed by Kristian Holm Buch",

        [System.Collections.IEnumerable]$Icons = @(
            @{ Icon = 'Github'; ToolTip = 'GitHub'; Click = { Start-Process 'https://github.com/krisbuch' } },
            @{ Icon = 'LinkedIn'; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
        ),

        [System.Windows.FrameworkElement]$Into,
        [int]$GridRow = 0,
        [int]$GridColumn = 0,

        [switch]$PassThru,
        [switch]$Silent
    )

    # --- logging shim ---
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
    function _log([string]$msg, [string]$sym = '📚', [string]$fg = 'Gray')
    {
        if ($Silent)
        {
            return
        }
        if ($haveWriteMsg)
        {
            Write-Msg $sym $msg -Foreground $fg -Silent:$Silent
        }
        else
        {
            Write-Host $msg -ForegroundColor $fg
        }
    }
    function _ok([string]$m)
    {
        _log $m '✅' 'Green'
    }
    function _warn([string]$m)
    {
        _log $m '⚠️' 'Yellow'
    }
    function _err([string]$m)
    {
        _log $m '❗' 'Red'
    }

    # Helper: make BitmapImage safely
    function New-BitmapImage([string]$pathOrUri)
    {
        if ([string]::IsNullOrWhiteSpace($pathOrUri))
        {
            return $null
        }
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        if (Test-Path -LiteralPath $pathOrUri)
        {
            $bmp.UriSource = [Uri]::new((Resolve-Path -LiteralPath $pathOrUri).ProviderPath)
        }
        else
        {
            $bmp.UriSource = [Uri]::new($pathOrUri, [UriKind]::RelativeOrAbsolute)
        }
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $bmp.Freeze()
        return $bmp
    }

    function Resolve-IconPath([string]$nameOrPath)
    {
        if ([string]::IsNullOrWhiteSpace($nameOrPath))
        {
            return $null
        }

        # already a file?
        if (Test-Path -LiteralPath $nameOrPath)
        {
            return (Resolve-Path -LiteralPath $nameOrPath).ProviderPath
        }

        # try helper if available
        $resolver = Get-Command -Name Resolve-WpfIcon -ErrorAction SilentlyContinue
        if ($resolver)
        {
            try
            {
                $p = Resolve-WpfIcon -Name $nameOrPath -ErrorAction Stop
                if ($p -and (Test-Path -LiteralPath $p))
                {
                    return (Resolve-Path -LiteralPath $p).ProviderPath
                }
            }
            catch
            {
            }
        }

        # fallback to module asset path: Assets\Icons\<Name>.png or .ico
        $png = Join-Path $PSScriptRoot ("Assets\Icons\{0}.png" -f $nameOrPath)
        if (Test-Path -LiteralPath $png)
        {
            return (Resolve-Path -LiteralPath $png).ProviderPath
        }

        $ico = [System.IO.Path]::ChangeExtension($png, '.ico')
        if (Test-Path -LiteralPath $ico)
        {
            return (Resolve-Path -LiteralPath $ico).ProviderPath
        }

        return $null
    }

    function Apply-IconHoverEffect([System.Windows.Controls.Image]$img, [double]$hoverScale = 1.12)
    {
        $img.RenderTransformOrigin = '0.5,0.5'
        $st = [System.Windows.Media.ScaleTransform]::new(1, 1)
        $img.RenderTransform = $st
        $img.Add_MouseEnter({ param($s, $e) $s.RenderTransform.ScaleX = $hoverScale; $s.RenderTransform.ScaleY = $hoverScale })
        $img.Add_MouseLeave({ param($s, $e) $s.RenderTransform.ScaleX = 1.0; $s.RenderTransform.ScaleY = 1.0 })
    }

    # Load header XAML
    $viewPath = Join-Path $PSScriptRoot "Views/Header.$Type.xaml"
    if (-not (Test-Path -LiteralPath $viewPath))
    {
        throw "Header view not found: $viewPath"
    }
    [xml]$xaml = Get-Content -LiteralPath $viewPath -Raw
    $ctrl = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))

    # Find named parts
    $logo = $ctrl.FindName('HeaderLogo')
    $tbTitle = $ctrl.FindName('HeaderTitle')
    $tbSub = $ctrl.FindName('HeaderSubtitle')
    $actions = $ctrl.FindName('HeaderActions')

    if ($null -eq $tbTitle -or $null -eq $tbSub -or $null -eq $actions)
    {
        # help with debugging by listing names found
        $namescope = New-Object System.Collections.Generic.List[string]
        ($ctrl | ForEach-Object {
            $_
        }) | Out-Null
        throw "Header XAML is missing required named elements (HeaderTitle, HeaderSubtitle, HeaderActions)."
    }

    # Apply content
    if ($LogoPath -and $logo)
    {
        $logo.Source = New-BitmapImage $LogoPath
    }
    if ($Title)
    {
        $tbTitle.Text = $Title
    }
    if ($Subtitle)
    {
        $tbSub.Text = $Subtitle
    }

    # Add right-side icons
    foreach ($item in ($Icons ?? @()))
    {
        if ($null -eq $item)
        {
            continue
        }
        $iconName = [string]$item.Icon
        $iconSize = if ($item.PSObject.Properties['Size'])
        {
            [double]$item.Size
        }
        else
        {
            28
        }
        $iconMargin = if ($item.PSObject.Properties['Margin'])
        {
            # allow "L,T,R,B" or single number
            $m = [string]$item.Margin
            if ($m -match ',')
            {
                [System.Windows.Thickness]::new(($m -split ',')[0], [double]($m -split ',')[1], [double]($m -split ',')[2], [double]($m -split ',')[3])
            }
            else
            {
                [System.Windows.Thickness]::new([double]$m, [double]$m, [double]$m, [double]$m)
            }
        }
        else
        {
            [System.Windows.Thickness]::new(8, 0, 0, 0)
        }
        $iconOpacity = if ($item.PSObject.Properties['Opacity'])
        {
            [double]$item.Opacity
        }
        else
        {
            1.0
        }

        $iconPath = Resolve-IconPath $iconName
        if (-not $iconPath)
        {
            _warn "Icon not found: $iconName"; continue
        }

        $img = [System.Windows.Controls.Image]::new()
        $img.Width = $iconSize
        $img.Height = $iconSize
        $img.Margin = $iconMargin
        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        $img.SnapsToDevicePixels = $true
        $img.Opacity = $iconOpacity
        $img.Source = New-BitmapImage $iconPath
        if ($item.ToolTip)
        {
            $img.ToolTip = [string]$item.ToolTip
        }

        # Prepare click action
        $clickSB = $null

        # 1) Scriptblock = kør som før
        if ($item.Click -is [scriptblock])
        {
            $clickSB = $item.Click.GetNewClosure()
        }
        # 2) String = lav et scriptblock (URL => Start-Process)
        elseif ($item.Click -is [string])
        {
            $clickStr = [string]$item.Click
            if ($clickStr -match '^(https?://)')
            {
                $escaped = $clickStr.Replace("'", "''")
                $clickSB = [scriptblock]::Create("Start-Process '$escaped'")
            }
            elseif ($clickStr.Trim().Length)
            {
                $clickSB = [scriptblock]::Create($clickStr).GetNewClosure()
            }
        }

        if ($clickSB)
        {
            $img.Tag = $clickSB
            $img.Add_MouseLeftButtonUp({
                    param($sender, $e)
                    $e.Handled = $true
                    $sb = $sender.Tag
                    if ($sb -is [scriptblock])
                    {
                        & $sb
                    }
                })
            $img.Focusable = $true
            $img.Add_KeyDown({
                    param($sender, $e)
                    if ($e.Key -eq 'Enter' -or $e.Key -eq 'Space')
                    {
                        $sb = $sender.Tag
                        if ($sb -is [scriptblock])
                        {
                            & $sb
                        }
                        $e.Handled = $true
                    }
                })
        }


        Apply-IconHoverEffect -img $img
        [void]$actions.Children.Add($img)
    }

    # Insert into parent if provided
    if ($Into)
    {
        if ($Into -is [System.Windows.Controls.Grid])
        {
            [System.Windows.Controls.Grid]::SetRow($ctrl, $GridRow)
            [System.Windows.Controls.Grid]::SetColumn($ctrl, $GridColumn)
            [void]$Into.Children.Add($ctrl)
        }
        elseif ($Into -is [System.Windows.Controls.ContentControl])
        {
            $Into.Content = $ctrl
        }
        elseif ($Into.PSObject.Properties['Children'])
        {
            [void]$Into.Children.Add($ctrl)
        }
        elseif ($Into -is [System.Windows.Controls.Decorator])
        {
            $Into.Child = $ctrl
        }
        else
        {
            throw "Unsupported parent type '$($Into.GetType().Name)'."
        }
        _ok "Header inserted into $($Into.GetType().Name) (Row=$GridRow, Column=$GridColumn)."
    }

    if ($PassThru)
    {
        return $ctrl
    }
}
