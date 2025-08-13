# --- robust theme merge (uden XamlReader) ---
function Merge-ResourceDictionary {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [ValidateSet('Application','Window','Both')] [string]$Scope = 'Both',
        [System.Windows.FrameworkElement]$Window,
        [switch]$ClearFirst
    )

    if (-not (Test-Path -LiteralPath $Path)) { throw "RD not found: $Path" }

    $abs = (Resolve-Path -LiteralPath $Path).ProviderPath
    $uri = [Uri]::new($abs, [UriKind]::Absolute)

    $rd = [System.Windows.ResourceDictionary]::new()
    $rd.Source = $uri   # <- vigtigt: brug Source, ikke XamlReader

    $app = [System.Windows.Application]::Current
    if (-not $app) { $app = [System.Windows.Application]::new() }

    if ($Scope -in 'Application','Both') {
        if ($ClearFirst) { $app.Resources.MergedDictionaries.Clear() }
        # fjern dublet med samme Source:
        foreach ($d in @($app.Resources.MergedDictionaries | ? { $_.Source -and $_.Source.AbsoluteUri -eq $rd.Source.AbsoluteUri })) {
            [void]$app.Resources.MergedDictionaries.Remove($d)
        }
        [void]$app.Resources.MergedDictionaries.Add($rd)
    }

    if ($Scope -in 'Window','Both') {
        if (-not $Window) { throw "Scope=Window kræver -Window." }
        if (-not $Window.Resources) { $Window.Resources = [System.Windows.ResourceDictionary]::new() }
        if ($ClearFirst) { $Window.Resources.MergedDictionaries.Clear() }
        foreach ($d in @($Window.Resources.MergedDictionaries | ? { $_.Source -and $_.Source.AbsoluteUri -eq $rd.Source.AbsoluteUri })) {
            [void]$Window.Resources.MergedDictionaries.Remove($d)
        }
        [void]$Window.Resources.MergedDictionaries.Add($rd)
    }

    return $rd.Source.AbsoluteUri
}

# --- brug det sådan her ---
# 1) (valgfrit) opret/vælg et vindue først
$win = [System.Windows.Window]::new()

# 2) merge BaseStyles før Theme (samme scope – her Window)
$base = Join-Path $PSScriptRoot 'Themes\BaseStyles.xaml'
$theme = Join-Path $PSScriptRoot 'Themes\Theme.DarkSlate.xaml'   # VÆLG den fil der faktisk har dine nøgler

[void](Merge-ResourceDictionary -Path $base  -Scope Window -Window $win -ClearFirst)
[void](Merge-ResourceDictionary -Path $theme -Scope Window -Window $win)

# 3) tjek at nøglerne nu findes fra vinduet
'BrushHeaderBG','BrushHeaderBorder','BrushHeaderFG','BrushHeaderSubFG','AccentBrush' |
  % { '{0,-18} -> {1}' -f $_, [bool]$win.TryFindResource($_) } | Write-Host
