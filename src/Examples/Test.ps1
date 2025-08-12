$ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module "C:\Users\KRIST\Bluarch\Bluarch.WpfTools\output\module\Bluarch.WpfTools\1.0.0\Bluarch.WpfTools.psm1" -Force

$win = New-Object System.Windows.Window
Initialize-WpfApplication -Theme NordBlue -Scope Window -Window $win -SetShutdownOnMainWindowClose
$win.ShowDialog() | Out-Null
