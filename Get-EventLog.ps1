param (
    [Parameter(Mandatory = $true)]
    [string]$sourceName
)

# Get the current time to start from
$lastEventTime = Get-Date

Write-Host "Listening for new events from source: $sourceName. Press Ctrl+C to stop."

try {
    while ($true) {
        Start-Sleep -Seconds 1

        # Retrieve new events since the last event time
        $newEvents = Get-WinEvent -FilterHashtable @{
            LogName      = 'Application'
            ProviderName = $sourceName
            StartTime    = $lastEventTime
        } -ErrorAction SilentlyContinue

        foreach ($event in $newEvents | Sort-Object TimeCreated) {
            Write-Host "TimeCreated: $($event.TimeCreated) | Id: $($event.Id) | Level: $($event.LevelDisplayName) | Message: $($event.Message)"
            $lastEventTime = $event.TimeCreated
        }
    }
}
catch {
    Write-Host "An error occurred: $_"
}
