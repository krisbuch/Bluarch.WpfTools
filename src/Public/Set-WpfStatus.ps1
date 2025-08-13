function Set-WpfStatus
{
    <#
.SYNOPSIS
    Updates footer status text and progress (supports levels, auto-color, timers, and animations).

.DESCRIPTION
    Works best with the PSCustomObject returned by Add-WpfFooter (-Footer param).
    You may also pass the raw controls via -StatusText/-ProgressBar.

.PARAMETER Footer
    The API object from Add-WpfFooter (contains StatusText and ProgressBar).

.PARAMETER StatusText
.PARAMETER ProgressBar
    Direct WPF controls (alternative to -Footer).

.PARAMETER Message
    Status message (will be truncated to 20 chars to fit your footer spec).

.PARAMETER Level
    Info | Success | Warning | Error | Neutral (sets StatusText.Foreground).

.PARAMETER Percent
    Set progress directly (0..100). Turns off indeterminate.

.PARAMETER To
    Target percent (default 100 when used with -TimeoutSeconds).

.PARAMETER TimeoutSeconds
    Animate progress from current (or 0 if collapsed) to -To within TimeoutSeconds.

.PARAMETER Indeterminate
    Set progress to indeterminate.

.PARAMETER Reset
    Stops timers, clears message, hides/zeroes progress.

.PARAMETER Color
    Explicit brush/color for the ProgressBar (e.g. "#2EA7FF" or a Brush). Overrides auto-color.

.PARAMETER AutoColor
    If set, ProgressBar color is chosen from percent bands (0-30 red, 30-60 orange, 60-85 gold, 85-100 green).

.PARAMETER ClearMessageOnCompletion
    When a timed animation completes (or To reached), clear the message after -ClearMessageDelay.

.PARAMETER ClearMessageDelay
    Seconds to wait before clearing message (default 1.5).

.PARAMETER HideProgressOnCompletion
    Hide the progress bar when the timed run hits the target.

#>
    [CmdletBinding(DefaultParameterSetName = 'ByFooter')]
    param(
        [Parameter(ParameterSetName = 'ByFooter', Mandatory)]
        [psobject]$Footer = $mw.FooterHost,

        [Parameter(ParameterSetName = 'ByElements')]
        [System.Windows.Controls.TextBlock]$StatusText,

        [Parameter(ParameterSetName = 'ByElements')]
        [System.Windows.Controls.ProgressBar]$ProgressBar,

        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Neutral')]
        [string]$Level = 'Info',

        [double]$Percent,
        [double]$To,
        [double]$TimeoutSeconds,

        [switch]$Indeterminate,
        [switch]$Reset,

        [object]$Color,         # string "#RRGGBB" or Brush
        [switch]$AutoColor,

        [switch]$ClearMessageOnCompletion,
        [double]$ClearMessageDelay = 1.5,
        [switch]$HideProgressOnCompletion
    )

    # --- Resolve controls ---
    if ($PSCmdlet.ParameterSetName -eq 'ByFooter')
    {
        if (-not $Footer -or -not $Footer.PSObject.Properties['StatusText'] -or -not $Footer.PSObject.Properties['ProgressBar'])
        {
            throw "Set-WpfStatus: -Footer doesn't expose StatusText/ProgressBar."
        }
        $StatusText = $Footer.StatusText
        $ProgressBar = $Footer.ProgressBar
    }
    if (-not $StatusText -or -not $ProgressBar)
    {
        throw "Set-WpfStatus: StatusText and ProgressBar were not resolved."
    }

    # --- Helpers ---
    Add-Type -AssemblyName PresentationCore, PresentationFramework -ErrorAction SilentlyContinue

    function Get-ResBrush
    {
        param([string]$Key, [System.Windows.Media.Brush]$Fallback)
        try
        {
            $b = [System.Windows.Application]::Current.Resources[$Key]
            if ($b -is [System.Windows.Media.Brush])
            {
                return $b
            }
        }
        catch
        {
        }
        return $Fallback
    }
    function To-Brush([object]$v)
    {
        if ($null -eq $v)
        {
            return $null
        }
        if ($v -is [System.Windows.Media.Brush])
        {
            return $v
        }
        $bc = [System.Windows.Media.BrushConverter]::new()
        try
        {
            return [System.Windows.Media.Brush]$bc.ConvertFromString([string]$v)
        }
        catch
        {
            throw "Invalid Color value: '$v'"
        }
    }
    function Clamp([double]$x, [double]$a = 0, [double]$b = 100)
    {
        if ($x -lt $a)
        {
            $a
        }
        elseif ($x -gt $b)
        {
            $b
        }
        else
        {
            $x
        }
    }

    # Color palettes
    $fgInfo = Get-ResBrush 'BrushFooterFG'      ([System.Windows.Media.Brushes]::LightGray)
    $fgSubtle = Get-ResBrush 'BrushSubtleFG'      ([System.Windows.Media.Brushes]::DarkGray)
    $fgSuccess = Get-ResBrush 'BrushSuccess'       ([System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::LimeGreen))
    $fgWarn = Get-ResBrush 'BrushWarning'       ([System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::DarkOrange))
    $fgError = Get-ResBrush 'BrushError'         ([System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Tomato))

    # Auto color ramps for progress
    $brushRed = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xE7, 0x4C, 0x3C))
    $brushOrange = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xF3, 0x9C, 0x12))
    $brushGold = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0xF1, 0xC4, 0x0F))
    $brushGreen = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x27, 0xAE, 0x60))

    function Get-AutoBrush([double]$pct)
    {
        $p = Clamp $pct
        if ($p -lt 30)
        {
            return $brushRed
        }
        elseif ($p -lt 60)
        {
            return $brushOrange
        }
        elseif ($p -lt 85)
        {
            return $brushGold
        }
        else
        {
            return $brushGreen
        }
    }

    # Store timers on the ProgressBar instance (persist between calls)
    if (-not $ProgressBar.PSObject.Properties['__StatusTimer'])
    {
        Add-Member -InputObject $ProgressBar -NotePropertyName '__StatusTimer' -NotePropertyValue $null -Force | Out-Null
    }
    if (-not $ProgressBar.PSObject.Properties['__ClearTimer'])
    {
        Add-Member -InputObject $ProgressBar -NotePropertyName '__ClearTimer' -NotePropertyValue $null -Force | Out-Null
    }

    # Stop & dispose helper
    function Stop-Timer([System.Windows.Threading.DispatcherTimer]$t)
    {
        if ($t)
        {
            $t.Stop(); $t.Tag = $null
        }
    }

    # --- Reset ---
    if ($Reset)
    {
        Stop-Timer $ProgressBar.__StatusTimer
        Stop-Timer $ProgressBar.__ClearTimer
        $ProgressBar.__StatusTimer = $null
        $ProgressBar.__ClearTimer = $null

        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Value = 0
        $ProgressBar.Visibility = 'Collapsed'

        $StatusText.Text = ''
        $StatusText.Visibility = 'Collapsed'
        return
    }

    # --- Message & Level ---
    if ($PSBoundParameters.ContainsKey('Message'))
    {
        $msg = [string]$Message
        if ($msg.Length -gt 20)
        {
            $msg = $msg.Substring(0, 20)
        }
        $StatusText.Text = $msg
        if ($StatusText.Visibility -ne 'Visible')
        {
            $StatusText.Visibility = 'Visible'
        }
    }

    if ($PSBoundParameters.ContainsKey('Level'))
    {
        switch ($Level)
        {
            'Info'
            {
                $StatusText.Foreground = $fgInfo
            }
            'Success'
            {
                $StatusText.Foreground = $fgSuccess
            }
            'Warning'
            {
                $StatusText.Foreground = $fgWarn
            }
            'Error'
            {
                $StatusText.Foreground = $fgError
            }
            'Neutral'
            {
                $StatusText.Foreground = $fgSubtle
            }
        }
    }

    # Ensure progress visible when we touch it
    $currentVisible = ($ProgressBar.Visibility -eq 'Visible')

    # --- Indeterminate ---
    if ($Indeterminate)
    {
        $ProgressBar.IsIndeterminate = $true
        if (-not $currentVisible)
        {
            $ProgressBar.Visibility = 'Visible'
        }
        # if explicit color provided, honor it
        if ($PSBoundParameters.ContainsKey('Color'))
        {
            $ProgressBar.Foreground = (To-Brush $Color)
        }
        return
    }

    # --- Stop any running timers if we are going to set percent/animate ---
    if ($PSBoundParameters.ContainsKey('Percent') -or $PSBoundParameters.ContainsKey('To') -or $PSBoundParameters.ContainsKey('TimeoutSeconds'))
    {
        Stop-Timer $ProgressBar.__StatusTimer
        $ProgressBar.__StatusTimer = $null
    }

    # --- Set Percent directly ---
    if ($PSBoundParameters.ContainsKey('Percent'))
    {
        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Value = Clamp $Percent
        if (-not $currentVisible)
        {
            $ProgressBar.Visibility = 'Visible'
        }
        if ($PSBoundParameters.ContainsKey('Color'))
        {
            $ProgressBar.Foreground = (To-Brush $Color)
        }
        elseif ($AutoColor)
        {
            $ProgressBar.Foreground = Get-AutoBrush $ProgressBar.Value
        }
    }

    # --- Animate to target over TimeoutSeconds ---
    if ($PSBoundParameters.ContainsKey('TimeoutSeconds'))
    {
        $target = if ($PSBoundParameters.ContainsKey('To'))
        {
            Clamp $To
        }
        else
        {
            100.0
        }
        $start = if ($ProgressBar.Visibility -eq 'Visible')
        {
            $ProgressBar.Value
        }
        else
        {
            0.0
        }
        if ($start -gt $target)
        {
            $start = 0.0
        }  # simple guard

        $ProgressBar.IsIndeterminate = $false
        if ($ProgressBar.Visibility -ne 'Visible')
        {
            $ProgressBar.Visibility = 'Visible'
        }

        $intervalMs = 50
        $ticks = [Math]::Max(1, [Math]::Ceiling(($TimeoutSeconds * 1000) / $intervalMs))
        $delta = ($target - $start) / $ticks
        $tickCount = 0

        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromMilliseconds($intervalMs)
        $timer.Add_Tick({
                $tickCount++
                $newVal = $ProgressBar.Value + $delta
                # Clamp and set
                if ($delta -ge 0)
                {
                    if ($newVal -ge $target)
                    {
                        $newVal = $target
                    }
                }
                else
                {
                    if ($newVal -le $target)
                    {
                        $newVal = $target
                    }
                }
                $ProgressBar.Value = $newVal

                # Auto color during animation
                if ($PSBoundParameters.ContainsKey('Color'))
                {
                    $ProgressBar.Foreground = (To-Brush $Color)
                }
                elseif ($AutoColor)
                {
                    $ProgressBar.Foreground = Get-AutoBrush $ProgressBar.Value
                }

                # Completion check
                if ($newVal -eq $target -or $tickCount -ge $ticks)
                {
                    $timer.Stop()
                    $ProgressBar.__StatusTimer = $null

                    if ($HideProgressOnCompletion)
                    {
                        $ProgressBar.Visibility = 'Collapsed'
                    }

                    if ($ClearMessageOnCompletion)
                    {
                        # start delayed clear
                        $ct = [System.Windows.Threading.DispatcherTimer]::new()
                        $ct.Interval = [TimeSpan]::FromSeconds([Math]::Max(0.0, $ClearMessageDelay))
                        $ct.Add_Tick({
                                $ct.Stop()
                                $StatusText.Text = ''
                                $StatusText.Visibility = 'Collapsed'
                                $ProgressBar.__ClearTimer = $null
                            })
                        $ProgressBar.__ClearTimer = $ct
                        $ct.Start()
                    }
                }
            })
        $ProgressBar.__StatusTimer = $timer
        $timer.Start()
    }
}
