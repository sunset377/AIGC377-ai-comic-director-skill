[CmdletBinding()]
param(
    [string]$TargetRoot = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $env:USERPROFILE '.codex\skills' }),
    [string]$OutJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
. (Join-Path $PSScriptRoot 'package-common.ps1')

$target = [IO.Path]::GetFullPath($TargetRoot)
$skill = Assert-ChildPath $target (Join-Path $target 'ai-comic-director')
Assert-SkillTree $skill | Out-Null
$versionPath = Join-Path $skill 'VERSION'
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    throw 'installed VERSION missing'
}
$version = [IO.File]::ReadAllText($versionPath, [Text.Encoding]::UTF8).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'installed VERSION invalid'
}

$tempReport = Join-Path ([IO.Path]::GetTempPath()) ('ai-comic-doctor-' + [Guid]::NewGuid().ToString('N') + '.json')
Assert-ChildPath ([IO.Path]::GetTempPath()) $tempReport | Out-Null
try {
    $doctorOutput = & (Join-Path $PSScriptRoot 'doctor.ps1') -SkillRoot $skill -OutJson $tempReport -SkipWorkspaceProbe
    $doctor = $doctorOutput | ConvertFrom-Json
} finally {
    if (Test-Path -LiteralPath $tempReport) {
        Remove-Item -LiteralPath $tempReport -Force
    }
}
$ok = [bool]$doctor.skill_valid -and [bool]$doctor.libtv_available
$report = [ordered]@{
    ok = $ok
    product = 'ai-comic-director'
    version = $version
    skill_path = $skill
    libtv_available = [bool]$doctor.libtv_available
    login_status = [string]$doctor.login_status
    next_action = if ([string]$doctor.login_status -eq 'LOGGED_IN') { 'RUN_LOCAL_DEMO' } else { 'CUSTOMER_LOGIN_REQUIRED' }
    checked_at = [DateTime]::UtcNow.ToString('o')
}
if (-not [string]::IsNullOrWhiteSpace($OutJson)) {
    Write-JsonNew $report $OutJson | Out-Null
}
$report | ConvertTo-Json -Compress -Depth 6
if (-not $ok) {
    exit 2
}
