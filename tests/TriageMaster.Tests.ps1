Import-Module "$PSScriptRoot/../TriageMaster.psd1" -Force
Describe 'TriageMaster basic' {
    It 'loads functions' {
        Get-Command Invoke-Triage | Should -Not -BeNullOrEmpty
    }
}
