function Insert-WpfIcon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Root = $PSScriptRoot
    )
    Resolve-WpfIcon -Name $Name -Root $Root
}
