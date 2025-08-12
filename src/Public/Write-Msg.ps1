function Write-Msg
{
<#
.SYNOPSIS
Writes a timestamped, column-aligned console message with an icon and automatic word-wrapping.

.DESCRIPTION
Write-Msg prints three visually aligned columns:
  1) A timestamp (either wall clock or runtime stopwatch),
  2) A fixed-width icon cell (emoji/symbol),
  3) The message text, word-wrapped to the available console width.

The function keeps columns aligned across wrapped lines and across calls. When -UseRuntime is
specified, a shared Stopwatch is started on the first call and the elapsed time (hh:mm:ss.fff)
is shown instead of the wall clock. You can restart that stopwatch at any time with -ResetRuntime.

Emoji can render as double-width in many consoles. The SymbolCellWidth parameter lets you reserve
a fixed number of console cells for the icon; the default (5) works well in most Windows terminals.

.PARAMETER Symbol
Icon/emoticon shown in the fixed-width symbol column. Valid values:
ℹ️, ⚠️, ❗, ✅, 🔄, ✔️, ⏭️, 📚, 🗃️, 📢, 🛠️, 🚀, 🏳️, 📦, ▶️, 🔍, 🔥, ♾️, ⛔, 🛑, ♻️
Default: ℹ️

.PARAMETER Message
The message text to display. Newlines are normalized to spaces and the text is word-wrapped to fit
the remaining console width.

.PARAMETER Foreground
Console foreground color for the message column. Default: White

.PARAMETER PreBreak
Write a blank line before the entry (useful to visually separate sections).

.PARAMETER UseRuntime
Show elapsed runtime (⏱ hh:mm:ss.fff) from a shared Stopwatch instead of wall clock time.
The stopwatch is created on the first call that specifies -UseRuntime.

.PARAMETER ResetRuntime
Restart the shared Stopwatch (sets elapsed time back to 00:00:00.000). Typically used on the first
entry of a new phase, together with -UseRuntime.

.PARAMETER SymbolCellWidth
Console cell width reserved for the symbol column (to keep columns aligned even with wide emoji).
Valid range: 3–20. Default: 5

.PARAMETER Silent
Suppress output entirely. Useful for conditional or verbose-only scenarios.

.EXAMPLE
Write-Msg "Starting up..."
Writes a default informational entry with current time and the ℹ️ icon.

.EXAMPLE
Write-Msg ✅ "Initialization complete" -Foreground Green
Shows a green “success” message with a checkmark icon.

.EXAMPLE
# Start a new phase timer and show elapsed runtime going forward
Write-Msg ✅ "Beginning installation…" -UseRuntime -ResetRuntime
Write-Msg 🔄 "Downloading dependencies…" -UseRuntime
Write-Msg ⚠️ "Low disk space on drive C:, continuing…" -Foreground Yellow -UseRuntime
Write-Msg ✅ "Done." -UseRuntime
Displays elapsed time (⏱ hh:mm:ss.fff) for each entry since the reset.

.EXAMPLE
# Demonstrate wrapping while keeping columns aligned
Write-Msg 📦 "Installing very long dependency name that will wrap nicely across multiple lines without breaking the columns…"
Long text is wrapped under the Message column, keeping the time and icon columns aligned.

.EXAMPLE
# Temporarily suppress output
Write-Msg ❗ "This will not print" -Silent:$Silent

.INPUTS
None. You cannot pipe objects to Write-Msg.

.OUTPUTS
None. Write-Msg writes to the host.

.NOTES
- Column alignment is best with a modern terminal font (e.g., Cascadia Code / Cascadia Mono) and a UTF-8 console.
- Emoji display width varies by terminal; adjust -SymbolCellWidth if alignment looks off in your environment.
- The runtime stopwatch is stored in $script:__WriteMsgStopwatch (module/global script scope).

