function Set-WpfImage
{
<#
.SYNOPSIS
Sets the source, tooltip, stretch mode, dimensions, and opacity of a WPF Image control by its x:Name.

.DESCRIPTION
The Set-WpfImage function locates a WPF Image control within a given root element by its x:Name, then sets its image source from a specified file path. It also allows optional configuration of the image's tooltip, stretch mode, width, height, and opacity. The image file is loaded with the OnLoad cache option to avoid file locks.

.PARAMETER Root
The root WPF FrameworkElement containing the Image control.

.PARAMETER Name
The x:Name of the Image control to update.

.PARAMETER Path
The file path to the image to display. Relative paths are resolved using $PSScriptRoot or the current location.

.PARAMETER ToolTip
Optional tooltip text to display when hovering over the image.

.PARAMETER Stretch
Optional stretch mode for the image. Valid values are 'Uniform', 'UniformToFill', 'Fill', and 'None'. Default is 'Uniform'.

.PARAMETER Width
Optional width to set for the Image control.

.PARAMETER Height
Optional height to set for the Image control.

.PARAMETER Opacity
Optional opacity value for the Image control, between 0.0 and 1.0.

.EXAMPLE
Set-WpfImage -Root $window -Name 'LogoImage' -Path 'Images/logo.png' -ToolTip 'Company Logo' -Stretch 'Uniform' -Width 128 -Height 128 -Opacity 0.9

.NOTES
Requires PowerShell with access to WPF types (e.g., running in a WPF host or with Add-Type for PresentationFramework).

Author      : Kristian Holm Buch
Date        : 2025-08-11
Copyright   : (C) 2025 - Kristian Holm Buch. All rights reserved.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.FrameworkElement]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$ToolTip,

        [Parameter()]
        [ValidateSet('Uniform', 'UniformToFill', 'Fill', 'None')]
        [System.Windows.Media.Stretch]$Stretch = 'Uniform',

        [Parameter()]
        [int]$Width,

        [Parameter()]
        [int]$Height,

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$Opacity
    )

    # Find the Image control by x:Name
    $img = $Root.FindName($Name)
    if (-not ($img -is [System.Windows.Controls.Image]))
    {
        $foundType = if ($img)
        {
            $img.GetType().FullName
        }
        else
        {
            'null'
        }
        throw "Could not find an Image control with x:Name '$Name'. Found type: $foundType."
    }
    # Make path absolute if it's relative
    if (-not [System.IO.Path]::IsPathRooted($Path))
    {
        # Prefer $PSScriptRoot if available, otherwise use current location
        if ($PSScriptRoot)
        {
            $Path = Join-Path $PSScriptRoot $Path
        }
        else
        {
            $Path = Join-Path (Get-Location) $Path
        }
    }


    # Load bitmap (OnLoad to avoid file locks)
    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit()
    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bmp.UriSource = [System.Uri]::new($Path, [System.UriKind]::RelativeOrAbsolute)
    $bmp.EndInit()
    if ($bmp.CanFreeze)
    {
        $bmp.Freeze()
    }
    # Set image source, tooltip, and stretch
    $img.Source = $bmp
    if ($ToolTip)
    {
        $img.ToolTip = $ToolTip
    }
    $img.Stretch = [System.Windows.Media.Stretch]::$Stretch

    # Set width and height if provided
    if ($Width)
    {
        $img.Width = $Width
    }
    if ($Height)
    {
        $img.Height = $Height
    }
    if ($Opacity)
    {
        $img.Opacity = $Opacity
    }
}
