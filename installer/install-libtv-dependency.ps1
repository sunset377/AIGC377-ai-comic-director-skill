[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetRoot,
    [switch]$UpdateLibTV,
    [string]$ActivityUri = 'https://api2.liblib.art/api/www/landing-activities/getById?id=240'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'package-common.ps1')

if ($ActivityUri -ne 'https://api2.liblib.art/api/www/landing-activities/getById?id=240') {
    throw 'unsupported activity URI'
}
$target = [IO.Path]::GetFullPath($TargetRoot)
New-Item -ItemType Directory -Force -Path $target | Out-Null
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-comic-libtv-' + [Guid]::NewGuid().ToString('N'))
Assert-ChildPath ([IO.Path]::GetTempPath()) $tempRoot | Out-Null
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $response = Invoke-RestMethod -Uri $ActivityUri -UseBasicParsing
    if ($null -eq $response.data -or [string]::IsNullOrWhiteSpace([string]$response.data.linkUrl)) {
        throw 'LibTV activity response missing linkUrl'
    }
    $links = ConvertFrom-Json ([string]$response.data.linkUrl)
    $skillUrl = Assert-OfficialDownloadUri ([string]$links.skill)
    $installerUrl = Assert-OfficialDownloadUri ([string]$links.install.PowerShell)
    $version = [string]$links.version
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw 'LibTV activity response missing version'
    }

    $skillZip = Join-Path $tempRoot 'libtv-cli-skill.zip'
    $installerPath = Join-Path $tempRoot 'install-libtv-cli.ps1'
    Invoke-WebRequest -Uri $skillUrl -OutFile $skillZip -UseBasicParsing
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    $extract = Join-Path $tempRoot 'skill-extracted'
    Expand-Archive -LiteralPath $skillZip -DestinationPath $extract -Force
    $entrypoints = @(Get-ChildItem -LiteralPath $extract -Recurse -Filter 'SKILL.md' -File)
    if ($entrypoints.Count -ne 1) {
        throw 'official LibTV Skill ZIP must contain exactly one SKILL.md'
    }
    $sourceRoot = $entrypoints[0].Directory.FullName
    $final = Join-Path $target 'libtv-cli'
    $backup = $null
    if (Test-Path -LiteralPath $final) {
        if (-not $UpdateLibTV) {
            $cli = Get-Command libtv -ErrorAction SilentlyContinue
            return [ordered]@{ status = 'EXISTING'; version = $version; skill_path = $final; cli_available = [bool]$cli }
        }
        $backupRoot = Join-Path $target '.libtv-cli-backups'
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $backup = Join-Path $backupRoot (([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')) + '-' + [Guid]::NewGuid().ToString('N'))
        Move-Item -LiteralPath $final -Destination $backup
    }
    $stage = Join-Path $target ('.libtv-cli-stage-' + [Guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $sourceRoot -Destination $stage -Recurse
    Move-Item -LiteralPath $stage -Destination $final

    & $installerPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "official LibTV installer failed with exit code $LASTEXITCODE"
    }
    $cli = Get-Command libtv -ErrorAction SilentlyContinue
    if ($null -eq $cli) {
        $candidate = Join-Path $env:USERPROFILE '.libtv\libtv.exe'
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw 'LibTV CLI not found after official installation'
        }
    }
    return [ordered]@{ status = 'INSTALLED'; version = $version; skill_path = $final; backup_path = $backup; cli_available = $true }
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    Assert-ChildPath ([IO.Path]::GetTempPath()) $resolvedTemp | Out-Null
    if (Test-Path -LiteralPath $resolvedTemp) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
