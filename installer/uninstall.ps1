[CmdletBinding()]
param(
    [string]$TargetRoot = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $env:USERPROFILE '.codex\skills' }),
    [switch]$RemoveLibTVSkill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
. (Join-Path $PSScriptRoot 'package-common.ps1')

$target = [IO.Path]::GetFullPath($TargetRoot)
$product = Assert-ChildPath $target (Join-Path $target 'ai-comic-director')
if (-not (Test-Path -LiteralPath $product -PathType Container)) {
    throw 'installed product Skill not found'
}
if (Test-IsReparsePoint $product) {
    throw 'refusing to uninstall a reparse-point product path'
}
$backupRoot = Assert-ChildPath $target (Join-Path $target '.ai-comic-director-uninstalled')
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$stamp = ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')) + '-' + [Guid]::NewGuid().ToString('N')
$productBackup = Assert-ChildPath $backupRoot (Join-Path $backupRoot $stamp)
Move-Item -LiteralPath $product -Destination $productBackup

$libtvBackup = $null
if ($RemoveLibTVSkill) {
    $libtv = Assert-ChildPath $target (Join-Path $target 'libtv-cli')
    if (Test-Path -LiteralPath $libtv -PathType Container) {
        if (Test-IsReparsePoint $libtv) {
            throw 'refusing to uninstall a reparse-point LibTV Skill path'
        }
        $libtvBackupRoot = Assert-ChildPath $target (Join-Path $target '.libtv-cli-uninstalled')
        New-Item -ItemType Directory -Force -Path $libtvBackupRoot | Out-Null
        $libtvBackup = Assert-ChildPath $libtvBackupRoot (Join-Path $libtvBackupRoot $stamp)
        Move-Item -LiteralPath $libtv -Destination $libtvBackup
    }
}

$result = [ordered]@{
    product = 'ai-comic-director'
    product_backup_path = $productBackup
    libtv_skill_backup_path = $libtvBackup
    libtv_executable_removed = $false
    credentials_removed = $false
    uninstalled_at = [DateTime]::UtcNow.ToString('o')
}
$result | ConvertTo-Json -Compress -Depth 5
