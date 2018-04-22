$Sut = Join-Path -Path $PsScriptRoot -ChildPath "..\RunDbaChecks\RunDbaChecks.ps1" -Resolve
#Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false
#Install-Module -Name DbaChecks -Scope CurrentUser -Force -Repository (Get-PsRepository)[0].Name

Describe "Testing RunDbaChecks.ps1" {
    Mock -CommandName Write-Verbose -MockWith {}
    Mock -CommandName Write-Warning -MockWith {}
    Mock -CommandName Install-Module -MockWith {}
    Mock -CommandName Install-PackageProvider -MockWith {}

    Context "Testing inputs" {
        It "Should have Configuration as a mandatory parameter" {
            (Get-Command $Sut).Parameters['Configuration'].Attributes.Mandatory | Should -Be $true
        }
        It "Should have PSPath as an alias for Configuration" {
            (Get-Command $Sut).Parameters['Configuration'].Aliases | Should -Be 'PSPath'
        }
        It "Should throw is Configuration is an invalid path" {
            {&$Sut -Configuration 'TestDrive:\SomeFakeFile.json'} | Should -Throw 'Invalid Path Specified'
        }
        It "Should throw if configuration is not to a file" {
            {&$Sut -Configuration 'TestDrive:\'} | Should -Throw 'Invalid Path Specified'
        }
        It "Should have SqlInstance as a string array parameter" {
            (Get-Command $Sut).Parameters['SqlInstance'].ParameterType.Name | Should -Be 'String[]'
        }
        It "Should have ComputerName as a string array parameter" {
            (Get-Command $Sut).Parameters['ComputerName'].ParameterType.Name | Should -Be 'String[]'
        }
        It "Should have Check as a string array parameter" {
            (Get-Command $Sut).Parameters['Check'].ParameterType.Name | Should -Be 'String[]'
        }
        It "Should have ExcludeCheck as a string array parameter" {
            (Get-Command $Sut).Parameters['ExcludeCheck'].ParameterType.Name | Should -Be 'String[]'
        }
        It "Should have PesterOutputPath as a string parameter" {
            (Get-Command $Sut).Parameters['PesterOutputPath'].ParameterType.Name | Should -Be 'String'
        }
        It "Should fail if PesterOutputPath is not an xml file" {
            Mock -CommandName Test-Path -MockWith {$true}
            {& $Sut -Confirugation TestDrive:\Example.json -PesterOutputPath TestDrive:\FakeFile.csv} | Should -Throw 'Pester output file must be of type XML'
        }
        It "Should have powerBiOutputPath as a string parameter" {
            (Get-Command $Sut).Parameters['powerBiOutputPath'].ParameterType.Name | Should -Be 'String'
        }
        It "Should have credentialUsername as a string parameter" {
            (Get-Command $Sut).Parameters['credentialUsername'].ParameterType.Name | Should -Be 'String'
        }
        It "Should have credentialPassword as a generic object parameter" {
            (Get-Command $Sut).Parameters['credentialPassword'].ParameterType.Name | Should -Be 'Object'
        }
        It "Should have sqlCredentialUsername as a string parameter" {
            (Get-Command $Sut).Parameters['sqlCredentialUsername'].ParameterType.Name | Should -Be 'String'
        }
        It "Should have sqlCredentialPassword as a generic object parameter" {
            (Get-Command $Sut).Parameters['sqlCredentialPassword'].ParameterType.Name | Should -Be 'Object'
        }
    }

    Context "Testing Process" {

    }

    Context "Testing Outputs" {

    }
}
