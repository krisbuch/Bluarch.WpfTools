function Initialize-WpfHeaderAdvanced {
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement]$HeaderRoot,

        # Valgfri: aktuel værdi der skal vises
        [string]$CurrentTheme
    )

    $combo = $HeaderRoot.FindName('ThemeCombo')
    if (-not $combo) { return }

    # Fyld ComboBox med enum-navne, fallback til statisk liste
    try {
        $null = [Themes]  # fejler hvis typen ikke findes
        $combo.ItemsSource = [enum]::GetNames([Themes])
    } catch {
        $combo.ItemsSource = @('CleanLight','NordBlue','DarkSlate','HighContrast','ModernTech','AbstractWave','WinUIFluent','SurpriseMe')
    }

    if ($CurrentTheme) { $combo.SelectedItem = $CurrentTheme }

    # Reager på ændring
    $combo.Add_SelectionChanged({
        param($s,$e)
        $name = [string]$s.SelectedItem
        if ([string]::IsNullOrWhiteSpace($name)) { return }

        if (Get-Command Set-WpfTheme -ErrorAction SilentlyContinue) {
            try {
                Set-WpfTheme -Theme $name -Scope Application
                if (Get-Command Write-Msg -ErrorAction SilentlyContinue) {
                    Write-Msg ✅ "Theme switched to '$name' (Application scope)"
                }
            } catch {
                if (Get-Command Write-Msg -ErrorAction SilentlyContinue) {
                    Write-Msg ❗ "Failed to switch theme '$name' – $($_.Exception.Message)" -Foreground Red
                } else {
                    Write-Host "Failed to switch theme '$name' – $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            if (Get-Command Write-Msg -ErrorAction SilentlyContinue) {
                Write-Msg ⚠️ "Set-WpfTheme not found in session." -Foreground Yellow
            } else {
                Write-Host "Set-WpfTheme not found in session." -ForegroundColor Yellow
            }
        }
    })
}
