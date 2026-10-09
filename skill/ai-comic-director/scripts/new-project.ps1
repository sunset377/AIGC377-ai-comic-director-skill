[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

function Assert-SafeProjectName([string]$Value) {
    $trimmed = $Value.Trim()
    $reserved = '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$'
    if ([string]::IsNullOrWhiteSpace($trimmed) -or
        $trimmed -ne $Value -or
        $Value.Contains('..') -or
        $Value.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Value.Contains([IO.Path]::DirectorySeparatorChar) -or
        $Value.Contains([IO.Path]::AltDirectorySeparatorChar) -or
        $Value.EndsWith('.') -or
        $Value.EndsWith(' ') -or
        $Value -match $reserved) {
        throw 'invalid project name'
    }
}

function Assert-ChildPath([string]$Parent, [string]$Child) {
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'resolved project path escapes output root'
    }
}

Assert-SafeProjectName $Name
$root = [IO.Path]::GetFullPath($OutputRoot)
New-Item -ItemType Directory -Force -Path $root | Out-Null
$projectRoot = Join-Path $root $Name
Assert-ChildPath $root $projectRoot
if (Test-Path -LiteralPath $projectRoot) {
    throw 'project target already exists'
}

$templateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets\templates'))
$mapping = [ordered]@{
    'project-card.md' = '00_项目卡.md'
    'season-outline.md' = '01_世界观与季纲.md'
    'character-bible.md' = '02_角色连续性档案.md'
    'episode-script.md' = '03_分集剧本.md'
    'storyboard.md' = '04_分镜表.md'
    'asset-manifest.csv' = '05_资产清单.csv'
    'node-map.md' = '06_LibTV节点图.md'
    'qc-report.md' = '07_QC报告.md'
}

$stage = Join-Path $root ('.ai-comic-director-stage-' + [Guid]::NewGuid().ToString('N'))
Assert-ChildPath $root $stage
New-Item -ItemType Directory -Path $stage | Out-Null
$createdAt = [DateTime]::UtcNow.ToString('o')

try {
    foreach ($sourceName in $mapping.Keys) {
        $source = Join-Path $templateRoot $sourceName
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "required template missing: $sourceName"
        }
        $destination = Join-Path $stage $mapping[$sourceName]
        if ([IO.Path]::GetExtension($sourceName) -ieq '.csv') {
            [IO.File]::Copy($source, $destination, $false)
        } else {
            $text = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
            $text = $text.Replace('[项目名称]', $Name).Replace('[创建时间]', $createdAt)
            [IO.File]::WriteAllText($destination, $text, $utf8)
        }
    }
    Move-Item -LiteralPath $stage -Destination $projectRoot
} catch {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    throw
}

$receipt = [ordered]@{
    project_root = [IO.Path]::GetFullPath($projectRoot)
    created_at = $createdAt
    artifact_count = $mapping.Count
}
$receipt | ConvertTo-Json -Compress