.LINK
Get-Help About_Comment_Based_Help
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [ValidateSet("ℹ️", "⚠️", "❗", "✅", "🔄", "✔️", "⏭️", "📚", "🗃️", "📢", "🛠️", "🚀", "🏳️", "📦", "▶️", "🔍", "🔥", "♾️", "⛔", "🛑", "♻️")]
        [string]$Symbol = "ℹ️",

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Message,

        [Parameter(Position = 2)]
        [System.ConsoleColor]$Foreground = "White",

        [Parameter(Position = 3)]
        [switch]$PreBreak,

        [Parameter(Position = 4)]
        [switch]$UseRuntime,

        [Parameter()]
        [switch]$ResetRuntime,

        [Parameter()]
        [ValidateRange(3, 20)]
        [int]$SymbolCellWidth = 5,

        [switch]$Silent = $false
    )
    if ($Silent)
    {
        return
    }
    if ($PreBreak)
    {
        Write-Host ""
    }

    # -- RUNTIME CLOCK ---------------------------------------------------------
    if ($UseRuntime)
    {
        if (-not $script:__WriteMsgStopwatch)
        {
            $script:__WriteMsgStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
        elseif ($ResetRuntime)
        {
            $script:__WriteMsgStopwatch.Restart()
        }
        $elapsed = $script:__WriteMsgStopwatch.Elapsed
        # TimeSpan custom format kræver escaped koloner og punktum
        $timeString = $elapsed.ToString("hh\:mm\:ss\.fff")
        $timestampText = "🕔 $timeString"
    }
    else
    {
        $timestampText = "🕔 " + (Get-Date).ToString("HH:mm:ss.fff")
    }
    # -------------------------------------------------------------------------

    # Console bredde og kolonner
    $raw = $Host.UI.RawUI
    $consoleWidth = [math]::Max(40, $raw.WindowSize.Width)
    $tsColWidth = [math]::Max($timestampText.Length + 1, 14)
    $spaceBetween = 1
    $msgWidth = $consoleWidth - $tsColWidth - $SymbolCellWidth - (2 * $spaceBetween)
    if ($msgWidth -lt 10)
    {
        $msgWidth = 10
    }

    # Wrap besked
    $text = ($Message -replace "`r`n", " " -replace "`n", " ")
    $lines = New-Object System.Collections.Generic.List[string]
    while ($text.Length -gt $msgWidth)
    {
        $slice = $text.Substring(0, $msgWidth)
        $breakAt = $slice.LastIndexOf(' ')
        if ($breakAt -lt 1)
        {
            $breakAt = $msgWidth
        }
        $lines.Add($text.Substring(0, $breakAt).TrimEnd())
        $text = $text.Substring($breakAt).TrimStart()
    }
    $lines.Add($text)

    function Center-InCell([string]$s, [int]$cellWidth)
    {
        $assumedWidth = 2   # antag dobbeltbred emoji
        $pad = [math]::Max(0, $cellWidth - $assumedWidth)
        (' ' * [math]::Floor($pad / 2)) + $s + (' ' * [math]::Ceiling($pad / 2))
    }

    $tsOut = $timestampText.PadRight($tsColWidth)
    $symOut = Center-InCell $Symbol $SymbolCellWidth

    # Første linje
    Write-Host $tsOut -ForegroundColor DarkGray -BackgroundColor Black -NoNewline
    Write-Host (" " * $spaceBetween) -NoNewline
    Write-Host $symOut -ForegroundColor Black -BackgroundColor DarkGray -NoNewline
    Write-Host (" " * $spaceBetween) -NoNewline
    Write-Host $lines[0] -ForegroundColor $Foreground -BackgroundColor Black

    # Fortsættelseslinjer
    for ($i = 1; $i -lt $lines.Count; $i++)
    {
        Write-Host (" " * $tsColWidth) -BackgroundColor Black -NoNewline
        Write-Host (" " * $spaceBetween) -NoNewline
        Write-Host (" " * $SymbolCellWidth) -BackgroundColor Black -NoNewline
        Write-Host (" " * $spaceBetween) -NoNewline
        Write-Host $lines[$i] -ForegroundColor $Foreground -BackgroundColor Black
    }
}
