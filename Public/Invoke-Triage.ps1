function Invoke-Triage {
<#!
.SYNOPSIS
End-to-end triage parser for KAPE-like collections with logging, tool bootstrap, and master timeline output.
.DESCRIPTION
Enumerates target artifacts, optionally downloads Eric Zimmerman's utilities, parses EVTX/registry/USN/prefetch/LNK/JumpLists, and builds a normalized timeline.
.PARAMETER TriageRoot
Root folder where the triage resides.
.PARAMETER ToolsRoot
Folder to cache third-party tools.
.PARAMETER ParsingOutput
Output folder for parsed artifacts.
.PARAMETER FileListPath
If provided, writes the matched file list here.
.PARAMETER DownloadTools
When set, downloads Eric Zimmerman's tools needed.
.PARAMETER LogFile
Path to log file (will be created if missing).
.EXAMPLE
Invoke-Triage -TriageRoot 'D:\investigations\CASE123\files' -DownloadTools
#>
    [CmdletBinding(PositionalBinding=$false, SupportsShouldProcess=$false)]
    param(
        [Parameter(Mandatory)][ValidateScript({Test-Path $_ -PathType Container})][string]$TriageRoot,
        [string]$ToolsRoot = (Join-Path $TriageRoot 'tools'),
        [string]$ParsingOutput = (Join-Path $TriageRoot 'parsed'),
        [string]$FileListPath = (Join-Path $TriageRoot 'files_list.txt'),
        [switch]$DownloadTools,
        [string]$LogFile = (Join-Path $TriageRoot 'triage_run.log')
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Ensure-Folder -Path $ParsingOutput | Out-Null
    Ensure-Folder -Path $ToolsRoot | Out-Null

    Write-Log -Message "Invoke-Triage starting for root: $TriageRoot" -LogFile $LogFile

    $files = Get-TriageFileList -TriageRoot $TriageRoot -OutputPath $FileListPath -LogFile $LogFile

    $mfte = $pecmd = $lecmd = $recmd = $null
    if ($DownloadTools){
        $mfte = Get-ZimmermanTool -ToolName 'MFTECmd' -ZipUrl 'https://download.ericzimmermanstools.com/net9/MFTECmd.zip' -ToolsRoot $ToolsRoot -LogFile $LogFile
        $pecmd = Get-ZimmermanTool -ToolName 'PECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/PECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
        $lecmd = Get-ZimmermanTool -ToolName 'LECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/LECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
        $recmd = Get-ZimmermanTool -ToolName 'RECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/RECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
    }

    Write-Log -Message ("Beginning parsing of {0} files" -f $files.Count) -LogFile $LogFile

    foreach($fullPath in $files){
        if (-not (Test-Path -LiteralPath $fullPath)) { Write-Log -Message "Skipping missing path: $fullPath" -LogFile $LogFile; continue }

        switch -Wildcard ($fullPath) {
            '*Security.evtx' {
                $eventIds = 4624,4625,4634,4647,4648,4672,4688,4689,4697,4698,4699,4702,4719,4720,4722,4723,4724,4725,4726,4728,4729,4732,4733,4740,4657,4663,1102
                $outFile = Join-Path $ParsingOutput 'Security_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                {$_ -in 4624,4625,4634,4647,4648,4672} { 'LOGON' }
                                {$_ -in 4688,4689}                   { 'PROCESS' }
                                {$_ -in 4697,4698,4699,4702}         { 'PERSISTENCE' }
                                {$_ -in 4720,4722,4723,4724,4725,4726,4728,4729,4732,4733,4740} { 'ACCOUNT_CHANGE' }
                                {$_ -in 4719,1102}                   { 'TAMPERING' }
                                {$_ -in 4657,4663}                   { 'OBJECT_ACCESS' }
                                default                              { 'OTHER' }
                            }
                            ('{0}`tSecurity`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName, ($_.Message -replace '\r?\n',' '), $cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("Security extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    }
                } catch { Write-Warning "Failed to parse $fullPath : $_" }
            }
            '*System.evtx' {
                $eventIds = 6005,6006,6008,6013,41,7034,7036,7040,7045,7000,7001,7009,7011,219
                $outFile = Join-Path $ParsingOutput 'System_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                {$_ -in 6005,6006,6008,6013,41} { 'BOOT_SHUTDOWN' }
                                {$_ -in 7034,7036,7040,7045,7000,7001,7009,7011} { 'SERVICE_EVENT' }
                                {$_ -in 219} { 'DEVICE_DRIVER' }
                                default { 'SYSTEM_EVENT' }
                            }
                            ('{0}`tSystem`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName, ($_.Message -replace '\r?\n',' '), $cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("System extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    }
                } catch { Write-Warning "Failed to parse $fullPath : $_" }
            }
            '*Application.evtx' {
                $eventIds = 1000,1001,1002,1026,11707,11708,11724,11729,5037,5038
                $outFile = Join-Path $ParsingOutput 'Application_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                1000 {'APP_CRASH'}; 1001 {'APP_REPORT'}; 1002 {'APP_HANG'}; 1026 {'DOTNET_ERROR'};
                                11707 {'APP_INSTALL_SUCCESS'}; 11708 {'APP_INSTALL_FAIL'}; 11724 {'APP_UNINSTALL'}; 11729 {'APP_INSTALL_ROLLBACK'};
                                5037 {'RUNTIME_FIREWALL_ERROR'}; 5038 {'CODE_INTEGRITY_BLOCK'}; default {'APP_EVENT'}
                            }
                            ('{0}`tApplication`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName, ($_.Message -replace '\r?\n',' '), $cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("Application extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    }
                } catch { Write-Warning "Failed to parse $fullPath : $_" }
            }
            '*PowerShell*Operational.evtx' {
                $eventIds = 4100,4101,4102,4103,4104,4105,4106,53504
                $outFile = Join-Path $ParsingOutput 'PowerShell_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                4100 {'PS_ENGINE_START'}; 4101 {'PS_ENGINE_STOP'}; 4102 {'PS_ENGINE_STATE'}; 4103 {'PS_MODULE'}; 4104 {'PS_SCRIPTBLOCK'}; 4105 {'PS_PIPELINE_START'}; 4106 {'PS_PIPELINE_STOP'}; 53504 {'PS_SCRIPTBLOCK_INVOKE'}; default {'PS_EVENT'}
                            }
                            $msg = if ($_.Id -in 4104,53504) { -join ($_.Properties | ForEach-Object { $_.Value }) } else { ($_.Message -replace '\r?\n',' ') }
                            ('{0}`tPowerShell`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName,$msg,$cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("PowerShell extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    } else { Write-Log -Message "No matching PowerShell events found in $fullPath" -LogFile $LogFile }
                } catch { Write-Warning "Failed to parse $fullPath : $_"; Write-Log -Message "Failed to parse $fullPath : $_" -LogFile $LogFile }
            }
            '*WMI-Activity*Operational.evtx' {
                $eventIds = 5857,5858,5859,5860
                $outFile = Join-Path $ParsingOutput 'WMI_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                5857 {'WMI_ACTIVITY'}; 5858 {'WMI_BINDING'}; 5859 {'WMI_CONSUMER'}; 5860 {'WMI_PROVIDER'}; default {'WMI_EVENT'}
                            }
                            $msg = if ($_.Id -in 5857,5859) { -join ($_.Properties | ForEach-Object { $_.Value }) } else { ($_.Message -replace '\r?\n',' ') }
                            ('{0}`tWMI`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName,$msg,$cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("WMI extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    } else { Write-Log -Message "No matching WMI events found in $fullPath" -LogFile $LogFile }
                } catch { Write-Warning "Failed to parse $fullPath : $_"; Write-Log -Message "Failed to parse $fullPath : $_" -LogFile $LogFile }
            }
            '*Windows Defender*Operational.evtx' {
                $eventIds = 1116,1117,1118,1119,5007,5001,5004,5010,2000,2001
                $outFile = Join-Path $ParsingOutput 'Defender_Extracted.txt'
                try {
                    $events = Get-WinEvent -FilterHashtable @{ Path=$fullPath; Id=$eventIds } -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Sort-Object TimeCreated | ForEach-Object {
                            $cat = switch ($_.Id) {
                                1116 {'DEFENDER_DETECTION'}; 1117 {'DEFENDER_ACTION_TAKEN'}; 1118 {'DEFENDER_ACTION_FAILED'}; 1119 {'DEFENDER_ACTION_RETRY'}; 5007 {'DEFENDER_CONFIG_CHANGE'}; 5001 {'DEFENDER_RTP_DISABLED'}; 5004 {'DEFENDER_RTP_ENABLED'}; 5010 {'DEFENDER_SIGNATURE_UPDATE'}; 2000 {'DEFENDER_ENGINE_START'}; 2001 {'DEFENDER_ENGINE_HEALTH'}; default {'DEFENDER_EVENT'}
                            }
                            ('{0}`tDefender`t{1}`t{2}`t{3}`tTAG:{4}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName, ($_.Message -replace '\r?\n',' '), $cat)
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("Defender extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    } else { Write-Log -Message "No matching Defender events found in $fullPath" -LogFile $LogFile }
                } catch { Write-Warning "Failed to parse $fullPath : $_"; Write-Log -Message "Failed to parse $fullPath : $_" -LogFile $LogFile }
            }
            { $_ -like '*\\config\\SAM' -or $_ -like '*\\config\\SYSTEM' -or $_ -like '*\\config\\SOFTWARE' -or $_ -like '*\\config\\SECURITY' } {
                if ($recmd){ Invoke-LoggedCommand -Description "Parsing system hive $fullPath" -ExePath $recmd -Arguments @('--bn', $fullPath, '--csv', $ParsingOutput) -LogFile $LogFile } else { Write-Log -Message "RECmd not available; skipping registry parse for $fullPath" -LogFile $LogFile }
            }
            { $_ -like '*NTUSER.DAT' -or $_ -like '*UsrClass.dat' } {
                if ($recmd){ Invoke-LoggedCommand -Description "Parsing user hive $fullPath" -ExePath $recmd -Arguments @('--bn', $fullPath, '--csv', $ParsingOutput) -LogFile $LogFile } else { Write-Log -Message "RECmd not available; skipping registry parse for $fullPath" -LogFile $LogFile }
            }
            '*\\$J' {
                if ($mfte){ Invoke-LoggedCommand -Description "Parsing USN Journal $fullPath" -ExePath $mfte -Arguments @('-f', $fullPath, '--csv', $ParsingOutput, '--usnjrnl') -LogFile $LogFile } else { Write-Log -Message "MFTECmd not available; skipping USN parse for $fullPath" -LogFile $LogFile }
            }
            '*.pf' {
                if ($pecmd){ Invoke-LoggedCommand -Description "Parsing Prefetch $fullPath" -ExePath $pecmd -Arguments @('-f', $fullPath, '--csv', $ParsingOutput) -LogFile $LogFile } else { Write-Log -Message "PECmd not available; skipping Prefetch parse for $fullPath" -LogFile $LogFile }
            }
            { $_ -like '*.lnk' -or $_ -like '*.automaticDestinations-ms' -or $_ -like '*.customDestinations-ms' } {
                if ($lecmd){ Invoke-LoggedCommand -Description "Parsing LNK/Jump List $fullPath" -ExePath $lecmd -Arguments @('-f', $fullPath, '--csv', $ParsingOutput) -LogFile $LogFile } else { Write-Log -Message "LECmd not available; skipping LNK/JumpList parse for $fullPath" -LogFile $LogFile }
            }
            { $_ -like '*TeamViewer*' -or $_ -like '*Connections_incoming.txt' -or $_ -like '*TeamViewer15_Logfile.log' } {
                Write-Log -Message "Parsing TeamViewer text artifact: $fullPath" -LogFile $LogFile
                $tvOut = Join-Path $ParsingOutput 'TeamViewer_Parsed.txt'
                Get-Content -LiteralPath $fullPath -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_ -match '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2}:[0-9]{2}') {
                        $ts = $Matches[0]
                        "$ts`tTeamViewer`tNA`tTeamViewer`t$($_ -replace '\r?\n',' ')" | Out-File $tvOut -Append -Encoding UTF8
                    } else {
                        $fallback = (Get-Item -LiteralPath $fullPath).LastWriteTime.ToString('MM/dd/yyyy HH:mm:ss')
                        "$fallback`tTeamViewer`tNA`tTeamViewer`t$($_ -replace '\r?\n',' ')" | Out-File $tvOut -Append -Encoding UTF8
                    }
                }
                $count = 0
                if (Test-Path -LiteralPath $tvOut) {
                    $count = (Get-Content -LiteralPath $tvOut -ErrorAction SilentlyContinue).Count
                }
                Write-Log -Message "TeamViewer entries appended: $count -> $tvOut" -LogFile $LogFile
            }
            default {
                Write-Log -Message "Processing unrecognized log: $fullPath" -LogFile $LogFile
                try {
                    $outFile = Join-Path $ParsingOutput ("Generic_" + [IO.Path]::GetFileNameWithoutExtension($fullPath) + ".txt")
                    $events = Get-WinEvent -Path $fullPath -ErrorAction SilentlyContinue
                    if ($events){
                        $events | Select-Object TimeCreated, Id, ProviderName, Message | Sort-Object TimeCreated | ForEach-Object {
                            ('{0}`tGeneric`t{1}`t{2}`t{3}' -f $_.TimeCreated.ToString('MM/dd/yyyy HH:mm:ss'),$_.Id,$_.ProviderName, ($_.Message -replace '\r?\n',' '))
                        } | Out-File $outFile -Encoding UTF8
                        Write-Log -Message ("Generic extracted entries: {0} -> {1}" -f $events.Count, $outFile) -LogFile $LogFile
                    } else { Write-Log -Message "No events found in unrecognized log: $fullPath" -LogFile $LogFile }
                } catch { Write-Warning "Failed to parse $fullPath : $_"; Write-Log -Message "Failed to parse $fullPath : $_" -LogFile $LogFile }
            }
        }
    }

    $timelinePath = Build-MasterTimeline -ParsedFolder $ParsingOutput -OutputFile 'Master_Timeline.txt' -LogFile $LogFile
    Write-Log -Message "Master triage complete. Parsed outputs: $ParsingOutput" -LogFile $LogFile
    return [pscustomobject]@{ ParsedOutput=$ParsingOutput; Timeline=$timelinePath; Log=$LogFile }
}
