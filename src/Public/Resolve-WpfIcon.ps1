function Resolve-WpfIcon
{
    <#
.SYNOPSIS
Resolve an icon name to a concrete file path (or a BitmapImage).

.DESCRIPTION
Searches common asset folders (default: $Root\Assets\Icons) for a file matching
the given Name and optional Size hint. Supports .png, .ico, .jpg/.jpeg, .bmp, .svg
(svg returneres som path; WPF loader ikke svg nativt). Returns either a string path
(default) or a frozen BitmapImage when -AsImageSource is used.

.PARAMETER Name
Logical icon name, e.g. "Github", "LinkedIn", "Home".
You can also pass a direct file path — then it’s just validated/resolved.

.PARAMETER Root
Project root. Default = $PSScriptRoot (hvis sat i din kalder).

.PARAMETER Library
Relative subfolder to search first. Default = "Assets\Icons".

.PARAMETER Size
Optional size hint (e.g. 16, 24, 32, 48, 96). We try to prefer files/folders
containing that size in the name or path.

.PARAMETER Extensions
Override/extend allowed file extensions.

.PARAMETER AsImageSource
Return a [System.Windows.Media.Imaging.BitmapImage] instead of a path.

.PARAMETER ThrowOnNotFound
Throw if not found (otherwise return $null).

.PARAMETER Silent
Suppress logging via Write-Msg/Write-Host.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Icons]$Name,

        [Parameter()]
        [string]$Root = $PSScriptRoot,

        [Parameter()]
        [string]$Library = 'Assets\Icons',

        [Parameter()]
        [int]$Size,

        [Parameter()]
        [string[]]$Extensions = @('.png', '.ico', '.jpg', '.jpeg', '.bmp', '.svg'),

        [Parameter()]
        [switch]$AsImageSource,

        [Parameter()]
        [switch]$ThrowOnNotFound,

        [Parameter()]
        [switch]$Silent
    )

    # --- logging shim ---
    $haveWriteMsg = Get-Command -Name Write-Msg -ErrorAction SilentlyContinue
    function _log([string]$msg, [string]$symbol = '📚', [string]$color = 'Gray')
    {
        if ($Silent)
        {
            return
        }
        if ($haveWriteMsg)
        {
            Write-Msg $symbol $msg -Foreground $color
        }
        else
        {
            Write-Host $msg -ForegroundColor $color
        }
    }
    function _warn([string]$msg)
    {
        _log $msg '⚠️' 'Yellow'
    }
    function _ok  ([string]$msg)
    {
        _log $msg '✅' 'Green'
    }

    # Direct path?
    if (Test-Path -LiteralPath $Name)
    {
        $path = (Resolve-Path -LiteralPath $Name).ProviderPath
        if ($AsImageSource -and [System.IO.Path]::GetExtension($path) -ne '.svg')
        {
            $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bi.BeginInit(); $bi.UriSource = [Uri]$path; $bi.CacheOption = 'OnLoad'; $bi.EndInit(); $bi.Freeze()
            return $bi
        }
        return $path
    }

    # Build search roots
    $roots = @()
    if ($Root)
    {
        if ($Library)
        {
            $roots += (Join-Path $Root $Library)
        }
        $roots += $Root
        # A few common fallbacks
        $roots += @(Join-Path $Root 'Assets'),
        (Join-Path $Root 'Assets\Icon'),
        (Join-Path $Root 'Assets\IconLib'),
        (Join-Path $Root 'Assets\Images')
    }
    $roots = $roots | Where-Object { Test-Path $_ } | Select-Object -Unique
    if (-not $roots)
    {
        $roots = @((Get-Location).Path)
    }

    # Candidate name variants
    $baseNames = @(
        $Name,
        ($Name -replace '\s', ''),
        ($Name -replace '[_\s]', '-'),
        $Name.ToLowerInvariant(),
        $Name.ToUpperInvariant()
    ) | Select-Object -Unique

    # Collect matches
    $matches = New-Object System.Collections.Generic.List[psobject]
    foreach ($r in $roots)
    {
        foreach ($ext in $Extensions)
        {
            foreach ($bn in $baseNames)
            {
                # Exact file name
                $file = Join-Path $r ($bn + $ext)
                if (Test-Path $file)
                {
                    $matches.Add([pscustomobject]@{
                            Path  = (Resolve-Path $file).ProviderPath
                            Score = 0
                        }) | Out-Null
                }
            }
        }
        # Recursive search by name contains
        Get-ChildItem -Path $r -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $Extensions -contains ([System.IO.Path]::GetExtension($_.Name).ToLowerInvariant()) -and
                ($baseNames | ForEach-Object { $_ }) -contains $_.BaseName -or
                ($baseNames | ForEach-Object { $bn = $_; $_ }) | Out-Null
            } | ForEach-Object {
                $matches.Add([pscustomobject]@{
                        Path  = $_.FullName
                        Score = 5
                    }) | Out-Null
            }
        # Fuzzy contains (e.g. name present inside filename)
        Get-ChildItem -Path $r -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $Extensions -contains ([System.IO.Path]::GetExtension($_.Name).ToLowerInvariant()) -and
                ($baseNames | Where-Object { $_ -and $_ -ne '' -and $_ -match [regex]::Escape($_) }) -ne $null -and
                ($_.BaseName -match ($baseNames -join '|'))
            } | ForEach-Object {
                $matches.Add([pscustomobject]@{
                        Path  = $_.FullName
                        Score = 9
                    }) | Out-Null
            }
    }

    if ($Size)
    {
        # Prefer files/paths that mention the size (e.g., "...48...", "\48\", "-48", "@48x48")
        foreach ($m in $matches)
        {
            if ($m.Path -match "(^|[\\/_\-])$Size(x$Size)?([._\-\\/]|$)")
            {
                $m.Score -= 3
            }
        }
    }

    if (-not $matches.Count)
    {
        $msg = "Icon '$Name' not found under roots: " + ($roots -join '; ')
        if ($ThrowOnNotFound)
        {
            throw $msg
        }
        else
        {
            _warn $msg; return $null
        }
    }

    $hit = $matches | Sort-Object Score, Path | Select-Object -First 1
    _ok "Resolved icon '$Name' -> $($hit.Path)"

    if ($AsImageSource)
    {
        if ([System.IO.Path]::GetExtension($hit.Path).ToLowerInvariant() -eq '.svg')
        {
            _warn "SVG requires a converter; returning path instead of ImageSource."
            return $hit.Path
        }
        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit()
        $bi.UriSource = [Uri]$hit.Path
        $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.EndInit()
        $bi.Freeze()
        return $bi
    }

    return $hit.Path
}
