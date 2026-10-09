[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SkillRoot,
    [string]$OutJson,
    [switch]$SkipWorkspaceProbe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
. (Join-Path $PSScriptRoot 'package-common.ps1')

function Invoke-NativeProbe([string]$FilePath, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $captured = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $captured
    }
}

$skill = [IO.Path]::GetFullPath($SkillRoot)
$skillValid = $false
try {
    Assert-SkillTree $skill | Out-Null
    $skillValid = $true
} catch {
    $skillValid = $false
}

$blockers = New-Object System.Collections.Generic.List[string]
if (-not $skillValid) {
    $blockers.Add('SKILL_INVALID')
}
$libtv = Get-Command libtv -ErrorAction SilentlyContinue
$libtvAvailable = $false
$libtvVersion = $null
$loginStatus = 'CLI_MISSING'
$workspaceStatus = 'NOT_ATTEMPTED'

if ($null -eq $libtv) {
    $blockers.Add('LIBTV_CLI_MISSING')
} else {
    $versionProbe = Invoke-NativeProbe $libtv.Source @('--version')
    if ($versionProbe.ExitCode -eq 0 -and $versionProbe.Output.Count -gt 0) {
        $candidate = ([string]$versionProbe.Output[0]).Trim()
        if ($candidate -match '^[0-9]+(?:\.[0-9A-Za-z-]+)+$') {
            $libtvAvailable = $true
            $libtvVersion = $candidate
        }
    }
    if (-not $libtvAvailable) {
        $blockers.Add('LIBTV_CLI_UNUSABLE')
        $loginStatus = 'CLI_UNUSABLE'
    } else {
        $accountProbe = Invoke-NativeProbe $libtv.Source @('account', 'info')
        if ($accountProbe.ExitCode -eq 0) {
            $loginStatus = 'LOGGED_IN'
            if ($SkipWorkspaceProbe) {
                $workspaceStatus = 'SKIPPED'
            } else {
                $workspaceProbe = Invoke-NativeProbe $libtv.Source @('workspace', 'list', '-s', '1')
                if ($workspaceProbe.ExitCode -eq 0) {
                    $workspaceStatus = 'READ_OK'
                } else {
                    $workspaceStatus = 'READ_BLOCKED'
                    $blockers.Add('LIBTV_WORKSPACE_READ_BLOCKED')
                }
            }
        } else {
            $loginStatus = 'LOGIN_REQUIRED'
            $workspaceStatus = 'NOT_ATTEMPTED'
            $blockers.Add('LIBTV_LOGIN_REQUIRED')
        }
    }
}

$report = [ordered]@{
    schema_version = 1
    skill_valid = $skillValid
    libtv_available = $libtvAvailable
    libtv_version = $libtvVersion
    login_status = $loginStatus
    workspace_read_status = $workspaceStatus
    blockers = @($blockers)
    checked_at = [DateTime]::UtcNow.ToString('o')
}
if (-not [string]::IsNullOrWhiteSpace($OutJson)) {
    Write-JsonNew $report $OutJson | Out-Null
}
$report | ConvertTo-Json -Compress -Depth 6
