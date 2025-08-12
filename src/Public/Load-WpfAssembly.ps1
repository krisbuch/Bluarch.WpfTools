function Load-WpfAssembly
{
    <#
.SYNOPSIS
Loads the Windows WPF assemblies you need (and optionally popular WPF packages) in a safe, idempotent way.

.DESCRIPTION
Builds a list of assemblies from a preset (Minimal/Standard/Extended/All), optionally adds named package groups
(MahApps, ModernWpf, MaterialDesign, FluentWpf) and any manual assembly names. Each assembly is loaded if not present.
Supports probing custom folders and (optionally) wiring AssemblyResolve to those folders.

.PARAMETER Preset
- Minimal  : WindowsBase, PresentationCore
- Standard : + PresentationFramework, System.Xaml   (DEFAULT)
- Extended : + ReachFramework, UIAutomationTypes, UIAutomationClient, WindowsFormsIntegration
- All      : Extended + System.Windows.Forms, System.Drawing

.PARAMETER Packages
Optional package shortcuts (if present on disk or in the GAC):
- MahApps        -> MahApps.Metro, ControlzEx
- ModernWpf      -> ModernWpf, ModernWpf.Controls
- MaterialDesign -> MaterialDesignThemes.Wpf, MaterialDesignColors
- FluentWpf      -> FluentWPF

.PARAMETER Assemblies
Additional assembly names to load (e.g. 'PresentationFramework.Aero2').

.PARAMETER ProbingPaths
One or more folders to search recursively for *.dll (e.g. "$PSScriptRoot\Lib").

.PARAMETER WireAssemblyResolve
Attach an AssemblyResolve handler that resolves from ProbingPaths (good for transitive deps like ControlzEx).

.PARAMETER ThrowOnError
Throw on the first failure instead of continuing.

.PARAMETER PassThru
Return a summary object (Loaded/Skipped/Failed).

.PARAMETER Silent
Suppress log output (respected by Write-Msg if available).

.EXAMPLE
Load-WpfAssembly
# Loads Standard preset: WindowsBase, PresentationCore, PresentationFramework, System.Xaml

.EXAMPLE
Load-WpfAssembly -Preset Extended -Packages MahApps,MaterialDesign -ProbingPaths "$PSScriptRoot\Lib" -WireAssemblyResolve
# Probes your Lib folder and wires AssemblyResolve so deps are found there.

.EXAMPLE
Load-WpfAssembly -Assemblies PresentationFramework.Aero2 -PassThru
# Adds an extra theme assembly and returns a summary.
#>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('Minimal', 'Standard', 'Extended', 'All')]
        [string]$Preset = 'Standard',

        [Parameter()]
        [ValidateSet('MahApps', 'ModernWpf', 'MaterialDesign', 'FluentWpf')]
        [string[]]$Packages,

        [Parameter()]
        [string[]]$Assemblies,

        [Parameter()]
        [string[]]$ProbingPaths,

        [Parameter()]
        [switch]$WireAssemblyResolve,

        [Parameter()]
        [switch]$ThrowOnError,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$Silent
    )

    if (-not $IsWindows)
    {
        throw "WPF is only supported on Windows."
    }

    # --- logging shim (uses Write-Msg if available) ---
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
    function _log([string]$msg, [string]$symbol = '📚', [string]$color = 'Gray')
    {
        if ($haveWriteMsg)
        {
            Write-Msg $symbol $msg -Foreground $color -Silent:$Silent
        }
        elseif (-not $Silent)
        {
            Write-Host $msg -ForegroundColor $color
        }
    }
    function _ok ([string]$msg)
    {
        _log $msg '✅' 'Green'
    }
    function _wrn([string]$msg)
    {
        _log $msg '⚠️' 'Yellow'
    }
    function _err([string]$msg)
    {
        _log $msg '❗' 'Red'
    }

    # --- presets ---
    $profiles = @{
        Minimal  = @('WindowsBase', 'PresentationCore')
        Standard = @('WindowsBase', 'PresentationCore', 'PresentationFramework', 'System.Xaml')
        Extended = @('WindowsBase', 'PresentationCore', 'PresentationFramework', 'System.Xaml',
            'ReachFramework', 'UIAutomationTypes', 'UIAutomationClient', 'WindowsFormsIntegration')
        All      = @('WindowsBase', 'PresentationCore', 'PresentationFramework', 'System.Xaml',
            'ReachFramework', 'UIAutomationTypes', 'UIAutomationClient', 'WindowsFormsIntegration',
            'System.Windows.Forms', 'System.Drawing')
    }

    # --- package groups ---
    $pkgAssemblies = @{
        MahApps        = @('MahApps.Metro', 'ControlzEx')
        ModernWpf      = @('ModernWpf', 'ModernWpf.Controls')
        MaterialDesign = @('MaterialDesignThemes.Wpf', 'MaterialDesignColors')
        FluentWpf      = @('FluentWPF')
    }

    # --- build target list (unique, ordered) ---
    $target = [System.Collections.Generic.List[string]]::new()
    foreach ($n in $profiles[$Preset])
    {
        if (-not $target.Contains($n))
        {
            $target.Add($n)
        }
    }
    foreach ($p in ($Packages ?? @()))
    {
        foreach ($n in $pkgAssemblies[$p])
        {
            if (-not $target.Contains($n))
            {
                $target.Add($n)
            }
        }
    }
    foreach ($n in ($Assemblies ?? @()))
    {
        if (-not $target.Contains($n))
        {
            $target.Add($n)
        }
    }
    if ($target.Count -eq 0)
    {
        return
    }

    # --- probe index (case-insensitive base-name -> full path) ---
    $script:__LoadWpfAssembly_Probe = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in ($ProbingPaths ?? @()))
    {
        if (Test-Path -LiteralPath $p)
        {
            Get-ChildItem -Path $p -Filter *.dll -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $script:__LoadWpfAssembly_Probe[$_.BaseName] = $_.FullName
            }
        }
        else
        {
            _wrn "Probing path not found: $p"
        }
    }

    # --- optional AssemblyResolve wiring ---
    if ($WireAssemblyResolve -and $script:__LoadWpfAssembly_Probe.Count -gt 0)
    {
        if (-not $script:__LoadWpfAssembly_Resolver)
        {
            $script:__LoadWpfAssembly_Resolver = [System.ResolveEventHandler] {
                param($sender, $args)
                try
                {
                    $short = ($args.Name -split ',')[0]
                    if ($script:__LoadWpfAssembly_Probe.ContainsKey($short))
                    {
                        return [System.Reflection.Assembly]::LoadFrom($script:__LoadWpfAssembly_Probe[$short])
                    }
                }
                catch
                {
                }
                return $null
            }
            [AppDomain]::CurrentDomain.add_AssemblyResolve($script:__LoadWpfAssembly_Resolver)
            _log "AssemblyResolve wired to probing paths." '🧲' 'Gray'
        }
        else
        {
            # update probe dictionary for next resolves
            _log "AssemblyResolve already wired; probe index updated." '🧲' 'Gray'
        }
    }

    _log "Loading WPF assemblies (preset: $Preset)" '📚' 'Gray'

    $loaded = [System.Collections.Generic.List[string]]::new()
    $skipped = [System.Collections.Generic.List[string]]::new()
    $failed = [System.Collections.Generic.List[string]]::new()

    foreach ($name in $target)
    {
        try
        {
            # skip if already loaded
            $existing = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $name }
            if ($existing)
            {
                $skipped.Add("$name ($($existing.GetName().Version))") | Out-Null
                _log "Already loaded: $name ($($existing.GetName().Version))" '🗃️' 'DarkGray'
                continue
            }

            $ok = $false

            # 1) Add-Type
            try
            {
                Add-Type -AssemblyName $name -ErrorAction Stop | Out-Null
                $ok = $true
            }
            catch
            {
                # 2) Assembly.Load by name
                try
                {
                    [void][System.Reflection.Assembly]::Load($name)
                    $ok = $true
                }
                catch
                {
                    # 3) Probe folders -> LoadFrom
                    if ($script:__LoadWpfAssembly_Probe.ContainsKey($name))
                    {
                        [void][System.Reflection.Assembly]::LoadFrom($script:__LoadWpfAssembly_Probe[$name])
                        $ok = $true
                    }
                }
            }

            if ($ok)
            {
                $now = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq $name }
                if ($now)
                {
                    $loaded.Add("$name ($($now.GetName().Version))") | Out-Null
                    _ok "Loaded: $name ($($now.GetName().Version))"
                }
                else
                {
                    throw "Assembly '$name' appears not loaded after attempts."
                }
            }
            else
            {
                throw "Assembly '$name' not found (Add-Type/Load/Probe all failed)."
            }
        }
        catch
        {
            $failed.Add($name) | Out-Null
            _err "Failed to load: $name -> $($_.Exception.Message)"
            if ($ThrowOnError)
            {
                throw
            }
        }
    }

    if ($PassThru)
    {
        [pscustomobject]@{
            Preset   = $Preset
            Packages = $Packages
            Loaded   = [string[]]$loaded
            Skipped  = [string[]]$skipped
            Failed   = [string[]]$failed
        }
    }
}
