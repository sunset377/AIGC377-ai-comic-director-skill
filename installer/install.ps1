[CmdletBinding()]
param(
    [string]$TargetRoot = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $env:USERPROFILE '.codex\skills' }),
    [switch]$Upgrade,
    [switch]$InstallLibTV,
    [switch]$UpdateLibTV,
    [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
. (Join-Path $PSScriptRoot 'package-common.ps1')

$packageRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (Test-Path -LiteralPath (Join-Path $packageRoot 'checksums.sha256') -PathType Leaf) {
    Assert-PackageIntegrity $packageRoot | Out-Null
}
$source = Join-Path $packageRoot 'skill\ai-comic-director'
Assert-SkillTree $source | Out-Null
$version = [IO.File]::ReadAllText((Join-Path $packageRoot 'VERSION'), [Text.Encoding]::UTF8).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'invalid package version'
}

$target = [IO.Path]::GetFullPath($TargetRoot)
New-Item -ItemType Directory -Force -Path $target | Out-Null
$final = Assert-ChildPath $target (Join-Path $target 'ai-comic-director')
$stage = Assert-ChildPath $target (Join-Path $target ('.ai-comic-director-stage-' + [Guid]::NewGuid().ToString('N')))
$backup = $null

if (Test-Path -LiteralPath $final) {
    $installedVersionPath = Join-Path $final 'VERSION'
    $installedVersion = if (Test-Path -LiteralPath $installedVersionPath -PathType Leaf) {
        [IO.File]::ReadAllText($installedVersionPath, [Text.Encoding]::UTF8).Trim()
    } else {
        'unknown'
    }
    if (-not $Upgrade) {
        throw "skill already installed: $installedVersion"
    }
}

try {
    New-Item -ItemType Directory -Path $stage | Out-Null
    Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse
    }
    [IO.File]::WriteAllText((Join-Path $stage 'VERSION'), $version + "`n", $utf8)
    Assert-SkillTree $stage | Out-Null

    if (Test-Path -LiteralPath $final) {
        $backupRoot = Assert-ChildPath $target (Join-Path $target '.ai-comic-director-backups')
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $backup = Assert-ChildPath $backupRoot (Join-Path $backupRoot (([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')) + '-' + [Guid]::NewGuid().ToString('N')))
        Move-Item -LiteralPath $final -Destination $backup
    }
    Move-Item -LiteralPath $stage -Destination $final
} catch {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if ($backup -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $final)) {
        Move-Item -LiteralPath $backup -Destination $final
    }
    throw
}

$dependency = [ordered]@{ status = 'NOT_REQUESTED' }
if ($InstallLibTV) {
    $dependency = & (Join-Path $PSScriptRoot 'install-libtv-dependency.ps1') -TargetRoot $target -UpdateLibTV:$UpdateLibTV
}
$receipt = [ordered]@{
    product = 'ai-comic-director'
    version = $version
    install_path = $final
    backup_path = $backup
    libtv_dependency = $dependency
    login_required = $true
    installed_at = [DateTime]::UtcNow.ToString('o')
}
if (-not [string]::IsNullOrWhiteSpace($ReceiptPath)) {
    Write-JsonNew $receipt $ReceiptPath | Out-Null
}
$receipt | ConvertTo-Json -Compress -Depth 8
