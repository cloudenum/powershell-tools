param (
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

# Read the file content as bytes
$fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

# Convert the bytes to a Base64 string
$base64String = [Convert]::ToBase64String($fileBytes)

# Output the Base64 string
Write-Output $base64String