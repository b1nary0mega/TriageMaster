function Get-ZimmermanTool {
<#!
.SYNOPSIS
Downloads and extracts an Eric Zimmerman tool, returning the exe path.
.PARAMETER ToolName
Name of the tool (e.g. 'MFTECmd').
.PARAMETER ZipUrl
HTTP(S) URL to the zip package.
.PARAMETER ToolsRoot
Folder where tools are stored.
.EXAMPLE
Get-ZimmermanTool -ToolName 'PECmd' -ZipUrl 'https://download.ericzimmermanstools.com/net9/PECmd.zip' -ToolsRoot 'D:\triage\tools'
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ToolName,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ZipUrl,
        [Parameter(Mandatory)][ValidateScript({Test-Path $_ -PathType Container})][string]$ToolsRoot,
        [string]$LogFile
    )
    $zipPath = Join-Path $ToolsRoot "$ToolName.zip"
    $toolPath = Join-Path $ToolsRoot $ToolName
    if (-not (Test-Path -LiteralPath $toolPath)){
        Write-Log -Message "Downloading $ToolName from $ZipUrl to $zipPath" -LogFile $LogFile
        $retries = 3; $delay = 2
        for ($i=1; $i -le $retries; $i++) {
            try {
                Write-Log -Message ('Downloading {0} from {1} to {2}' -f $ToolName, $ZipUrl, $zipPath) -LogFile $LogFile
                Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
                Expand-Archive -Path $ZipPath -DestinationPath $toolPath -Force
                Write-Log -Message "$ToolName extracted to $toolPath" -LogFile $LogFile
                break
            } catch {
                if ($i -eq $retries) { throw ("Failed to download/extract {0}: {1}" -f $ToolName, $_.Exception.Message) }
                Start-Sleep -Seconds $delay; $delay *= 2
            }
        } 
    }
    $exe = Get-ChildItem -Path $toolPath -Filter "$ToolName.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (-not $exe){ throw "Could not locate $ToolName.exe under $toolPath" }
    Write-Log -Message "$ToolName resolved to executable: $exe" -LogFile $LogFile
    return $exe
}
