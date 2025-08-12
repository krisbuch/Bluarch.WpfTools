function Add-WpfHeader
{
    <#
Adds a header view (from Views\Header.<Type>.xaml) to a container, or returns it.

- Loads the XAML for the requested header Type (e.g. "Simple").
- Sets logo, Title, Subtitle.
- Adds right-side action icons (resolved via Resolve-WpfIcon or Insert-WpfIcon).
- If -Into is provided, inserts the control into a parent. Otherwise returns it.

.PARAMETER Type
Name of the XAML view (matches Views\Header.<Type>.xaml). Default: Simple.

.PARAMETER LogoPath
Optional path or name of the logo image.

.PARAMETER Title
Header title. Default: BLUARCH.

.PARAMETER Subtitle
Header subtitle.

.PARAMETER Icons
Array of hashtables/objects describing right‑side icons. Each item can have:
- Icon    : string (icon name or file path) or [System.Windows.Media.ImageSource]
- ToolTip : string (optional)
- Click   : scriptblock (optional) – executed on MouseLeftButtonUp

Example:
    @(
      @{ Icon = 'Github';   ToolTip='Open GitHub';   Click = { Start-Process 'https://github.com/bluagentis' } },
      @{ Icon = 'Settings'; ToolTip='Settings';      Click = { [System.Windows.MessageBox]::Show('Settings') } }
    )

.PARAMETER Into
Parent control to insert the header into (Grid, Panel, Decorator, ContentControl).
If omitted, the header control is returned for manual insertion.

.PARAMETER GridRow
Grid row index for Grid parents. Default: 0.

.PARAMETER GridColumn
Grid column index for Grid parents. Default: 0.

.PARAMETER PassThru
Return the created header control even when inserted.

.NOTES
Requires Resolve-WpfIcon (or Insert-WpfIcon) to locate icons in $PSScriptRoot\Assets\Icons.
Make sure Load-WpfAssembly and Initialize-WpfApplication have been called first.
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Simple')]
        [string]$Type = 'Simple',

        [Parameter()]
        [string]$LogoPath,

        [Parameter()]
        [string]$Title = 'BLUARCH',

        [Parameter()]
        [string]$Subtitle,

        [Parameter()]
        [System.Collections.IEnumerable]$Icons,

        [Parameter()]
        [System.Windows.FrameworkElement]$Into,

        [Parameter()]
        [int]$GridRow = 0,

        [Parameter()]
        [int]$GridColumn = 0,

        [switch]$PassThru
    )

    # Helper to create BitmapImage from path/URI
    function New-BitmapImage([string]$p)
    {
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        if ([System.IO.Path]::IsPathRooted($p) -or (Test-Path -LiteralPath $p))
        {
            $bmp.UriSource = [Uri]::new((Resolve-Path -LiteralPath $p).ProviderPath)
        }
        else
        {
            $bmp.UriSource = [Uri]::new($p, [UriKind]::RelativeOrAbsolute)
        }
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $bmp.Freeze()
        return $bmp
    }

    # Load XAML
    $viewPath = Join-Path $PSScriptRoot "Views/Header/Header.$Type.xaml"
    if (-not (Test-Path -LiteralPath $viewPath))
    {
        throw "Header view not found: $viewPath"
    }
    [xml]$xaml = Get-Content -LiteralPath $viewPath -Raw
    $ctrl = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))

    # Find named parts
    $logo = $ctrl.FindName('HeaderLogo')
    $tbTit = $ctrl.FindName('HeaderTitle')
    $tbSub = $ctrl.FindName('HeaderSubtitle')
    $actions = $ctrl.FindName('HeaderActions')
    if ($null -eq $tbTit -or $null -eq $tbSub -or $null -eq $actions)
    {
        throw "Header XAML is missing required named elements."
    }

    # Set logo, title, subtitle
    if ($LogoPath -and $logo)
    {
        # Resolve logo via Resolve-WpfIcon/Insert-WpfIcon or treat as direct path
        try
        {
            $img = Resolve-WpfIcon -Name $LogoPath -AsImageSource -ThrowOnNotFound
        }
        catch
        {
            $img = New-BitmapImage $LogoPath
        }
        $logo.Source = $img
    }
    $tbTit.Text = $Title
    if ($Subtitle)
    {
        $tbSub.Text = $Subtitle
    }

    # Add icons
    foreach ($item in ($Icons ?? @()))
    {
        $ic = $null
        $tip = $item.ToolTip
        $click = $item.Click

        # If icon is already an ImageSource, use it; else resolve name/path
        if ($item.Icon -is [System.Windows.Media.ImageSource])
        {
            $ic = $item.Icon
        }
        else
        {
            $nameOrPath = [string]$item.Icon
            # Try to resolve via Resolve-WpfIcon first
            try
            {
                $ic = Resolve-WpfIcon -Name $nameOrPath -AsImageSource -ThrowOnNotFound
            }
            catch
            {
                # If not found, assume it's a file path
                $ic = New-BitmapImage $nameOrPath
            }
        }

        $img = [System.Windows.Controls.Image]::new()
        $img.Width = 28
        $img.Height = 28
        $img.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        if ($tip)
        {
            $img.ToolTip = $tip
        }
        $img.Source = $ic
        if ($click -is [scriptblock])
        {
            $sb = $click.GetNewClosure()
            $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] {
                    param($s, $e) & $sb
                })
        }
        $actions.Children.Add($img) | Out-Null
    }

    # Insert or return
    if ($Into)
    {
        if ($Into -is [System.Windows.Controls.Grid])
        {
            [System.Windows.Controls.Grid]::SetRow($ctrl, $GridRow)
            [System.Windows.Controls.Grid]::SetColumn($ctrl, $GridColumn)
            $Into.Children.Add($ctrl) | Out-Null
        }
        elseif ($Into.PSObject.Properties['Children'])
        {
            $Into.Children.Add($ctrl) | Out-Null
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
    }

    if ($PassThru)
    {
        return $ctrl
    }
}
