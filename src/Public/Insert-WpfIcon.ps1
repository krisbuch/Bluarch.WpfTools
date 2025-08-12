function Insert-WpfIcon
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Icons]$Name,

        [Parameter()]
        [string]$Root = $PSScriptRoot
    )
    Resolve-WpfIcon -Name $Name -Root $Root
}
