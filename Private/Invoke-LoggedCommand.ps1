function Invoke-LoggedCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$LogFile
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $cmdLine = "$ExePath $($Arguments -join ' ')"
    Write-Verbose "[$timestamp] $Description"
    Write-Verbose " $cmdLine"
    Write-Log -Message "[$timestamp] $Description" -LogFile $LogFile
    Write-Log -Message " $cmdLine" -LogFile $LogFile
    try {
        & $ExePath @Arguments 2>&1 | Tee-Object -FilePath $LogFile -Append | Out-Null
        Write-Log -Message "[$timestamp] Completed: $Description" -LogFile $LogFile
    } catch {
        Write-Log -Message ("[{0}] Error during {1}: {2}" -f $timestamp, $Description, $_) -LogFile $LogFile
        throw
    }
    Write-Log -Message "" -LogFile $LogFile
}
