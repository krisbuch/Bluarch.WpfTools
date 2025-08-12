function Set-WpfIcon {
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
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Windows.FrameworkElement]$Xaml,
        [Parameter(Mandatory)][Alias('Name','x:Name')][string]$xName,
        [Parameter(Mandatory)][string]$Name,
        [int]$Size,
        [switch]$Silent
    )

    $img = $Xaml.FindName($xName)
    if (-not $img) { throw "Element with x:Name '$xName' not found." }
    if ($img -isnot [System.Windows.Controls.Image]) { throw "'$xName' is not an Image control." }

    $src = Resolve-WpfIcon -Name $Name -Size $Size -AsImageSource -Silent:$Silent
    if ($null -eq $src) { throw "Icon '$Name' could not be resolved." }

    $img.Source = $src
}
