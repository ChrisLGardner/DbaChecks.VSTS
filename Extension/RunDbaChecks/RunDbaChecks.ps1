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

Install-Module -Name DbaChecks -Scope CurrentUser -Force -SkipPublisherCheck -Repository (Get-PsRepository)[0].Name

$AvailableChecks = Get-DbcCheck
$Check = $Check -split ',' | Foreach-Object {
    if ($_ -notin $AvailableChecks) {
        Write-Warning -Message "$_ not in list of available checks, please double check spelling."
    }
    else {
        $_
    }}
$ExcludeCheck = $ExcludeCheck -split ',' | Foreach-Object {
    if ($_ -notin $AvailableChecks) {
        Write-Warning -Message "$_ not in list of available checks, please double check spelling."
    }
    else {
        $_
    }}

if (Test-Path -Path $pesterOutputPath) {
    Write-Warning -Message "Pester output file already exists, this will overwrite the existing file: $pesterOutputPath"
}

if (Test-Path -Path $powerBiOutputPath) {
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

$SqlInstance = $SqlInstance.Split(',')
$ComputerName = $ComputerName.Split(',')

if ($SqlInstance) {
    Write-Verbose -Message "Adding SQL instances to Invoke-DbcCheck call"
    $InvokeDbcCheckParameters.Add('SqlInstance',$SqlInstance)
}

if ($ComputerName) {
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
if ($SqlInstance) {
    $InvokeDbcCheckParameters.Add('SqlInstance',$SqlInstance)
}
if ($SqlServer) {
    $InvokeDbcCheckParameters.Add('SqlServer',$SqlServer)
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

$InvokeDbcCheckOutput = Invoke-DbcCheck @InvokeDbcCheckParameters -PassThru

if ($powerBiOutputPath) {
    Write-Verbose -Message "Outputting PowerBI data to $powerBiOutputPath"
    $InvokeDbcCheckOutput | Update-DbcPowerBiDataSource -Path $powerBiOutputPath
}
