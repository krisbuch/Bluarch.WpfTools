function Add-WpfHeader
{
    <#
.SYNOPSIS
Adds a header view (from Views\Header.<Type>.xaml) to a container, or returns it for manual placement.

.DESCRIPTION
- Loads the XAML for the requested header Type (e.g. "Simple" or "Advanced").
- Sets logo, Title, Subtitle.
- Adds right-side action icons (image + tooltip + click scriptblock).
- If -Into is provided, inserts into that container (Grid/Panel/Decorator/ContentControl supported).
- If Type = 'Advanced', also:
  - Wires ThemeCombo (populates from [Themes] enum if available; falls back to a static list).
  - Calls Set-WpfTheme when selection changes (Application scope).
  - Sets InfoIcon (defaults to Assets\Icons\Help.png) if present.
  - Wires InfoClose (if present) to uncheck InfoToggle, and ESC key to close the info card.

.PARAMETER Type
Header view type (matches XAML file "Views\Header.<Type>.xaml"). Default: Simple.

.PARAMETER LogoPath
Path/URI to a logo image. Optional.

.PARAMETER Title
Header title text. Default: BLUARCH.

.PARAMETER Subtitle
Header subtitle text. Optional.

.PARAMETER Icons
Array of items with properties:
- Icon     : Name or file path. If "name", we try $PSScriptRoot\Assets\Icons\<name>.png (or .ico).
- ToolTip  : string (optional)
- Click    : scriptblock (optional) – executed on MouseLeftButtonUp

Examples:
@(
  @{ Icon = 'Github';   ToolTip='Open GitHub';   Click = { Start-Process 'https://github.com/krisbuch' } },
  @{ Icon = 'LinkedIn'; ToolTip='LinkedIn';      Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
)

.PARAMETER Into
Parent to insert the header into. Supports: Grid (Children), Panel (Children), Decorator (Child), ContentControl (Content).
If omitted, the control is returned.

.PARAMETER GridRow
Row index if -Into is a Grid. Default: 0.

.PARAMETER GridColumn
Column index if -Into is a Grid. Default: 0.

.PARAMETER CurrentTheme
Preselect this value in ThemeCombo for the Advanced header.

.PARAMETER InfoIconPath
Path to the info/help icon image for Advanced header (defaults to Assets\Icons\Help.png if present).

.PARAMETER PassThru
Return the created header control even if it was inserted into a parent.

.PARAMETER Silent
Suppresses informational logging (uses Write-Msg if available).

.NOTES
Module     : Bluarch.WpfTools
#>
    [CmdletBinding()]
    param(
        [ValidateSet('Simple', 'Advanced')]
        [string]$Type = 'Simple',

        [string]$LogoPath = (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Images\BluarchAuthor.png"),
        [string]$Title = 'Bluarch Application',
        [string]$Subtitle = "Powered by Pwsh 7+, WPF & .NET - Developed by Kristian Holm Buch",

        [System.Collections.IEnumerable]$Icons = @(
            @{ Icon = 'Github'; ToolTip = 'GitHub'; Click = { Start-Process 'https://github.com/krisbuch' } },
            @{ Icon = 'LinkedIn'; ToolTip = 'LinkedIn'; Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
        ),

        [System.Windows.FrameworkElement]$Into,
        [int]$GridRow = 0,
        [int]$GridColumn = 0,

        [string]$CurrentTheme,
        [string]$InfoIconPath = (Join-Path -Path $PSScriptRoot -ChildPath "Assets\Icons\Badge.png"),

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
    function _err ([string]$msg)
    {
        _log $msg '❗' 'Red'
    }
    function _ok  ([string]$msg)
    {
        _log $msg '✅' 'Green'
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

    # --- Load header XAML ---
    $viewPath = Join-Path $PSScriptRoot "Views/Header.$Type.xaml"
    if (-not (Test-Path -LiteralPath $viewPath))
    {
        throw "Header view not found: $viewPath"
    }
    try
    {
        [xml]$xaml = Get-Content -LiteralPath $viewPath -Raw
        $ctrl = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))
    }
    catch
    {
        throw "Failed to load header XAML '$viewPath': $($_.Exception.Message)"
    }

    # --- Find required parts (common) ---
    $logo = $ctrl.FindName('HeaderLogo')
    $tbTitle = $ctrl.FindName('HeaderTitle')
    $tbSub = $ctrl.FindName('HeaderSubtitle')
    $actions = $ctrl.FindName('HeaderActions')
    if ($null -eq $tbTitle -or $null -eq $tbSub -or $null -eq $actions)
    {
        throw "Header XAML is missing required named elements (HeaderTitle, HeaderSubtitle, HeaderActions)."
    }

    # --- Apply logo/title/subtitle ---
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

    # --- Add right-side icons (keeps your original scriptblock behavior) ---
    foreach ($item in ($Icons ?? @()))
    {
        $iconName = [string]$item.Icon
        if ([string]::IsNullOrWhiteSpace($iconName))
        {
            continue
        }

        # name -> <module>\Assets\Icons\<name>.png (fallback .ico)
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
            _warn "Icon not found: $iconName (looked for $iconPath)"; continue
        }

        $img = New-Object System.Windows.Controls.Image
        $img.Width = 28; $img.Height = 28
        $img.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $img.Opacity = 0.7

        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        $img.SnapsToDevicePixels = $true
        $img.Source = New-BitmapImage $iconPath
        if ($item.ToolTip)
        {
            $img.ToolTip = [string]$item.ToolTip
        }

        # Click as SCRIPTBLOCK (your original behavior)
        if ($item.Click -is [scriptblock])
        {
            $sb = $item.Click.GetNewClosure()
            $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] { param($s, $e) $e.Handled = $true; & $sb })
            $img.Focusable = $true
            $img.Add_KeyDown({ param($s, $e)
                    if ($e.Key -in @([System.Windows.Input.Key]::Enter, [System.Windows.Input.Key]::Space))
                    {
                        & $sb; $e.Handled = $true
                    } })
        }
        elseif ($item.Click)
        {
            # Optional: If user passed a URL string or code string
            $clickStr = [string]$item.Click
            if ($clickStr -match '^(https?://)')
            {
                $urlLocal = $clickStr
                $img.Add_MouseLeftButtonUp({ Start-Process $urlLocal })
            }
            elseif ($clickStr.Trim().Length)
            {
                $sb = [scriptblock]::Create($clickStr)
                $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] { param($s, $e) $e.Handled = $true; & $sb })
            }
        }

        [void]$actions.Children.Add($img)
    }

    # --- Advanced-only wiring: Theme combo + Info icon/toggle ---
    if ($Type -eq 'Advanced')
    {
        # Theme combo
        $combo = $ctrl.FindName('ThemeCombo')
        if ($combo)
        {
            try
            {
                $null = [Themes] # will throw if enum type doesn't exist
                $combo.ItemsSource = [enum]::GetNames([Themes])
            }
            catch
            {
                $combo.ItemsSource = @('CleanLight', 'NordBlue', 'DarkSlate', 'HighContrast', 'ModernTech', 'AbstractWave', 'WinUIFluent', 'SurpriseMe')
            }
            if ($CurrentTheme)
            {
                $combo.SelectedItem = $CurrentTheme
            }

            $combo.Add_SelectionChanged({
                    param($s, $e)
                    $name = [string]$s.SelectedItem
                    if ([string]::IsNullOrWhiteSpace($name))
                    {
                        return
                    }
                    if (Get-Command Set-WpfTheme -ErrorAction SilentlyContinue)
                    {
                        try
                        {
                            Set-WpfTheme -Theme $name -Scope Application
                            if (Get-Command Write-Msg -ErrorAction SilentlyContinue)
                            {
                                Write-Msg ✅ "Theme switched to '$name' (Application scope)"
                            }
                        }
                        catch
                        {
                            if (Get-Command Write-Msg -ErrorAction SilentlyContinue)
                            {
                                Write-Msg ❗ "Failed to switch theme '$name' – $($_.Exception.Message)" -Foreground Red
                            }
                            else
                            {
                                Write-Host "Failed to switch theme '$name' – $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                    }
                    else
                    {
                        if (Get-Command Write-Msg -ErrorAction SilentlyContinue)
                        {
                            Write-Msg ⚠️ "Set-WpfTheme not found in session." -Foreground Yellow
                        }
                        else
                        {
                            Write-Host "Set-WpfTheme not found in session." -ForegroundColor Yellow
                        }
                    }
                })
        }

        # Info icon default
        $infoImg = $ctrl.FindName('InfoIcon')
        if ($infoImg)
        {
            $path = $InfoIconPath
            if (-not $path)
            {
                $try = Join-Path $PSScriptRoot 'Assets\Icons\Help.png'
                if (Test-Path -LiteralPath $try)
                {
                    $path = $try
                }
            }
            if ($path -and (Test-Path -LiteralPath $path))
            {
                $infoImg.Source = New-BitmapImage $path
            }
        }
        $InfoPopup = $ctrl.FindName("InfoPopup")
        $InfoPopupImage = $ctrl.FindName("InfoPopupImage")
        if ($InfoPopupImage)
        {
            $path = Join-Path -Path $PSScriptRoot -ChildPath "Assets\Images\BluachProfile.png"
            if (-not $path)
            {
                $try = Join-Path $PSScriptRoot 'Assets\Images\BluachProfile.png'
                if (Test-Path -LiteralPath $try)
                {
                    $path = $try
                }
            }
            if ($path -and (Test-Path -LiteralPath $path))
            {
                $InfoPopupImage.Source = New-BitmapImage $path
            }
        }
        # Optional: close button inside the info card
        $toggle = $ctrl.FindName('InfoToggle')
        $btnClose = $ctrl.FindName('InfoClose')   # give the button x:Name="InfoClose" in XAML if you want this
        if ($toggle -and $btnClose)
        {
            $btnClose.Add_Click({ param($s, $e) $parent = $s; while ($parent -and -not ($parent.FindName('InfoToggle')))
                    {
                        $parent = $parent.Parent
                    }
                    if ($parent)
                    {
                        ($parent.FindName('InfoToggle')).IsChecked = $false
                    } })
        }

        # Optional: ESC closes card
        if ($toggle)
        {
            $ctrl.Add_PreviewKeyDown({ param($s, $e)
                    if ($e.Key -eq [System.Windows.Input.Key]::Escape)
                    {
                        $toggle.IsChecked = $false; $e.Handled = $true
                    } })
        }

    }

    # --- Insert into parent if provided ---
    if ($Into)
    {
        if ($Into -is [System.Windows.Controls.Grid])
        {
            [System.Windows.Controls.Grid]::SetRow($ctrl, $GridRow)
            [System.Windows.Controls.Grid]::SetColumn($ctrl, $GridColumn)
            [void]$Into.Children.Add($ctrl)
        }
        elseif ($Into.PSObject.Properties['Children'])
        {
            [void]$Into.Children.Add($ctrl)
        }
        elseif ($Into.PSObject.Properties['Child'])
        {
            $Into.Child = $ctrl
        }
        elseif ($Into.PSObject.Properties['Content'])
        {
            $Into.Content = $ctrl
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
