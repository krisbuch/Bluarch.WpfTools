function Add-WpfHeader
{
    <#
.SYNOPSIS
Adds a header view (from Views\Header.<Type>.xaml) to a container, or returns it for manual placement.

.DESCRIPTION
- Loads the XAML for the requested header Type (e.g. 'Simple').
- Sets logo, Title, Subtitle.
- Adds right-side action icons (image + tooltip + click script).
- If -Into is provided, inserts into that container (Grid/Panel/Decorator supported), otherwise returns the control.

.PARAMETER Type
Header view type (matches XAML file 'Views\Header.<Type>.xaml'). Default: Simple.

.PARAMETER LogoPath
Path/URI to a logo image. Optional.

.PARAMETER Title
Header title text.

.PARAMETER Subtitle
Header subtitle text.

.PARAMETER Icons
Array of items with properties:
- Icon     : [Icons] enum value (file resolved as $PSScriptRoot\Assets\Icons\<Icon>.png)
- ToolTip  : string (optional)
- Click    : scriptblock (optional) – executed on MouseLeftButtonUp

Examples:
    @(
      @{ Icon = [Icons]::Github;   ToolTip='Open GitHub';   Click = { Start-Process 'https://github.com/bluagentis' } },
      @{ Icon = [Icons]::Settings; ToolTip='Settings';      Click = { [System.Windows.MessageBox]::Show('Settings') } }
    )

.PARAMETER Into
Parent to insert the header into. Supports: Grid (Children), Panel (Children), Decorator (Child), ContentControl (Content).
If omitted, the control is returned.

.PARAMETER GridRow
Row index if Into is a Grid. Default: 0.

.PARAMETER GridColumn
Column index if Into is a Grid. Default: 0.

.PARAMETER PassThru
Return the created header control.

.NOTES
Make sure Initialize-WpfApplication (your function) + Load-WpfAssembly have been run beforehand.
#>
    [CmdletBinding()]
    param(
        [ValidateSet('Simple')]
        [string]$Type = 'Simple',

        [string]$LogoPath,
        [string]$Title = 'BLUARCH',
        [string]$Subtitle,

        [System.Collections.IEnumerable]$Icons,

        [System.Windows.FrameworkElement]$Into,
        [int]$GridRow = 0,
        [int]$GridColumn = 0,

        [switch]$PassThru
    )

    # Helper: make BitmapImage safely
    function New-BitmapImage([string]$pathOrUri)
    {
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        if ([System.IO.Path]::IsPathRooted($pathOrUri) -or (Test-Path -LiteralPath $pathOrUri))
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

    # Load XAML view
    $viewPath = Join-Path $PSScriptRoot "Views/Header.$Type.xaml"
    if (-not (Test-Path -LiteralPath $viewPath))
    {
        throw "Header view not found: $viewPath"
    }
    [xml]$xaml = Get-Content -LiteralPath $viewPath -Raw
    $ctrl = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($xaml))

    # Resolve named parts
    $logo = $ctrl.FindName('HeaderLogo')
    $tbTitle = $ctrl.FindName('HeaderTitle')
    $tbSub = $ctrl.FindName('HeaderSubtitle')
    $actions = $ctrl.FindName('HeaderActions')

    if ($null -eq $tbTitle -or $null -eq $tbSub -or $null -eq $actions)
    {
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
        # Support hashtable or object
        $iconName = [Icons]([string]$item.Icon)
        $toolTip = $item.ToolTip
        $clickSB = $item.Click

        $iconPath = Join-Path $PSScriptRoot ("Assets\Icons\{0}.png" -f $iconName)
        if (-not (Test-Path -LiteralPath $iconPath))
        {
            throw "Icon not found: $iconPath"
        }

        $img = New-Object System.Windows.Controls.Image
        $img.Width = 28
        $img.Height = 28
        $img.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        if ($toolTip)
        {
            $img.ToolTip = $toolTip
        }
        $img.Source = New-BitmapImage $iconPath

        if ($clickSB -is [scriptblock])
        {
            # capture the scriptblock in a local var so it closes correctly
            $sb = $clickSB.GetNewClosure()
            $img.Add_MouseLeftButtonUp([System.Windows.Input.MouseButtonEventHandler] {
                    param($sender, $args) & $sb
                })
        }

        [void]$actions.Children.Add($img)
    }

    # Insert into parent if provided
    if ($Into)
    {
        # Grid -> Children, set row/col
        if ($Into -is [System.Windows.Controls.Grid])
        {
            [System.Windows.Controls.Grid]::SetRow($ctrl, $GridRow)
            [System.Windows.Controls.Grid]::SetColumn($ctrl, $GridColumn)
            [void]$Into.Children.Add($ctrl)
        }
        # Panel (StackPanel, DockPanel, WrapPanel, etc.) -> Children
        elseif ($Into.PSObject.Properties['Children'])
        {
            [void]$Into.Children.Add($ctrl)
        }
        # Decorator (Border) -> Child
        elseif ($Into.PSObject.Properties['Child'])
        {
            $Into.Child = $ctrl
        }
        # ContentControl -> Content
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
