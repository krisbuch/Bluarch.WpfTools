function Add-WpfHeader
{
    <#
.SYNOPSIS
Adds a header view (from Views\Header.<Type>.xaml) to a container, or returns it for manual placement.

.DESCRIPTION
- Loads the XAML for the requested header Type (e.g. "Simple").
- Sets logo, Title, Subtitle.
- Adds right-side action icons (image + tooltip + click script).
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
Array of items with properties:
- Icon     : Name or file path. If a function Resolve-WpfIcon exists, it will be used to resolve names
             (e.g., "Github" -> <moduleRoot>\Assets\Icons\Github.png). Otherwise a literal/file path is used.
- ToolTip  : string (optional)
- Click    : scriptblock (optional) – executed on MouseLeftButtonUp

Examples:
@(
  @{ Icon = 'Github';   ToolTip='Open GitHub';   Click = { Start-Process 'https://github.com/bluagentis' } },
  @{ Icon = 'LinkedIn'; ToolTip='LinkedIn';      Click = { Start-Process 'https://www.linkedin.com/in/kristianbuch/' } }
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
Suppresses informational logging (uses Write-Msg if available).

.NOTES
📦 CONTENT
 Module     ▹ Bluarch.WpfTools
 Function   ▹
 Version    ▹ 1.0.0
 Published  ▹ 2025-08-

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
        [ValidateSet('Simple','Advanced')]
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

        [switch]$PassThru
    )

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
        $bmp.EndInit()
        $bmp.Freeze()
        return $bmp
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
        # Icon file: $PSScriptRoot\Assets\Icons\<Icon>.png
        $iconName = [string]$item.Icon
        if ([string]::IsNullOrWhiteSpace($iconName))
        {
            continue
        }

        $iconPath = Join-Path $PSScriptRoot ("Assets\Icons\{0}.png" -f $iconName)
        if (-not (Test-Path -LiteralPath $iconPath))
        {
            # Try .ico as fallback
            $iconPathIco = [System.IO.Path]::ChangeExtension($iconPath, '.ico')
            if (Test-Path -LiteralPath $iconPathIco)
            {
                $iconPath = $iconPathIco
            }
            else
            {
                throw "Icon not found: $iconPath"
            }
        }

        $img = New-Object System.Windows.Controls.Image
        $img.Width = 28
        $img.Height = 28
        $img.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
        $img.Stretch = [System.Windows.Media.Stretch]::Uniform
        $img.Cursor = [System.Windows.Input.Cursors]::Hand
        $img.SnapsToDevicePixels = $true
        $img.Source = New-BitmapImage $iconPath
        if ($item.ToolTip)
        {
            $img.ToolTip = [string]$item.ToolTip
        }

        # Normalize Click into a scriptblock
        $clickSB = $null
        if ($item.Click -is [scriptblock])
        {
            $clickSB = $item.Click.GetNewClosure()
        }
        elseif ($item.Click -is [string])
        {
            $clickStr = [string]$item.Click
            if ($clickStr -match '^(https?://)')
            {
                $urlLocal = $clickStr
                $clickSB = { Start-Process $urlLocal }
            }
            elseif ($clickStr.Trim().Length)
            {
                # Allow raw PowerShell code as string
                $clickSB = [scriptblock]::Create($clickStr)
            }
        }

        if ($clickSB)
        {
            # Store the action on the Image instance to avoid closure/scope issues
            $img.Tag = $clickSB

            # Mouse click
            $img.Add_MouseLeftButtonUp({
                    param($sender, $e)
                    $e.Handled = $true
                    $sb = $sender.Tag
                    if ($sb -is [scriptblock])
                    {
                        & $sb
                    }
                })

            # Keyboard activation (Enter/Space)
            $img.Focusable = $true
            $img.Add_KeyDown({
                    param($sender, $e)
                    if ($e.Key -eq [System.Windows.Input.Key]::Enter -or
                        $e.Key -eq [System.Windows.Input.Key]::Space)
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
    }

    if ($PassThru)
    {
        return $ctrl
    }
}
