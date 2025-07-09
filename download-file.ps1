<#
.SYNOPSIS
    Download a file from the internet with progress, speed, and ETA.

.PARAMETER Url
    The source URL.

.PARAMETER OutFile
    (Optional) The destination path / filename.  
    If omitted, the script uses the URL’s filename.  
    If the URL has no filename, defaults to 'downloaded.file'.

.PARAMETER Quiet
    Suppress progress output. (Switch)

.EXAMPLE
    .\DownloadFile.ps1 -Url "https://example.com/file.iso"
    .\DownloadFile.ps1 -Url "https://example.com/file.iso" -OutFile "my.iso" -Quiet
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$OutFile,

    [switch]$Quiet
)

$cwd = Get-Location

# -- Globals for cleanup in the cancellation handler --
$fs      = $null
$stream  = $null
$client  = $null

function Console-Info {
    if (-not $Quiet) {
        Write-Host @args
    }
}

function Console-Warning {
    if (-not $Quiet) {
        Write-Warning @args
    }
}

function Console-Error {
    if (-not $Quiet) {
        Write-Error @args
    }
}

function Cleanup-And-Exit {
    param($exitCode)
    if ($fs)     { $fs.Dispose() }
    if ($stream) { $stream.Dispose() }
    if ($client) { $client.Dispose() }
    if ($OutFile -and (Test-Path $OutFile) -and ($exitCode -ne 0)) {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }
    exit $exitCode
}

function Format-Bytes {
    param([double]$Bytes)
    switch ($Bytes) {
        {$_ -ge 1GB} { "{0:N2}GB" -f ($Bytes / 1GB); break }
        {$_ -ge 1MB} { "{0:N2}MB" -f ($Bytes / 1MB); break }
        {$_ -ge 1KB} { "{0:N2}KB" -f ($Bytes / 1KB); break }
        default       { "{0:N0}B"  -f $Bytes        ; break }
    }
}

$exitCode = 0
try {
    # Derive OutFile if not provided
    if (-not $OutFile) {
        try {
            $name = [System.IO.Path]::GetFileName(([Uri] $Url).AbsolutePath)
            if (-not $name) { throw }
            $OutFile = "./$name"
        } catch {
            $OutFile = './downloaded.file'
        }

        $OutFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($cwd, $OutFile))
        Console-Info "Saving to: '$OutFile'"
        if (Test-Path $OutFile) {
            Console-Warning "'$OutFile' already exists. It will be overwritten."
        }
    }

    Add-Type -AssemblyName System.Net.Http
    $client            = [System.Net.Http.HttpClient]::new()
    $client.Timeout    = [TimeSpan]::FromMinutes(30)

    # HEAD request to get size (if supported)
    $totalBytes = $null
    try {
        $head = [System.Net.Http.HttpRequestMessage]::new(
            [System.Net.Http.HttpMethod]::Head, $Url)
        $resp = $client.SendAsync($head).Result
        $totalBytes = $resp.Content.Headers.ContentLength
    } catch { }

    # Begin download
    $stream  = $client.GetStreamAsync($Url).Result
    $fs      = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create)
    $buffer  = New-Object byte[] 8192
    $read    = 0
    $sw      = [System.Diagnostics.Stopwatch]::StartNew()
    $lastUpd = 0

    while (($bytes = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fs.Write($buffer, 0, $bytes)
        $read += $bytes

        if (-not $Quiet) {
            $now = $sw.ElapsedMilliseconds
            if ($now -gt ($lastUpd + 500)) {
                $speedBps   = if ($sw.Elapsed.TotalSeconds) { $read / $sw.Elapsed.TotalSeconds } else { 0 }
                $percent = if ($totalBytes) { ($read / $totalBytes) * 100 } else { 0 }
                $remain  = if ($totalBytes -and $speedBps) { ($totalBytes - $read) / $speedBps } else { 0 }
                $eta     = [TimeSpan]::FromSeconds([Math]::Max(0, [Math]::Round($remain)))

                $downStr  = Format-Bytes $read
                $totalStr = if ($totalBytes) { " of $(Format-Bytes $totalBytes)" } else { "" }
                $spdStr   = "$(Format-Bytes $speedBps)/s"
                $etaStr   = if ($totalBytes) { $eta.ToString("hh\:mm\:ss") } else { "--:--:--" }

                $status = "$downStr$totalStr @ $spdStr  ETA: $etaStr"

                Write-Progress -Activity "Downloading $Url" `
                               -Status $status `
                               -PercentComplete ([int]$percent)
                $lastUpd = $now
            }
        }
    }

    # Finished successfully
    Console-Info "✔ Download complete: '$OutFile'"
}
catch {
    Console-Error "Download failed: $_"
    $exitCode = 1
}
finally {
    Cleanup-And-Exit $exitCode
}
