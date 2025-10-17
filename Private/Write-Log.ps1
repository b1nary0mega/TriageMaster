function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$LogFile
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    if ($PSBoundParameters.ContainsKey('LogFile') -and $LogFile) {
        Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    } else {
        Write-Information "[$timestamp] $Message" -InformationAction Continue
    }
}
