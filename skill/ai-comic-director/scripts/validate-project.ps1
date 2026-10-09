[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [Parameter(Mandatory = $true)]
    [string]$OutJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$root = [IO.Path]::GetFullPath($ProjectRoot)
$reportPath = [IO.Path]::GetFullPath($OutJson)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw 'project root does not exist'
}
if (Test-Path -LiteralPath $reportPath) {
    throw 'validation report already exists'
}

$required = @(
    '00_项目卡.md',
    '01_世界观与季纲.md',
    '02_角色连续性档案.md',
    '03_分集剧本.md',
    '04_分镜表.md',
    '05_资产清单.csv',
    '06_LibTV节点图.md',
    '07_QC报告.md'
)
$missing = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]
foreach ($name in $required) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $missing.Add($name)
    } elseif ([IO.Path]::GetExtension($name) -ieq '.md' -and (Get-Item -LiteralPath $path).Length -eq 0) {
        $errors.Add("empty markdown: $name")
    }
}

$assetPath = Join-Path $root '05_资产清单.csv'
if (Test-Path -LiteralPath $assetPath -PathType Leaf) {
    $expectedHeader = 'asset_id,role,file_path,character_id,episode_id,source,rights_status,libtv_node_name,libtv_node_key,upload_status,notes'
    $actualHeader = (Get-Content -LiteralPath $assetPath -Encoding UTF8 -TotalCount 1)
    if ($actualHeader -ne $expectedHeader) {
        $errors.Add('asset manifest header mismatch')
    }
}

$qcPath = Join-Path $root '07_QC报告.md'
if (Test-Path -LiteralPath $qcPath -PathType Leaf) {
    $qc = [IO.File]::ReadAllText($qcPath, [Text.Encoding]::UTF8)
    if ($qc -notmatch 'QCStatus=(PASS|BLOCKED|FAIL)') {
        $errors.Add('invalid QCStatus')
    }
}

$allText = ($required | Where-Object { $_ -like '*.md' } | ForEach-Object {
    $path = Join-Path $root $_
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    }
}) -join "`n"
if ($allText -match '(?m)(^|\s)--run(\s|$)' -and $allText -notmatch 'PAID_RUN_GRANTED\s*[:=：]\s*GRANTED') {
    $errors.Add('paid run command present without PAID_RUN_GRANTED=GRANTED')
}

$ok = ($missing.Count -eq 0 -and $errors.Count -eq 0)
$report = [ordered]@{
    ok = $ok
    missing = @($missing)
    errors = @($errors)
    artifact_count = $required.Count - $missing.Count
    checked_at = [DateTime]::UtcNow.ToString('o')
}
$parent = Split-Path -Parent $reportPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$json = $report | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($reportPath, $json + "`n", $utf8)
$report | ConvertTo-Json -Compress -Depth 5
if (-not $ok) {
    exit 2
}
