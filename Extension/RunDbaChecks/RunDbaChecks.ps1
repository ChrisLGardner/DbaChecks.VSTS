[cmdletbinding()]
param (
    [parameter(Mandatory)]
    [alias('pspath')]
    [validateScript({
        if (-not (Test-Path -Path $_ -PathType Leaf)) {
            throw 'Invalid Path specified'
        }
        $true
    })]
    [string]$Configuration,

    [string[]]$SqlInstance,

    [string[]]$ComputerName,

    [string[]]$Check,

    [string[]]$ExcludeCheck,

    [validateScript({
        if ($_.split('.')[-1] -ne 'xml') {
            throw 'Pester output file must be of type XML'
        }
        $true
    })]
    [string]$pesterOutputPath,

    [string]$powerBiOutputPath,

    [string]$credentialUsername,

    $credentialPassword,

    [string]$sqlCredentialUsername,

    $sqlCredentialPassword
)

Write-Verbose -Message "Attempting Install of latest version of DbaChecks"
if (Get-Module PowerShellGet -ListAvailable) {
    Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false -Verbose:$false
    Install-Module -Name DbaChecks -Scope CurrentUser -Force -Repository (Get-PsRepository)[0].Name
}
elseif (-not(Get-Module DbaChecks -ListAvailable)) {
    Write-Error "DbaChecks not found and PowerShellGet not available to install latest version. Please install either to enable DbaChecks to run."
    Exit -1
}
$AvailableChecks = Get-DbcCheck
$Check = $Check -split ',' | Foreach-Object {
    if ($_ -notin $AvailableChecks.AllTags) {
        Write-Warning -Message "$_ not in list of available checks, please double check spelling."
    }
    else {
        $_
    }}
$ExcludeCheck = $ExcludeCheck -split ',' | Foreach-Object {
    if ($_ -notin $AvailableChecks.AllTags) {
        Write-Warning -Message "$_ not in list of available checks, please double check spelling."
    }
    else {
        $_
    }}

if ($pesterOutputPath -and (Test-Path -Path $pesterOutputPath)) {
    Write-Warning -Message "Pester output file already exists, this will overwrite the existing file: $pesterOutputPath"
}

if ($powerBiOutputPath -and (Test-Path -Path $powerBiOutputPath)) {
    Write-Warning -Message "PowerBI output file already exists, this will overwrite the existing file: $powerBiOutputPath"
}

if (([string]::IsNullOrWhiteSpace($credentialUsername) -and $credentialPassword) -or
 ($credentialUsername -and [string]::IsNullOrWhiteSpace($credentialPassword))) {
    Write-Warning -Message "Full credentials not provided, please check values enterred."
}
elseif ($credentialUsername -and $credentialPassword) {
    $Credential = New-Object System.Management.Automation.PSCredential ($credentialUsername, (ConvertTo-SecureString $credentialPassword -AsPlainText -Force))
}

if (([string]::IsNullOrWhiteSpace($sqlCredentialUsername) -and $sqlCredentialPassword) -or
 ($sqlCredentialUsername -and [string]::IsNullOrWhiteSpace($sqlCredentialPassword))) {
    Write-Warning -Message "Full SQL credentials not provided, please check values enterred."
}
elseif ($sqlCredentialUsername -and $sqlCredentialPassword) {
    $Credential = New-Object System.Management.Automation.PSCredential ($sqlCredentialUsername, (ConvertTo-SecureString $sqlCredentialPassword -AsPlainText -Force))
}

Import-DbcConfig -Path $Configuration

$InvokeDbcCheckParameters = @{}

if ($SqlInstance) {
    $SqlInstance = $SqlInstance.Split(',')
    Write-Verbose -Message "Adding SQL instances to Invoke-DbcCheck call"
    $InvokeDbcCheckParameters.Add('SqlInstance',$SqlInstance)
}

if ($ComputerName) {
    $ComputerName = $ComputerName.Split(',')
    Write-Verbose -Message "Adding computer names to Invoke-DbcCheck call"
    $InvokeDbcCheckParameters.Add('ComputerName',$ComputerName)
}

if ($Check -and ($Check -ne '*' -or [string]::IsNullOrWhiteSpace($Check))) {
    Write-Verbose -Message "Adding required checks to Invoke-DbcCheck call."
    $InvokeDbcCheckParameters.add('Check',$Check)
}
else {
    $InvokeDbcCheckParameters.Add('AllChecks',$true)
}
if ($ExcludeCheck) {
    Write-Verbose -Message "Adding excluded checks to Invoke-DbcCheck call."
    $InvokeDbcCheckParameters.add('ExcludeCheck',$ExcludeCheck)
}
if ($pesterOutputPath) {
    Write-Verbose -Message "Adding Pester output file to Invoke-DbcCheck call."
    $InvokeDbcCheckParameters.add('OutputFile',$pesterOutputPath)
    $InvokeDbcCheckParameters.add('OutputFormat','NunitXML')
}
if ($Credential) {
    Write-Verbose -Message "Adding Credential to Invoke-DbcCheck call"
    $InvokeDbcCheckParameters.Add('Credential',$Credential)
}
if ($SqlCredential) {
    Write-Verbose -Message "Adding SQL Credential to Invoke-DbcCheck call"
    $InvokeDbcCheckParameters.Add('SqlCredential',$SqlCredential)
}

$InvokeDbcCheckOutput = Invoke-DbcCheck @InvokeDbcCheckParameters -PassThru

if ($powerBiOutputPath) {
    Write-Verbose -Message "Outputting PowerBI data to $powerBiOutputPath"
    $InvokeDbcCheckOutput | Update-DbcPowerBiDataSource -Path $powerBiOutputPath
}
