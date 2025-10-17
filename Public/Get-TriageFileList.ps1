function Get-TriageFileList {
<#!
.SYNOPSIS
Builds an absolute file list from a triage root using provided patterns.
.DESCRIPTION
Recurses the triage root and returns files matching the patterns (wildcards supported).
.PARAMETER TriageRoot
Root folder of the triage collection.
.PARAMETER Patterns
Wildcard patterns to include (e.g. '*.evtx','*.pf','*NTUSER.DAT').
.PARAMETER OutputPath
Optional path to write the list to disk (UTF8). Returns the list regardless.
.EXAMPLE
Get-TriageFileList -TriageRoot 'D:\triage' -Patterns '*.evtx','*.pf' -OutputPath (Join-Path 'D:\triage' 'files_list.txt')
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Parameter(Mandatory)][ValidateScript({Test-Path $_ -PathType Container})][string]$TriageRoot,
        [Parameter()][string[]]$Patterns = @('*.evtx','*.pf','*NTUSER.DAT','*UsrClass.dat','*.lnk','*.automaticDestinations-ms','*.customDestinations-ms','*TeamViewer*','*AnyDesk*','*Bomgar*','*\\$J'),
        [string]$OutputPath,
        [string]$LogFile
    )
    Write-Log -Message "Starting enumeration under $TriageRoot" -LogFile $LogFile
    $all = Get-ChildItem -Path $TriageRoot -Recurse -File -Force -ErrorAction SilentlyContinue
    $filtered = foreach($f in $all){
        $abs = $f.FullName
        if ($Patterns | Where-Object { $abs -like $_ }) { $abs }
    }
    if ($filtered.Count -eq 0){
        Write-Warning 'No files matched the specified patterns.'
        Write-Log -Message 'No files matched patterns' -LogFile $LogFile
    }
    if ($PSBoundParameters.ContainsKey('OutputPath') -and $OutputPath){
        $null = Ensure-Folder -Path (Split-Path $OutputPath -Parent)
        $filtered | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Log -Message "File list created with $($filtered.Count) entries at $OutputPath" -LogFile $LogFile
    }
    return $filtered
}
