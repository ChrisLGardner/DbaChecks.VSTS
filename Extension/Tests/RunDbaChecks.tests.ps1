$Sut = Join-Path -Path $PsScriptRoot -ChildPath "..\RunDbaChecks\RunDbaChecks.ps1" -Resolve
if (-not (Get-Module dbachecks -ListAvailable)) {
    Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false
    Install-Module -Name DbaChecks -Scope CurrentUser -Force -Repository (Get-PsRepository)[0].Name
}

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
        $MockTags = @('One','Two','Three')
        Mock -CommandName Get-DbcCheck -MockWith {
            [pscustomobject]@{AllTags = $MockTags}
        }
        Mock -CommandName Test-Path -MockWith {$true}
        Mock -CommandName Import-DbcConfig -MockWith {}
        Mock -CommandName Invoke-DbcCheck -MockWith {}
        Mock -CommandName Update-DbcPowerBiDataSource -MockWith {}

        It "Should correctly split an array of checks" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check 'One,Two,Three'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Check -and ($Check | Where-Object {$_ -in $MockTags}).Count -eq $Check.Count}
        }
        It "Should correctly remove unavailable checks when using Check parameter" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check 'One,Two,Four'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Check -and $Check.Count -eq 2}
        }
        It "Should not pass Checks to Invoke-DbcCheck when no valid checks are found" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check 'Four,Five,Six'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Check -eq $Null}
        }
        It "Should correctly split an array of exclude checks" {
            &$Sut -Configuration TestDrive:\TestFile.json -ExcludeCheck 'One,Two,Three'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$ExcludeCheck -and ($ExcludeCheck | Where-Object {$_ -in $MockTags}).Count -eq $ExcludeCheck.Count}
        }
        It "Should correctly remove unavailable checks when using ExcludeCheck parameter" {
            &$Sut -Configuration TestDrive:\TestFile.json -ExcludeCheck 'One,Two,Four'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$ExcludeCheck -and $ExcludeCheck.Count -eq 2}
        }
        It "Should not pass ExcludeCheck to Invoke-DbcCheck when no valid checks are found" {
            &$Sut -Configuration TestDrive:\TestFile.json -ExcludeCheck 'Four,Five,Six'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$ExcludeCheck -eq $Null}
        }
        It "Should pass AllChecks to Invoke-DbcCheck when * is passed to Check parameter" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check '*'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$AllChecks}
        }
        It "Should pass AllChecks to Invoke-DbcCheck when '' is passed to Check parameter" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check ''

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$AllChecks}
        }
        It "Should pass AllChecks to Invoke-DbcCheck when '  ' is passed to Check parameter" {
            &$Sut -Configuration TestDrive:\TestFile.json -Check '  '

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$AllChecks}
        }
        It "Should warn when the PesterOutputPath already exists" {
            &$Sut -Configuration TestDrive:\TestFile.json -PesterOutputPath TestDrive:\TestOutput.xml

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -like 'Pester output file already exists*'}
        }
        It "Should warn when the PowerBiOutputPath already exists" {
            &$Sut -Configuration TestDrive:\TestFile.json -powerBiOutputPath TestDrive:\TestOutput.xml

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -like 'PowerBI output file already exists*'}
        }
        It "Should warn when a credential username is passed in without a password and not produce a credential object for Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -credentialUsername 'Username'

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -eq 'Full credentials not provided, please check values enterred.'}
            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Credential -eq $Null}
        }
        It "Should warn when a credential password is passed in without a username and not produce a credential object for Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -credentialPassword '5up3r5ecr3t!'

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -eq 'Full credentials not provided, please check values enterred.'}
            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Credential -eq $Null}
        }
        It "Should create the Credential object and pass it to Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -credentialUsername 'Username' -credentialPassword '5up3r5ecr3t!'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$Credential -and $Credential.Username -eq 'Username' -and $Credential.GetNetworkCredential().Password -eq '5up3r5ecr3t!'}
        }
        It "Should warn when a SQL credential username is passed in without a password and not produce a credential object for Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -sqlCredentialUsername 'SqlUsername'

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -eq 'Full SQL credentials not provided, please check values enterred.'}
            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$SqlCredential -eq $Null}
        }
        It "Should warn when a  SQL credential password is passed in without a username and not produce a credential object for Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -sqlCredentialPassword '5up3r5ecr3t!'

            Assert-MockCalled -CommandName Write-Warning -Scope It -ParameterFilter {$Message -eq 'Full SQL credentials not provided, please check values enterred.'}
            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$SqlCredential -eq $Null}
        }
        It "Should create the SQL Credential object and pass it to Invoke-DbcCheck" {
            &$Sut -Configuration TestDrive:\TestFile.json -sqlCredentialUsername 'SqlUsername' -sqlCredentialPassword '5up3r5ecr3t!'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$SqlCredential -and $SqlCredential.Username -eq 'SqlUsername' -and $SqlCredential.GetNetworkCredential().Password -eq '5up3r5ecr3t!'}
        }
        It "Should correctly split a string of Sql Instance names and pass to Invoke-DbcCheck as an array" {
            &$Sut -Configuration TestDrive:\TestFile.json -SqlInstance 'Localhost\SqlInstance1, remote\sqlinstance2'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$SqlInstance -and $SqlInstance.Count -eq 2}
        }
        It "Should correctly split a string of computer names and pass to Invoke-DbcCheck as an array" {
            &$Sut -Configuration TestDrive:\TestFile.json -ComputerName 'Localhost, remote'

            Assert-MockCalled -CommandName Invoke-DbcCheck -Scope It -ParameterFilter {$ComputerName -and $ComputerName.Count -eq 2}
        }
    }

    Context "Testing Outputs" {

    }
}
