<#
.SYNOPSIS
    Download sound packs for claude-herald.
    Checks the PeonPing registry first (for community packs like jarvis-mk2),
    falls back to og-packs for core packs.

.EXAMPLE
    .\install-sounds.ps1 -Packs jarvis-mk2
    .\install-sounds.ps1 -Packs peon,clean_chimes
    .\install-sounds.ps1 -List
    .\install-sounds.ps1 -All
#>
param(
    [string[]]$Packs = @(),
    [switch]$List,
    [switch]$All
)

$root         = $PSScriptRoot
$soundsDir    = Join-Path $root "sounds"
$registryUrl  = "https://peonping.github.io/registry/index.json"
$ogPacksBase  = "https://raw.githubusercontent.com/PeonPing/og-packs/main"

# Fetch registry (has community packs + og-packs)
function Get-Registry {
    try {
        $r = Invoke-WebRequest -Uri $registryUrl -UseBasicParsing -ErrorAction Stop
        return ($r.Content | ConvertFrom-Json).packs
    } catch {
        return $null
    }
}

if ($List) {
    Write-Host ""
    Write-Host "Fetching pack registry..." -ForegroundColor DarkGray
    $reg = Get-Registry
    if ($reg) {
        Write-Host "Available packs ($($reg.Count) total):" -ForegroundColor Cyan
        $reg | Sort-Object name | ForEach-Object {
            $tier  = if ($_.trust_tier -eq "community") { " [community]" } else { "" }
            $color = if ($_.trust_tier -eq "community") { "DarkGray" } else { "White" }
            Write-Host ("  " + $_.name.PadRight(25) + $_.display_name + $tier) -ForegroundColor $color
        }
    } else {
        Write-Host "Registry unavailable. Core packs:" -ForegroundColor Yellow
        @("peon","clean_chimes","glados","sc_battlecruiser","sc_kerrigan","duke_nukem",
          "tf2_engineer","peasant","hd2_helldiver","rick","sheogorath","murloc",
          "ocarina_of_time","molag_bal") | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "Install : .\install-sounds.ps1 -Packs <name>" -ForegroundColor DarkGray
    Write-Host "Switch  : .\herald.ps1 --set-pack <name>" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

if ($Packs.Count -eq 0 -and -not $All) {
    Write-Host "Usage: .\install-sounds.ps1 -Packs <name>[,<name>]  or  -List  or  -All" -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Force -Path $soundsDir | Out-Null

# Fetch registry to resolve community packs
$registry = Get-Registry

function Install-Pack {
    param([string]$PackName)

    Write-Host ""
    Write-Host "Installing: $PackName" -ForegroundColor Cyan

    $packDir   = Join-Path $soundsDir $PackName
    $subDir    = Join-Path $packDir "sounds"
    New-Item -ItemType Directory -Force -Path $subDir | Out-Null

    # Try registry first (handles community packs with custom repos)
    $regEntry = if ($registry) { $registry | Where-Object { $_.name -eq $PackName } | Select-Object -First 1 } else { $null }

    $manifestUrl = $null
    $baseUrl     = $null

    if ($regEntry) {
        $repo = $regEntry.source_repo
        $ref  = $regEntry.source_ref
        $path = $regEntry.source_path.TrimStart(".").TrimStart("/")
        $bUrl = "https://raw.githubusercontent.com/$repo/$ref"
        $manifestUrl = if ($path) { "$bUrl/$path/openpeon.json" } else { "$bUrl/openpeon.json" }
        $baseUrl     = if ($path) { "$bUrl/$path" } else { $bUrl }
    } else {
        # Fallback: og-packs
        $manifestUrl = "$ogPacksBase/$PackName/openpeon.json"
        $baseUrl     = "$ogPacksBase/$PackName"
    }

    # Download manifest
    try {
        Invoke-WebRequest -Uri $manifestUrl -OutFile "$packDir\openpeon.json" -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Pack '$PackName' not found." -ForegroundColor Red
        return
    }

    $manifest = Get-Content "$packDir\openpeon.json" -Raw | ConvertFrom-Json
    Write-Host "  $($manifest.display_name)" -ForegroundColor White
    if ($manifest.description) { Write-Host "  $($manifest.description)" -ForegroundColor DarkGray }

    # Download sounds
    $ok = 0; $fail = 0
    foreach ($cat in $manifest.categories.PSObject.Properties) {
        foreach ($sound in $cat.Value.sounds) {
            $file     = $sound.file
            $fname    = [System.Uri]::EscapeDataString((Split-Path $file -Leaf)) -replace '%2[Ff]','/'
            $fname    = Split-Path $file -Leaf
            $outPath  = Join-Path $subDir $fname
            # URL-encode spaces/parens in filename
            $encoded  = $file -replace ' ','%20' -replace '\(','%28' -replace '\)','%29' -replace '\?','%3F'
            $url      = "$baseUrl/$encoded"
            try {
                Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -ErrorAction Stop
                $ok++
            } catch {
                $fail++
                Write-Host "  FAIL: $fname" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  $ok files downloaded$(if($fail -gt 0){" ($fail failed)"})" -ForegroundColor Green
}

if ($All) {
    if (-not $registry) { Write-Host "Registry unavailable — cannot list all packs." -ForegroundColor Red; exit 1 }
    $registry | ForEach-Object { Install-Pack $_.name }
} else {
    foreach ($p in ($Packs -split ',').Trim()) {
        Install-Pack $p
    }
}

Write-Host ""
Write-Host "Done. Switch pack: .\herald.ps1 --set-pack <name>" -ForegroundColor Cyan