<#
.SYNOPSIS
    Audio player for claude-herald.
    Uses WPF MediaPlayer for WAV/MP3, falls back to ffplay/mpv/vlc.
    Adapted from PeonPing/peon-ping win-play.ps1 (MIT).
.PARAMETER Path
    Full path to audio file.
.PARAMETER Volume
    0.0 to 1.0
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [double]$Volume = 0.5
)

if (-not (Test-Path $Path)) { exit 0 }

function Invoke-WpfPlay {
    param([string]$FilePath, [double]$Vol)
    try {
        Add-Type -AssemblyName PresentationCore
        $player = [System.Windows.Media.MediaPlayer]::new()
        $player.Volume = $Vol

        Register-ObjectEvent -InputObject $player -EventName MediaOpened -SourceIdentifier "CH_Opened" | Out-Null
        Register-ObjectEvent -InputObject $player -EventName MediaFailed -SourceIdentifier "CH_Failed" | Out-Null
        $player.Open([uri]::new($FilePath))
        $player.Play()

        # Pump dispatcher so events fire
        $deadline = [datetime]::UtcNow.AddSeconds(5)
        $opened = $false; $failed = $false
        while ([datetime]::UtcNow -lt $deadline) {
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Windows.Threading.DispatcherPriority]::Background, [Action]{})
            if (Get-Event -SourceIdentifier "CH_Failed" -ErrorAction SilentlyContinue) { $failed = $true; break }
            if (Get-Event -SourceIdentifier "CH_Opened" -ErrorAction SilentlyContinue) { $opened = $true; break }
            Start-Sleep -Milliseconds 50
        }

        if (-not $failed -and -not $opened) { $failed = $true }

        if (-not $failed -and $player.NaturalDuration.HasTimeSpan) {
            Start-Sleep -Seconds ([math]::Ceiling($player.NaturalDuration.TimeSpan.TotalSeconds))
        }

        Unregister-Event -SourceIdentifier "CH_Opened" -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier "CH_Failed" -ErrorAction SilentlyContinue
        $player.Close()
        return (-not $failed -and $opened)
    } catch { return $false }
}

# WPF handles WAV/MP3/WMA natively
if ($Path -match '\.(wav|mp3|wma)$') {
    if (Invoke-WpfPlay -FilePath $Path -Vol $Volume) { exit 0 }
}

# Fallbacks for other formats
$ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
if ($ffplay) {
    $vol = [math]::Max(0,[math]::Min(100,[int]($Volume * 100)))
    & $ffplay.Source -nodisp -autoexit -volume $vol $Path 2>$null
    exit 0
}

$mpv = Get-Command mpv -ErrorAction SilentlyContinue
if ($mpv) {
    $vol = [math]::Max(0,[math]::Min(100,[int]($Volume * 100)))
    & $mpv.Source --no-video --volume=$vol $Path 2>$null
    exit 0
}

exit 0