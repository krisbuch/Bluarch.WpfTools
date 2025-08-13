function Set-WpfIcon
{
    <#
.SYNOPSIS
    Set an Image control's Source by resolving a logical icon name.

.PARAMETER Xaml
    FrameworkElement hosting the Image.

.PARAMETER xName
    x:Name of the Image control.

.PARAMETER Name
    Logical icon name or direct file path.

.PARAMETER Size
    Size hint passed to Resolve-WpfIcon.

.PARAMETER Silent
    Suppress logging.
.NOTES
    📦 CONTENT
    Module     ▹ Bluarch.WpfTools
    Function   ▹ Set-WpfIcon
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
        [Parameter(Mandatory = $true)]
        [System.Windows.FrameworkElement]$Xaml,

        [Parameter(Mandatory = $true)]
        [Alias('Name', 'x:Name')]
        [string]$xName,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [int]$Size,

        [Parameter()]
        [switch]$Silent
    )

    $img = $Xaml.FindName($xName)
    if (-not $img)
    {
        throw "Element with x:Name '$xName' not found."
    }
    if ($img -isnot [System.Windows.Controls.Image])
    {
        throw "'$xName' is not an Image control."
    }

    $src = Resolve-WpfIcon -Name $Name -Size $Size -AsImageSource -Silent:$Silent
    if ($null -eq $src)
    {
        throw "Icon '$Name' could not be resolved."
    }

    $img.Source = $src
}
