function Insert-WpfIcon
{
<#
.NOTES
    📦 CONTENT
    Module     ▹ Bluarch.WpfTools
    Function   ▹ Insert-WpfIcon
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
    param(
        [Parameter(Mandatory = $true)]
        [Icons]$Name,

        [Parameter()]
        [string]$Root = $PSScriptRoot
    )
    Resolve-WpfIcon -Name $Name -Root $Root
}
