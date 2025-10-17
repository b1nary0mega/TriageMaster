#requires -Version 5.1
Set-StrictMode -Version Latest
$script:ErrorActionPreference = 'Stop'

Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 | ForEach-Object { . $_.FullName }
Get-ChildItem -Path $PSScriptRoot\Public\*.ps1  | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function Invoke-Triage,Get-ZimmermanTool,Get-TriageFileList,Build-MasterTimeline
