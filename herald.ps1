<#
.SYNOPSIS
    claude-herald CLI - manage your voice notification settings.
.DESCRIPTION
    Toggle features on/off, switch voice profiles, test voice, check status.

.EXAMPLE
    .\herald.ps1 --status
    .\herald.ps1 --toggle voice
    .\herald.ps1 --toggle toast
    .\herald.ps1 --toggle mobile
    .\herald.ps1 --toggle tool-events
    .\herald.ps1 --toggle complete-push
    .\herald.ps1 --test
    .\herald.ps1 --profiles
    .\herald.ps1 --set-profile jarvis
    .\herald.ps1 --set-topic my-unique-topic-123
    .\herald.ps1 --voices
    .\herald.ps1 --set-voice "Microsoft Zira Desktop"
    .\herald.ps1 --mute
    .\herald.ps1 --unmute
#>

param(
    [switch]$Status,
    [string]$Toggle,
    [switch]$Test,
    [switch]$Profiles,
    [string]$SetProfile,
    [string]$SetTopic,
    [string]$SetVoice,
    [switch]$Voices,
    [switch]$Mute,
    [switch]$Unmute,
    [switch]$Help
)

$configPath = Join-Path $PSScriptRoot "config.json"

function Get-Config {
    Get-Content $configPath -Raw | ConvertFrom-Json
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

function Write-Status($label, $value) {
    $icon  = if ($value) { "[ON] " } else { "[OFF]" }
    $color = if ($value) { "Green" } else { "DarkGray" }
    Write-Host "  $icon  $label" -ForegroundColor $color
}

$anyFlag = $Status -or $Toggle -or $Test -or $Profiles -or $SetProfile -or $SetTopic -or $SetVoice -or $Voices -or $Mute -or $Unmute

if ($Help -or (-not $anyFlag)) {
    Write-Host ""
    Write-Host "claude-herald" -ForegroundColor Cyan
    Write-Host "Voice + notification bridge for Claude Code" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\herald.ps1 --status                     Show current config"
    Write-Host "  .\herald.ps1 --test                       Speak a test line with active profile"
    Write-Host "  .\herald.ps1 --mute / --unmute            Quick voice toggle"
    Write-Host "  .\herald.ps1 --profiles                   List available voice profiles"
    Write-Host "  .\herald.ps1 --set-profile <name>         Switch voice profile (jarvis/default/zira)"
    Write-Host "  .\herald.ps1 --toggle <feature>           Toggle a feature on/off"
    Write-Host "  .\herald.ps1 --voices                     List installed TTS voices on this system"
    Write-Host "  .\herald.ps1 --set-voice <name>           Override voice in active profile"
    Write-Host "  .\herald.ps1 --set-topic <ntfy-topic>     Enable mobile push"
    Write-Host ""
    Write-Host "Toggleable features:" -ForegroundColor Yellow
    Write-Host "  voice         Voice TTS on/off"
    Write-Host "  toast         Windows toast notifications"
    Write-Host "  mobile        Mobile push via ntfy.sh"
    Write-Host "  tool-events   Per-tool toast popups (Write/Edit/Bash)"
    Write-Host "  complete-push Push to phone even on task-complete"
    Write-Host "  tool-details  Include filename/command in announcements"
    Write-Host ""
    exit 0
}

if ($Status) {
    $cfg = Get-Config
    Write-Host ""
    Write-Host "claude-herald status" -ForegroundColor Cyan
    Write-Host "--------------------" -ForegroundColor DarkGray
    Write-Status "Master switch        " $cfg.enabled
    Write-Status "Voice TTS            " $cfg.voice.enabled
    Write-Status "Toast notifications  " $cfg.toast.enabled
    Write-Status "Toast on tool events " $cfg.toast.show_tool_events
    Write-Status "On-stop hook         " $cfg.hooks.on_stop
    Write-Status "On-tool-use hook     " $cfg.hooks.on_tool_use
    Write-Status "Mobile push (ntfy)   " $cfg.mobile.enabled
    Write-Status "Push on complete     " $cfg.mobile.push_on_complete
    Write-Status "Tool details in TTS  " $cfg.announcements.tool_details
    Write-Host ""

    # Show active profile
    $activeProfile = $cfg.voice.active_profile
    if ($activeProfile -and $cfg.PSObject.Properties["profiles"]) {
        $p = $cfg.profiles.PSObject.Properties[$activeProfile]
        if ($p) {
            Write-Host "  Profile  : $activeProfile - $($p.Value.description)" -ForegroundColor Cyan
            Write-Host "  Voice    : $($p.Value.name)  rate=$($p.Value.rate)  vol=$($p.Value.volume)" -ForegroundColor DarkGray
        }
    }

    $topicDisplay = if ($cfg.mobile.ntfy_topic) { $cfg.mobile.ntfy_topic } else { "(not set)" }
    Write-Host "  ntfy     : $($cfg.mobile.ntfy_server)/$topicDisplay" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

if ($Profiles) {
    $cfg = Get-Config
    Write-Host ""
    Write-Host "Available voice profiles:" -ForegroundColor Cyan
    $active = $cfg.voice.active_profile
    $cfg.profiles.PSObject.Properties | ForEach-Object {
        $marker = if ($_.Name -eq $active) { " [ACTIVE]" } else { "" }
        $color  = if ($_.Name -eq $active) { "Green" } else { "White" }
        Write-Host "  $($_.Name)$marker" -ForegroundColor $color
        Write-Host "    $($_.Value.description)" -ForegroundColor DarkGray
        Write-Host "    Voice: $($_.Value.name)  rate=$($_.Value.rate)  vol=$($_.Value.volume)" -ForegroundColor DarkGray
        Write-Host ""
    }
    Write-Host "Switch with: .\herald.ps1 --set-profile <name>" -ForegroundColor Yellow
    exit 0
}

if ($SetProfile) {
    $cfg = Get-Config
    if (-not $cfg.PSObject.Properties["profiles"]) {
        Write-Host "No profiles defined in config.json." -ForegroundColor Red
        exit 1
    }
    $p = $cfg.profiles.PSObject.Properties[$SetProfile]
    if (-not $p) {
        $available = ($cfg.profiles.PSObject.Properties | ForEach-Object { $_.Name }) -join ", "
        Write-Host "Profile '$SetProfile' not found. Available: $available" -ForegroundColor Red
        exit 1
    }
    $cfg.voice.active_profile = $SetProfile
    Save-Config $cfg
    Write-Host "Profile set to: $SetProfile - $($p.Value.description)" -ForegroundColor Green
    Write-Host "Run --test to hear it." -ForegroundColor DarkGray
    exit 0
}

if ($Mute) {
    $cfg = Get-Config
    $cfg.voice.enabled = $false
    Save-Config $cfg
    Write-Host "Voice muted." -ForegroundColor Yellow
    exit 0
}

if ($Unmute) {
    $cfg = Get-Config
    $cfg.voice.enabled = $true
    Save-Config $cfg
    Write-Host "Voice unmuted." -ForegroundColor Green
    exit 0
}

if ($Toggle) {
    $cfg = Get-Config
    switch ($Toggle.ToLower()) {
        "voice"         { $cfg.voice.enabled              = -not $cfg.voice.enabled;              $label = "Voice TTS" }
        "toast"         { $cfg.toast.enabled              = -not $cfg.toast.enabled;              $label = "Toast notifications" }
        "mobile"        { $cfg.mobile.enabled             = -not $cfg.mobile.enabled;             $label = "Mobile push" }
        "tool-events"   { $cfg.toast.show_tool_events     = -not $cfg.toast.show_tool_events;     $label = "Toast on tool events" }
        "complete-push" { $cfg.mobile.push_on_complete    = -not $cfg.mobile.push_on_complete;    $label = "Push on task complete" }
        "tool-details"  { $cfg.announcements.tool_details = -not $cfg.announcements.tool_details; $label = "Tool details in TTS" }
        default {
            Write-Host "Unknown feature: $Toggle. Run --help for options." -ForegroundColor Red
            exit 1
        }
    }
    Save-Config $cfg
    $newVal = switch ($Toggle.ToLower()) {
        "voice"         { $cfg.voice.enabled }
        "toast"         { $cfg.toast.enabled }
        "mobile"        { $cfg.mobile.enabled }
        "tool-events"   { $cfg.toast.show_tool_events }
        "complete-push" { $cfg.mobile.push_on_complete }
        "tool-details"  { $cfg.announcements.tool_details }
    }
    $state = if ($newVal) { "ON" } else { "OFF" }
    $color = if ($newVal) { "Green" } else { "Yellow" }
    Write-Host "$label toggled $state." -ForegroundColor $color
    exit 0
}

if ($SetTopic) {
    $cfg = Get-Config
    $cfg.mobile.ntfy_topic = $SetTopic
    $cfg.mobile.enabled    = $true
    Save-Config $cfg
    Write-Host "Mobile topic set to: $SetTopic" -ForegroundColor Green
    Write-Host "Subscribe on your phone at: $($cfg.mobile.ntfy_server)/$SetTopic" -ForegroundColor Cyan
    exit 0
}

if ($Voices) {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    Write-Host ""
    Write-Host "Installed TTS voices:" -ForegroundColor Cyan
    $synth.GetInstalledVoices() | ForEach-Object {
        $info = $_.VoiceInfo
        Write-Host "  $($info.Name)  [$($info.Gender), $($info.Culture)]" -ForegroundColor White
    }
    $synth.Dispose()
    Write-Host ""
    Write-Host "To install more: Settings > Time & language > Speech > Add voices" -ForegroundColor DarkGray
    exit 0
}

if ($SetVoice) {
    $cfg = Get-Config
    # Apply to active profile if profiles exist, otherwise legacy voice block
    if ($cfg.PSObject.Properties["profiles"] -and $cfg.voice.active_profile) {
        $pName = $cfg.voice.active_profile
        $p     = $cfg.profiles.PSObject.Properties[$pName]
        if ($p) {
            $cfg.profiles.$pName.name = $SetVoice
            Save-Config $cfg
            Write-Host "Voice in profile '$pName' set to: $SetVoice" -ForegroundColor Green
            exit 0
        }
    }
    $cfg.voice.name = $SetVoice
    Save-Config $cfg
    Write-Host "Voice set to: $SetVoice" -ForegroundColor Green
    exit 0
}

if ($Test) {
    $cfg         = Get-Config
    $profileName = $cfg.voice.active_profile
    Write-Host ""
    Write-Host "Testing voice..." -ForegroundColor Cyan
    if ($profileName) { Write-Host "  Profile: $profileName" -ForegroundColor DarkGray }
    $speakScript = Join-Path $PSScriptRoot "engine\speak.ps1"
    & $speakScript -Message "All systems nominal. Claude Herald is online and operational. Awaiting your directive."
    Write-Host "Done." -ForegroundColor DarkGray
    Write-Host "If you heard nothing, run --voices to check what is installed." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}