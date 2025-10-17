# TriageMaster

An investigative tool for processing \[mostly\] KAPE triages, but will also work with several other collection/triage packages as well (i.e., MDE Investigation Package). 

This started as a tool to assist with the HTB CTF "Holmes". After much cleanup and passing the code to copilot + GPT5, this is the result of an AI-assisted refactoring of my initial triage scripts into a reusable PowerShell module. It provides a logged approach to generating an encriched timeline of events based on registry hives, page files, event logs and more.

## Install / Import
```powershell
Import-Module .\TriageMaster.psd1 -Force
```

## Quick Start
```powershell
Invoke-Triage -TriageRoot 'D:\investigations\CASE123\files' -DownloadTools -Verbose
```

## Functions
- `Invoke-Triage` — Orchestrates the full run.
- `Get-TriageFileList` — Builds a list of interesting files.
- `Get-ZimmermanTool` — Bootstraps Eric Zimmerman's tools.
- `Build-MasterTimeline` — Produces a unified timeline.

## Logging
All actions write to `triage_run.log` under the triage root by default.
