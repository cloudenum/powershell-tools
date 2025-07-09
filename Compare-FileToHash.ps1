param (
    [Parameter(Mandatory=$true)][string]$File,
    [Parameter(Mandatory=$true)][string]$ExpectedHash,
    [string]$Algorithm = "SHA256"
)

# Get the file hash
$hashSourcefile = Get-FileHash $File -Algorithm $Algorithm

if ($hashSourcefile.Hash -ne $ExpectedHash.ToUpper())
{
    Write-Output "Fail"
} else {
    Write-Output "OK"
}