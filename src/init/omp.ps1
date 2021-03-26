# Powershell doesn't default to UTF8 just yet, so we're forcing it as there are too many problems
# that pop up when we don't
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$global:PoshSettings = New-Object -TypeName PSObject -Property @{
    Theme = "";
}

# used to detect empty hit
$global:omp_lastHistoryId = -1

$config = "::CONFIG::"
if (Test-Path $config) {
    $global:PoshSettings.Theme = (Resolve-Path -Path $config).Path
}

function global:Set-PoshContext {}

function global:Set-PoshGitStatus {
    if (Get-Module -Name "posh-git") {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '', Justification = 'Variable used later(not in this scope)')]
        $Global:GitStatus = Get-GitStatus
    }
}

[ScriptBlock]$Prompt = {
    #store if the last command was successful
    $lastCommandSuccess = $?
    #store the last exit code for restore
    $realLASTEXITCODE = $global:LASTEXITCODE
    $errorCode = 0
    Set-PoshContext
    if ($lastCommandSuccess -eq $false) {
        #native app exit code
        if ($realLASTEXITCODE -is [int] -and $realLASTEXITCODE -gt 0) {
            $errorCode = $realLASTEXITCODE
        }
        else {
            $errorCode = 1
        }
    }

    $executionTime = -1
    $history = Get-History -ErrorAction Ignore -Count 1
    if ($null -ne $history -and $null -ne $history.EndExecutionTime -and $null -ne $history.StartExecutionTime -and $global:omp_lastHistoryId -ne $history.Id) {
            $executionTime = ($history.EndExecutionTime - $history.StartExecutionTime).TotalMilliseconds
            $global:omp_lastHistoryId = $history.Id
    }
    $omp = "::OMP::"
    $config = $global:PoshSettings.Theme
    $cleanPWD = $PWD.ProviderPath.TrimEnd("\")
    $cleanPSWD = $PWD.ToString().TrimEnd("\")
    $standardOut = @(&$omp --error="$errorCode" --pwd="$cleanPWD" --pswd="$cleanPSWD" --execution-time="$executionTime" --config="$config" 2>&1)
    # the output can be multiline, joining these ensures proper rendering by adding line breaks with `n
    $standardOut -join "`n"
    Set-PoshGitStatus
    $global:LASTEXITCODE = $realLASTEXITCODE
    #remove temp variables
    Remove-Variable realLASTEXITCODE -Confirm:$false
    Remove-Variable lastCommandSuccess -Confirm:$false
}
Set-Item -Path Function:prompt -Value $Prompt -Force

function global:Write-PoshDebug {
    $omp = "::OMP::"
    $config = $global:PoshSettings.Theme
    $cleanPWD = $PWD.ProviderPath.TrimEnd("\")
    $cleanPSWD = $PWD.ToString().TrimEnd("\")
    $standardOut = @(&$omp --error=1337 --pwd="$cleanPWD" --pswd="$cleanPSWD" --execution-time=9001 --config="$config" --debug 2>&1)
    $standardOut -join "`n"
}

function global:Export-PoshTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath,
        [Parameter(Mandatory = $false)]
        [ValidateSet('json','yaml','toml')]
        [string]
        $Format = 'json'
    )

    if ($FilePath.StartsWith('~')) {
        $FilePath = $FilePath.Replace('~', $HOME)
    }

    $config = $global:PoshSettings.Theme
    $omp = "::OMP::"
    $configString = @(&$omp --config="$config" --config-format="$Format" --print-config 2>&1)
    [IO.File]::WriteAllLines($FilePath, $configString)
}
