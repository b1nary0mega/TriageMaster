@{
    RootModule        = 'TriageMaster.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '00000000-0000-0000-0000-000000000001'
    Author            = 'Jimmi Aylesworth'
    CompanyName       = ''
    Copyright         = '(c) {0}. All rights reserved.' -f (Get-Date).Year
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-Triage','Get-ZimmermanTool','Get-TriageFileList','Build-MasterTimeline')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
