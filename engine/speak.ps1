<#
.SYNOPSIS
    Core TTS engine for claude-herald.
    Reads config, resolves active voice profile, and speaks a message.
.PARAMETER Message
    Text to speak.
.PARAMETER Priority
    low | normal | high
#>
param(
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet("low","normal","high")][string]$Priority = "normal"
)

$configPath = Join-Path $PSScriptRoot "..\config.json"
if (-not (Test-Path $configPath)) { exit 0 }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
if (-not $config.voice.enabled) { exit 0 }

# Resolve active profile - fall back to legacy voice block if no profiles defined
$voiceName = "Microsoft David Desktop"
$voiceRate = -2
$voiceVol  = 90

if ($config.PSObject.Properties["profiles"] -and $config.voice.active_profile) {
    $profileName = $config.voice.active_profile
    $profile     = $config.profiles.PSObject.Properties[$profileName]
    if ($profile) {
        $voiceName = $profile.Value.name
        $voiceRate = [int]$profile.Value.rate
        $voiceVol  = [int]$profile.Value.volume
    }
} elseif ($config.voice.PSObject.Properties["name"]) {
    $voiceName = $config.voice.name
    $voiceRate = [int]$config.voice.rate
    $voiceVol  = [int]$config.voice.volume
}

try {
    Add-Type -AssemblyName System.Speech
    $synth     = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $installed = $synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }

    if ($installed -contains $voiceName) {
        $synth.SelectVoice($voiceName)
    }

    $synth.Rate   = $voiceRate
    $synth.Volume = $voiceVol

    if ($Priority -eq "high") {
        $synth.SpeakAsync($Message) | Out-Null
    } else {
        $synth.Speak($Message)
    }

    $synth.Dispose()
} catch {
    $_ | Out-File (Join-Path $PSScriptRoot "..\herald.log") -Append
}