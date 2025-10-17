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

## License
This project is licensed under the **GNU GPL v3.0 or later (GPL-3.0-or-later)**.
You may use, modify, and distribute this software (including commercially) **only**
under the GPL, with source code availability and preservation of copyright
and license notices. See LICENSE for details.

---

# Copilot Prompt + Output

<blockquote>
Original Prompt:

  > I have a rats nest of some powrshell code I've thrown together over time. Can you help me clean up, organize, and document better if I upload?

Copilot Response:

  > Below is a quick triage of what you had, the cleaned, modular version I produced, and how to run it right away. I also packaged everything as a ready‑to‑import PowerShell module.

---

## What you had (at a glance)

**Purpose:** master triage script for KAPE-style collections with: absolute file enumeration, per‑artifact parsing (WinEvent logs, Registry, USN, Prefetch, LNK/Jump Lists, TeamViewer text), logging to a file, and a consolidated timeline.

**Notable issues & quick wins**

- **Duplicate function definition**: `Ensure-Folder` is declared twice back‑to‑back; one copy can be removed.  
- **Uninitialized variable use**: `Ensure-Folder -Path $ToolsRoot` is called *before* `$ToolsRoot` is defined. (Race/order-of-ops bug.)
- **Hard-coded paths**: `$TriageRoot` is fixed to `D:\investigations\...`; better as a parameter.
- **Global state coupling**: `Write-Log` writes to a script‑scoped `$LogFile`; pass the path as a parameter to decouple.
- **Inconsistent error policy**: mix of `try/catch` with non‑terminating cmdlets; setting `$ErrorActionPreference = 'Stop'` near the entry point yields more predictable control flow.
- **Tool bootstrap assumptions**: the Zimmerman tools downloader is inline; wrapping it and making it optional (offline environments) improves portability.
- **Timeline/tagging heuristics**: useful, but embedded in the main script; moving to a callable function improves testability and reuse.

---

## What I built for you

I refactored your single script into a clean, reusable **PowerShell module**:

**Download the module** → [TriageMaster.zip](blob:https://m365.cloud.microsoft/REDACTED)

**Module layout**
```
TriageMaster/
├─ TriageMaster.psd1
├─ TriageMaster.psm1
├─ Public/
│  ├─ Invoke-Triage.ps1
│  ├─ Get-TriageFileList.ps1
│  ├─ Get-ZimmermanTool.ps1
│  └─ Build-MasterTimeline.ps1
├─ Private/
│  ├─ Ensure-Folder.ps1
│  ├─ Invoke-LoggedCommand.ps1
│  └─ Write-Log.ps1
├─ .pssa/PSScriptAnalyzerSettings.psd1
├─ tests/TriageMaster.Tests.ps1
└─ samples/Invoke-Triage.sample.ps1
```

**Highlights of the refactor**

- **Advanced functions** with `CmdletBinding()` and validation; parameters instead of hard‑coded paths.  
- **Strict mode & terminating errors** at entry: `Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'`.  
- **Decoupled logging**: `Write-Log` can log to a file or to the Information stream.  
- **Optional tool bootstrap** (`-DownloadTools`) with proper error handling; offline‑friendly when omitted.  
- **Clear separation of concerns**:  
  - `Get-TriageFileList` (enumeration & filtering)  
  - `Get-ZimmermanTool` (download/extract & resolve exe)  
  - `Invoke-Triage` (routing files to the right parser)  
  - `Build-MasterTimeline` (normalized output & basic tagging)  
- **PSScriptAnalyzer config** and a **minimal Pester test** scaffold so you can iterate safely.

> ⚙️ The parsing logic and event ID selections are preserved from your original script—now wrapped cleanly into functions and made idempotent where possible.

---

## Quick start

1) **Unzip and import**
```powershell
# in PowerShell 5.1+ (Windows)
Expand-Archive .\TriageMaster.zip -DestinationPath . -Force
Import-Module .\TriageMaster\TriageMaster.psd1 -Force
```

2) **Run a full triage**
```powershell
Invoke-Triage `
  -TriageRoot 'D:\investigations\CASE123\files' `
  -DownloadTools `
  -Verbose
```

3) **Outputs**
- Parsed artifacts → `...\parsed\*.txt`  
- Master timeline → `Master_Timeline.txt` (same folder as the log)  
- Log file → `triage_run.log`  

---

## A quick look at the core entry point

```powershell
function Invoke-Triage {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$TriageRoot,
        [string]$ToolsRoot     = (Join-Path $TriageRoot 'tools'),
        [string]$ParsingOutput = (Join-Path $TriageRoot 'parsed'),
        [string]$FileListPath  = (Join-Path $TriageRoot 'files_list.txt'),
        [switch]$DownloadTools,
        [string]$LogFile       = (Join-Path $TriageRoot 'triage_run.log')
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Ensure-Folder -Path $ParsingOutput
    Ensure-Folder -Path $ToolsRoot

    Write-Log -Message "Invoke-Triage starting for root: $TriageRoot" -LogFile $LogFile

    $files = Get-TriageFileList -TriageRoot $TriageRoot -OutputPath $FileListPath -LogFile $LogFile

    if ($DownloadTools) {
        $mfte = Get-ZimmermanTool -ToolName 'MFTECmd' -ZipUrl 'https://download.ericzimmermanstools.com/net9/MFTECmd.zip' -ToolsRoot $ToolsRoot -LogFile $LogFile
        $pecmd = Get-ZimmermanTool -ToolName 'PECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/PECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
        $lecmd = Get-ZimmermanTool -ToolName 'LECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/LECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
        $recmd = Get-ZimmermanTool -ToolName 'RECmd'   -ZipUrl 'https://download.ericzimmermanstools.com/net9/RECmd.zip'   -ToolsRoot $ToolsRoot -LogFile $LogFile
    }

    # …routes each file to the appropriate parser (EVTX/Registry/USN/Prefetch/LNK/WMI/PowerShell/Defender/TeamViewer)…
    # …then builds the timeline.
}
```

> If you prefer **one self-contained script** (not a module), I can flatten these functions back into a single `triage_run.ps1` with the same fixes—just say the word.

---

## Mapping: old → new

- `$TriageRoot` (hard-coded) → `Invoke-Triage -TriageRoot <path>` (required param).
- `$ParsingOutput` → `-ParsingOutput` (defaults to `<root>\parsed`).
- `$LogFile` → `-LogFile` (defaults to `<root>\triage_run.log`).
- Zimmerman tool bootstrap → `-DownloadTools` switch to enable; otherwise skip.

---

## Suggested next steps (optional, nice-to-haves)

- **PowerShell 7 parallelism**: switch to `ForEach-Object -Parallel` for heavy EVTX sets (PS7+ only).  
- **Robust downloads**: swap `Invoke-WebRequest` for `Start-BitsTransfer` with retries in enterprise networks.  
- **Structured logging**: emit JSON lines for easy ingestion (e.g., `Write-Information ($obj | ConvertTo-Json -Compress)`).  
- **Code signing**: sign the module and enforce execution policy on responder hosts.  
- **CI hook**: run PSScriptAnalyzer & Pester in a pipeline before you ship artifacts.

---

## Sanity checks I ran

- Confirmed the embedded script content was extracted correctly from your `triage.txt` wrapper.
- Built the refactor as a module and packaged it here → **[TriageMaster.zip](blob:https://m365.cloud.microsoft/REDACTED)** (importable as-is). 


</blockquote>
