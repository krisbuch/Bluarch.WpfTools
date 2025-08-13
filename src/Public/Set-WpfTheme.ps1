function Set-WpfTheme
{
    <#
.SYNOPSIS
    Merge BaseStyles and a Theme ResourceDictionary into Application or a specific Window.

.DESCRIPTION
    Loads ResourceDictionary XAML with XamlReader (so the keys are actually materialized),
    then merges them in the correct order: BaseStyles FIRST, Theme SECOND.

    You can target:
      - Application scope (default), or
      - Window scope (pass -Scope Window -Window $win)

    You can clear all existing merged dictionaries first (-ClearExisting),
    or just replace duplicates from the same Source (-ReplaceExisting).

    Logging uses Write-Msg when available; otherwise falls back to Write-Host.

.PARAMETER BaseStylesPath
    Optional explicit path to BaseStyles XAML (e.g. "$PSScriptRoot\Themes\BaseStyles.xaml").
    If omitted, the function will look for "Themes\BaseStyles.xaml" in the module’s $PSScriptRoot.
    If not found, BaseStyles are skipped.

.PARAMETER Theme
    A value from your [Themes] enum (e.g. DarkSlate, NordBlue, CleanLight, HighContrast, None).
    When supplied (and not None), the Theme file is resolved as:
        "$PSScriptRoot\Themes\Theme.<Theme>.xaml"

.PARAMETER ThemePath
    Explicit path to a Theme ResourceDictionary XAML. If provided, it overrides -Theme.

.PARAMETER Scope
    Where to merge the dictionaries. 'Application' (default) or 'Window'.

.PARAMETER Window
    A FrameworkElement (typically a Window). Required when -Scope Window is used.

.PARAMETER ClearExisting
    Clear ALL existing MergedDictionaries at the chosen scope before adding BaseStyles/Theme.

.PARAMETER ReplaceExisting
    Remove any existing merged dictionaries with the same Source (AbsoluteUri) before adding.

.PARAMETER ValidateKeys
    Validate that these resource keys resolve (using TryFindResource) after the merge.
    Defaults to a few common theme keys. Pass @() to skip.

.PARAMETER PassThru
    Return an object describing the merge (paths, scope, counts).

.PARAMETER Silent
    Suppress console output (affects Write-Msg/Write-Host logging only).

.EXAMPLE
    Set-WpfTheme -Theme DarkSlate

    Merges Themes\BaseStyles.xaml (if found) and Themes\Theme.DarkSlate.xaml at Application scope.

.EXAMPLE
    Set-WpfTheme -ThemePath "$PSScriptRoot\Themes\Theme.NordBlue.xaml" -Scope Window -Window $win -ReplaceExisting

    Merges BaseStyles (if found) and NordBlue only on this specific Window, replacing a prior NordBlue.

.EXAMPLE
    # Typical startup sequence
    Import-Module Bluarch.WpfTools -Force
    Load-WpfAssembly -Preset Standard -Silent
    Set-WpfTheme -BaseStylesPath "$proj\Themes\BaseStyles.xaml" -Theme DarkSlate -ClearExisting
    $mw = Add-WpfMainWindow -Type Default -Title 'Bluarch' -PassThru

.NOTES
    - Runs only on Windows (WPF).
    - Ensure STA: Start PowerShell with -STA or use an STA runspace.

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
    param (
        [Parameter()]
        [string]$BaseStylesPath,

        [Parameter()]
        [Themes]$Theme,

        [Parameter()]
        [string]$ThemePath,

        [Parameter()]
        [ValidateSet('Application', 'Window')]
        [string]$Scope = 'Application',

        [Parameter()]
        [System.Windows.FrameworkElement]$Window,

        [Parameter()]
        [switch]$ClearExisting,

        [Parameter()]
        [switch]$ReplaceExisting,

        [Parameter()]
        [string[]]$ValidateKeys = @(
            'BrushHeaderBG', 'BrushHeaderBorder', 'BrushHeaderFG', 'BrushHeaderSubFG', 'AccentBrush'
        ),

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$Silent
    )

    # --- Environment checks ---
    if ($IsWindows -ne $true)
    {
        throw "WPF is only supported on Windows."
    }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA')
    {
        throw "WPF requires STA. Start PowerShell with -STA or use an STA runspace."
    }

    # --- Logger (Write-Msg if available) ---
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
    function _log([string]$msg, [string]$symbol = '📚', [string]$fg = 'Gray')
    {
        if ($Silent)
        {
            return
        }
        if ($haveWriteMsg)
        {
            Write-Msg $symbol $msg -Foreground $fg -UseRuntime
        }
        else
        {
            Write-Host $msg -ForegroundColor $fg
        }
    }
    function _ok([string]$msg)
    {
        _log $msg '✅' 'Green'
    }
    function _warn([string]$msg)
    {
        _log $msg '⚠️' 'Yellow'
    }
    function _err([string]$msg)
    {
        _log $msg '❗' 'Red'
    }

    # --- Resolve defaults ---
    # Default BaseStyles: <module>\Themes\BaseStyles.xaml
    if (-not $BaseStylesPath)
    {
        $BaseStylesPath = Join-Path $PSScriptRoot 'Themes\BaseStyles.xaml'
        if (-not (Test-Path -LiteralPath $BaseStylesPath))
        {
            $BaseStylesPath = $null
        }
    }

    # ThemePath overrides Theme; otherwise build ThemePath from enum
    if (-not $ThemePath -and $PSBoundParameters.ContainsKey('Theme') -and $Theme -and ($Theme.ToString() -ne 'None'))
    {
        $ThemePath = Join-Path $PSScriptRoot ("Themes\Theme.{0}.xaml" -f $Theme)
    }

    # --- Target scope ---
    $app = [System.Windows.Application]::Current
    if (-not $app)
    {
        $app = [System.Windows.Application]::new()
    }

    $targetRD = if ($Scope -eq 'Window')
    {
        if (-not $Window)
        {
            throw "When -Scope Window is used, you must pass -Window."
        }
        if (-not $Window.Resources)
        {
            $Window.Resources = [System.Windows.ResourceDictionary]::new()
        }
        $Window.Resources
    }
    else
    {
        if (-not $app.Resources)
        {
            $app.Resources = [System.Windows.ResourceDictionary]::new()
        }
        $app.Resources
    }

    # --- Helper: load RD via XamlReader ---
    function Load-RD([string]$path)
    {
        if (-not $path)
        {
            return $null
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf))
        {
            throw "Not found: $path"
        }
        return [Windows.Markup.XamlReader]::Load(
            [System.Xml.XmlNodeReader]::new([xml](Get-Content -Raw -LiteralPath $path))
        )
    }

    # --- Optional clearing ---
    if ($ClearExisting)
    {
        _log "Clearing MergedDictionaries at $Scope scope..." '📦'
        $targetRD.MergedDictionaries.Clear()
    }

    # --- Merge BaseStyles then Theme ---
    $added = New-Object System.Collections.Generic.List[string]
    $skipped = New-Object System.Collections.Generic.List[string]

    if ($BaseStylesPath)
    {
        try
        {
            $rdBase = Load-RD $BaseStylesPath
            if ($rdBase)
            {
                if ($ReplaceExisting)
                {
                    $uri = $rdBase.Source
                    if ($uri)
                    {
                        $dupes = @($targetRD.MergedDictionaries | Where-Object { $_.Source -and $_.Source.AbsoluteUri -eq $uri.AbsoluteUri })
                        foreach ($d in $dupes)
                        {
                            [void]$targetRD.MergedDictionaries.Remove($d)
                        }
                    }
                }
                _log "Merging BaseStyles ($Scope scope) BEFORE XAML..." '📚'
                [void]$targetRD.MergedDictionaries.Add($rdBase)
                _ok "Merged RD ($Scope): $BaseStylesPath"
                $added.Add($BaseStylesPath) | Out-Null
            }
        }
        catch
        {
            _err "Failed to load BaseStyles: $BaseStylesPath -> $($_.Exception.Message)"
        }
    }
    else
    {
        _warn "No BaseStyles provided/found. Skipping."
    }

    if ($ThemePath)
    {
        try
        {
            $rdTheme = Load-RD $ThemePath
            if ($rdTheme)
            {
                if ($ReplaceExisting)
                {
                    $uri = $rdTheme.Source
                    if ($uri)
                    {
                        $dupes = @($targetRD.MergedDictionaries | Where-Object { $_.Source -and $_.Source.AbsoluteUri -eq $uri.AbsoluteUri })
                        foreach ($d in $dupes)
                        {
                            [void]$targetRD.MergedDictionaries.Remove($d)
                        }
                    }
                }
                _log "Merging Theme '$([System.IO.Path]::GetFileNameWithoutExtension($ThemePath))' ($Scope scope) BEFORE XAML..." '📚'
                [void]$targetRD.MergedDictionaries.Add($rdTheme)
                _ok "Merged RD ($Scope): $ThemePath"
                $added.Add($ThemePath) | Out-Null
            }
        }
        catch
        {
            _err "Failed to load Theme: $ThemePath -> $($_.Exception.Message)"
        }
    }
    else
    {
        if ($PSBoundParameters.ContainsKey('Theme') -and ($Theme -and ($Theme.ToString() -ne 'None')))
        {
            _err "Theme '$Theme' was requested, but ThemePath could not be resolved."
        }
        else
        {
            _log "No Theme provided. Only BaseStyles (if any) merged." 'ℹ️' 'DarkGray'
        }
    }

    # --- Optional key validation ---
    if ($ValidateKeys -and $ValidateKeys.Count -gt 0)
    {
        # Pick a probing element to use TryFindResource
        $probe = if ($Scope -eq 'Window')
        {
            $Window
        }
        else
        {
            $app.MainWindow ?? $app
        }
        foreach ($k in $ValidateKeys)
        {
            $found = $false
            try
            {
                $val = $probe.TryFindResource($k)
                $found = [bool]$val
            }
            catch
            {
                $found = $false
            }
            _log ("{0,-18} -> {1}" -f $k, $found) ($found ? '✅' : '⚠️') ($found ? 'Green' : 'Yellow')
        }
    }

    if ($PassThru)
    {
        [pscustomobject]@{
            Scope          = $Scope
            BaseStylesPath = $BaseStylesPath
            ThemePath      = $ThemePath
            Added          = [string[]]$added
            Skipped        = [string[]]$skipped
            Count          = $targetRD.MergedDictionaries.Count
        }
    }
}
