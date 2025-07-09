param ( 
    [PSDefaultValue(Help="Current Directory")][Parameter(ValueFromPipeline=$true)] [string]$Path = $PWD.Path
)

$Result = Get-ChildItem $Path | Sort-Object -Descending -Property LastWriteTime -Top 1

Write-Output $Result
