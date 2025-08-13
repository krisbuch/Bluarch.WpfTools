# --- Setup ---
$project = Split-Path -Parent $PSScriptRoot
. (Join-Path -Path $project -ChildPath "Enum\enum.Themes.ps1")
Import-Module "C:\Users\KRIST\Bluarch\Bluarch.WpfTools\output\module\Bluarch.WpfTools\1.0.0\Bluarch.WpfTools.psm1" -Force

Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase

[string]$XamlPath = (Join-Path -Paath $project -ChildPath "Views\Sidebar.Icons.xaml")
[string]$ThemePath = Join-Path $project "Themes\Theme.DarkSlate.xaml",                  # valgfri: sti til din ResourceDictionary XAML
[string]$IconsPath = Join-Path $project "Assets\Icons"       # hvor dine PNG/ICO ligger


# App + theme
if (-not [System.Windows.Application]::Current) { $null = [System.Windows.Application]::new() }
if ($ThemePath -and (Test-Path $ThemePath)) {
    $rd = [Windows.Markup.XamlReader]::Load((Get-Content -Raw -Path $ThemePath))
    [System.Windows.Application]::Current.Resources.MergedDictionaries.Add($rd) | Out-Null
}

# Load UserControl
$xaml = Get-Content -Raw -Path $XamlPath
$uc   = [Windows.Markup.XamlReader]::Parse($xaml)

# Fix relative ikonstier til fulde paths
$images = $uc.FindName("PART_TopItems").Children + $uc.FindName("PART_BottomItems").Children |
          ForEach-Object { $_.Content } | Where-Object { $_ -is [System.Windows.Controls.Image] }
foreach ($img in $images) {
    $rel = [string]$img.Tag
    if ($rel -and -not [System.IO.Path]::IsPathRooted($rel)) {
        $candidate = Join-Path $IconsPath $rel.Substring($rel.IndexOf('\') + 1)  # "Icons\*.png" → ".\Icons\*.png"
        if (-not (Test-Path $candidate)) { $candidate = Join-Path (Split-Path -Parent $XamlPath) $rel }
        $img.Tag = $candidate
        # Reload Source fra Tag
        $bi = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bi.BeginInit(); $bi.UriSource = [Uri]$img.Tag; $bi.CacheOption = 'OnLoad'; $bi.EndInit()
        $img.Source = $bi
    }
}

# Vinduet
$win = New-Object System.Windows.Window
$win.Title                   = "Bluarch Sidebar Preview"
$win.Width                   = 960
$win.Height                  = 640
$win.WindowStartupLocation   = 'CenterScreen'
$win.Background              = [System.Windows.Application]::Current.Resources['BrushWindowBG']

# Layout: sidebar + content
$grid = New-Object System.Windows.Controls.Grid
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '80'  })) | Out-Null
$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '*'    })) | Out-Null

# Sidebar i kolonne 0
[System.Windows.Controls.Grid]::SetColumn($uc,0)
$grid.Children.Add($uc) | Out-Null

# Placeholder content (viser valgt nav)
$right = New-Object System.Windows.Controls.Border
$right.Background = [System.Windows.Application]::Current.Resources['BrushCard']
$right.BorderBrush = [System.Windows.Application]::Current.Resources['BrushCardBorder']
$right.BorderThickness = 1
$right.Margin = 12

$tb = New-Object System.Windows.Controls.TextBlock
$tb.Margin = 24
$tb.FontSize = 20
$tb.Foreground = [System.Windows.Application]::Current.Resources['BrushPrimaryFG']
$tb.Text = "Selected: Dashboard"
$right.Child = $tb

[System.Windows.Controls.Grid]::SetColumn($right,1)
$grid.Children.Add($right) | Out-Null

$win.Content = $grid

# Wire-up: opdater tekst når et item vælges
$allBtns = @(
    $uc.FindName('Nav_Home'),
    $uc.FindName('Nav_Dashboard'),
    $uc.FindName('Nav_Users'),
    $uc.FindName('Nav_Reports'),
    $uc.FindName('Nav_Settings'),
    $uc.FindName('Nav_Help')
) | Where-Object { $_ }

foreach ($btn in $allBtns) {
    $null = $btn.Add_Checked({
        param($s,$e)
        $n = $s.ToolTip -as [string]
        if (-not $n) { $n = $s.Name }
        $tb.Text = "Selected: $n"
    })
}

$win.ShowDialog() | Out-Null
