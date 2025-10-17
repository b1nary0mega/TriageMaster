function Ensure-Folder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Verbose "Created missing folder: $Path"
        Write-Log -Message "Created folder: $Path"
    } else {
        Write-Verbose "Folder already exists: $Path"
        Write-Log -Message "Verified folder exists: $Path"
    }
}
