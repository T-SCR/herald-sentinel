<#
.SYNOPSIS
    Download sound packs from PeonPing/og-packs into sounds/<pack>/.
    Usage: .\install-sounds.ps1 [-Packs peon,clean_chimes] [-List]
#>
param(
    [string[]]$Packs = @("peon","clean_chimes"),
    [switch]$List,
    [switch]$All
)

$root      = $PSScriptRoot
$soundsDir = Join-Path $root "sounds"
$base      = "https://raw.githubusercontent.com/PeonPing/og-packs/main"
$apiBase   = "https://api.github.com/repos/PeonPing/og-packs/contents"

if ($List) {
    Write-Host ""
    Write-Host "Popular packs:" -ForegroundColor Cyan
    $packs = @(
        @{name="peon";         desc="Warcraft III Orc Peon voice lines"},
        @{name="clean_chimes"; desc="Subtle UI chimes (Mixkit, no voice)"},
        @{name="glados";       desc="Portal GLaDOS voice"},
        @{name="sc_kerrigan";  desc="StarCraft Sarah Kerrigan voice"},
        @{name="duke_nukem";   desc="Duke Nukem voice"},
        @{name="tf2_engineer"; desc="TF2 Engineer voice"},
        @{name="peasant";      desc="Warcraft III Human Peasant voice"},
        @{name="hd2_helldiver";desc="Helldivers 2 voice"}
    )
    $packs | ForEach-Object { Write-Host "  $($_.name.PadRight(20)) $($_.desc)" -ForegroundColor White }
    Write-Host ""
    Write-Host "Install: .\install-sounds.ps1 -Packs peon,glados" -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Force -Path $soundsDir | Out-Null

foreach ($packName in $Packs) {
    Write-Host ""
    Write-Host "Downloading pack: $packName" -ForegroundColor Cyan

    $packDir = Join-Path $soundsDir $packName
    New-Item -ItemType Directory -Force -Path $packDir | Out-Null
    $soundSubDir = Join-Path $packDir "sounds"
    New-Item -ItemType Directory -Force -Path $soundSubDir | Out-Null

    # Fetch manifest
    $manifestUrl = "$base/$packName/openpeon.json"
    $manifestPath = Join-Path $packDir "openpeon.json"
    try {
        Invoke-WebRequest -Uri $manifestUrl -OutFile $manifestPath -UseBasicParsing -ErrorAction Stop
        Write-Host "  Manifest fetched" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [!] Pack not found: $packName" -ForegroundColor Red
        continue
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    # Download all sound files
    $total = 0; $ok = 0
    foreach ($cat in $manifest.categories.PSObject.Properties) {
        foreach ($sound in $cat.Value.sounds) {
            $total++
            $fileName = Split-Path $sound.file -Leaf
            $fileUrl  = "$base/$packName/$($sound.file)"
            $filePath = Join-Path $soundSubDir $fileName
            try {
                Invoke-WebRequest -Uri $fileUrl -OutFile $filePath -UseBasicParsing -ErrorAction Stop
                $ok++
            } catch {
                Write-Host "  [!] Failed: $fileName" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "  $ok/$total sounds downloaded" -ForegroundColor Green
    Write-Host "  Display name: $($manifest.display_name)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Done. Installed packs:" -ForegroundColor Green
Get-ChildItem -Path $soundsDir -Directory | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }
Write-Host ""
Write-Host "Switch pack: .\herald.ps1 --set-pack <name>" -ForegroundColor Yellow