function Build-MasterTimeline {
<#!
.SYNOPSIS
Creates a unified, chronologically sorted timeline from parsed text files.
.PARAMETER ParsedFolder
Folder containing parsed *.txt artifacts.
.PARAMETER OutputFile
Name of the timeline file to produce.
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Parameter(Mandatory)][ValidateScript({Test-Path $_ -PathType Container})][string]$ParsedFolder,
        [string]$OutputFile = 'Master_Timeline.txt',
        [string]$LogFile
    )
    Write-Log -Message "Constructing master timeline from $ParsedFolder" -LogFile $LogFile
    $timeline = [System.Collections.Generic.List[string]]::new()
    $parsedFiles = Get-ChildItem -Path $ParsedFolder -Filter *.txt -File -ErrorAction SilentlyContinue
    foreach($pf in $parsedFiles){
        $lines = Get-Content -LiteralPath $pf.FullName -ErrorAction SilentlyContinue
        foreach($line in $lines){
            if ($line -match '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2}:[0-9]{2}\t') {
                $timeline.Add($line)
            }
        }
        Write-Log -Message "Collected $($lines.Count) lines from $($pf.Name)" -LogFile $LogFile
    }
    if ($timeline.Count -eq 0){
        Write-Warning 'No timestamped lines were found in parsed outputs.'
        Write-Log -Message 'No timestamped lines found; timeline not created' -LogFile $LogFile
        return
    }
    $ordered = $timeline | Sort-Object { ([datetime]($_.Split("`t")[0])) }

    # Lightweight tagging heuristics
    $tagged = @()
    foreach($entry in $ordered){
        $line = $entry
        if ($line -match '\\Downloads\\.*\.(zip|7z|rar|sfx|tar|gz)'){
            $line += "`tTAG:ARCHIVE_DOWNLOAD"
        }
        $tagged += $line
    }
    $outPath = Join-Path (Split-Path -Parent $LogFile) $OutputFile
    'Timestamp	Source	EventID	Provider	Message	Tags' | Out-File -FilePath $outPath -Encoding UTF8
    $tagged | Out-File -FilePath $outPath -Append -Encoding UTF8
    Write-Log -Message "Master timeline created at $outPath with $($tagged.Count) entries" -LogFile $LogFile
    return $outPath
}
