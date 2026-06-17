<#
.SYNOPSIS
    Core notification engine for claude-herald.
    Plays a sound from the active pack + prints terminal banner.
    Falls back to terminal-only if no sounds installed.
#>
param(
    [Parameter(Mandatory)][string]$Event,
    [string]$Message = "",
    [string]$Detail  = ""
)

$root       = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $root "config.json"
if (-not (Test-Path $configPath)) { exit 0 }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $config.enabled) { exit 0 }

# Map claude-herald events to og-packs categories
$categoryMap = @{
    "done"       = "task.complete"
    "question"   = "input.required"
    "permission" = "input.required"
    "input"      = "input.required"
    "tool"       = "task.acknowledge"
}

# ── Audio playback ────────────────────────────────────────────────────────────
if ($config.audio.enabled) {
    $packName  = $config.audio.active_pack
    $volume    = [double]$config.audio.volume
    $packDir   = Join-Path $root "sounds\$packName"
    $soundsDir = Join-Path $packDir "sounds"
    $manifestP = Join-Path $packDir "openpeon.json"
    $playScript = Join-Path $root "engine\play.ps1"

    if ((Test-Path $manifestP) -and (Test-Path $soundsDir)) {
        $manifest = Get-Content $manifestP -Raw | ConvertFrom-Json
        $category = $categoryMap[$Event]

        # Skip audio for tool events if configured
        $skipTool = ($Event -eq "tool" -and -not $config.audio.play_on_tool)
        if ($category -and -not $skipTool) {
            $catSounds = $manifest.categories.PSObject.Properties |
                         Where-Object { $_.Name -eq $category } |
                         Select-Object -First 1

            if ($catSounds) {
                $soundFiles = $catSounds.Value.sounds
                $pick       = $soundFiles[(Get-Random -Maximum $soundFiles.Count)]
                $fileName   = Split-Path $pick.file -Leaf
                $filePath   = Join-Path $soundsDir $fileName

                if (Test-Path $filePath) {
                    # Play async so hook returns fast
                    Start-Process powershell -WindowStyle Hidden -ArgumentList @(
                        "-NoProfile", "-NonInteractive",
                        "-File", "`"$playScript`"",
                        "-Path", "`"$filePath`"",
                        "-Volume", $volume
                    )
                }
            }
        }
    }
}

# ── Terminal banner ───────────────────────────────────────────────────────────
if ($config.notify.terminal) {
    $prefix = switch ($Event) {
        "done"       { "[+]" }
        "question"   { "[?]" }
        "permission" { "[!]" }
        "input"      { "[>]" }
        "tool"       { "[-]" }
        default      { "[*]" }
    }
    $color = switch ($Event) {
        "done"       { "Green" }
        "question"   { "Yellow" }
        "permission" { "Red" }
        "input"      { "Cyan" }
        "tool"       { "DarkGray" }
        default      { "White" }
    }
    Write-Host ""
    if ($Detail) {
        Write-Host "  $prefix " -ForegroundColor $color -NoNewline
        Write-Host "claude " -ForegroundColor DarkGray -NoNewline
        Write-Host $Detail -ForegroundColor White
    } else {
        Write-Host "  $prefix " -ForegroundColor $color -NoNewline
        Write-Host "claude" -ForegroundColor DarkGray
    }
    if ($Message) { Write-Host "     $Message" -ForegroundColor Gray }
    Write-Host ""
}

# ── Toast (async) ─────────────────────────────────────────────────────────────
if ($config.toast.enabled) {
    $toastLabel = switch ($Event) {
        "done"       { "Claude - Done" }
        "question"   { "Claude - Question" }
        "permission" { "Claude - Authorization Required" }
        "input"      { "Claude - Needs Input" }
        "tool"       { "Claude - $Detail" }
        default      { "Claude" }
    }
    $toastBody   = if ($Message) { $Message } else { $Detail }
    $toastScript = Join-Path $root "engine\toast.ps1"
    Start-Process powershell -WindowStyle Hidden -ArgumentList @(
        "-NoProfile", "-NonInteractive",
        "-File", "`"$toastScript`"",
        "-Title", "`"$toastLabel`"",
        "-Body",  "`"$toastBody`""
    )
}