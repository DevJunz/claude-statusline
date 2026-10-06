# Installs the Claude Code status line for the current Windows user.
#   Local:  powershell -ExecutionPolicy Bypass -File .\install.ps1
#   Remote: irm https://raw.githubusercontent.com/DevJunz/claude-statusline/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$RawBase   = 'https://raw.githubusercontent.com/DevJunz/claude-statusline/main'
$ClaudeDir = Join-Path $HOME '.claude'
$Target    = Join-Path $ClaudeDir 'statusline.ps1'
$Settings  = Join-Path $ClaudeDir 'settings.json'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force $ClaudeDir | Out-Null

# 1. statusline.ps1: copy from this folder if present, otherwise download
$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'statusline.ps1' } else { $null }
if ($local -and (Test-Path $local)) {
    Copy-Item $local $Target -Force
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "$RawBase/statusline.ps1" -OutFile $Target -UseBasicParsing
}
Write-Host "[ok] script -> $Target"

# 2. settings.json: set statusLine, keep every other setting
$command = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + ($Target -replace '\\', '/') + '"'
$cfg = New-Object PSObject
if (Test-Path $Settings) {
    $text = [System.IO.File]::ReadAllText($Settings)
    if ($text.Trim()) {
        Copy-Item $Settings "$Settings.bak" -Force
        Write-Host "[ok] backup -> $Settings.bak"
        $cfg = $text | ConvertFrom-Json
    }
}
$statusLine = [PSCustomObject]@{ type = 'command'; command = $command }
if ($cfg.PSObject.Properties['statusLine']) { $cfg.statusLine = $statusLine }
else { $cfg | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine }
[System.IO.File]::WriteAllText($Settings, ($cfg | ConvertTo-Json -Depth 20), $Utf8NoBom)
Write-Host "[ok] statusLine -> $Settings"
Write-Host 'Done. Restart Claude Code to see the status line.'
