[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [Parameter(Mandatory = $true)]
    [ValidateSet('develop', 'episode', 'libtv-prepare', 'generate', 'review', 'full')]
    [string]$Mode,
    [Parameter(Mandatory = $true)]
    [ValidateSet('PLANNED', 'READY_FOR_REVIEW', 'NOT_RUN', 'PASS', 'BLOCKED', 'FAIL')]
    [string]$Status,
    [Parameter(Mandatory = $true)]
    [string]$OutJson,
    [switch]$RemoteMutationObserved,
    [switch]$PaidGenerationObserved
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

function Get-Sha256Hex([string]$Path) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $stream = [IO.File]::OpenRead($Path)
        try {
            $hash = $algorithm.ComputeHash($stream)
        } finally {
            $stream.Dispose()
        }
    } finally {
        $algorithm.Dispose()
    }
    return ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

$root = [IO.Path]::GetFullPath($ProjectRoot)
$recordPath = [IO.Path]::GetFullPath($OutJson)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw 'project root does not exist'
}
if (Test-Path -LiteralPath $recordPath) {
    throw 'run record already exists'
}

$artifacts = @(Get-ChildItem -LiteralPath $root -File | Sort-Object Name | ForEach-Object {
    [ordered]@{
        path = $_.Name
        sha256 = Get-Sha256Hex $_.FullName
        size = $_.Length
    }
})
$record = [ordered]@{
    schema_version = 1
    mode = $Mode
    status = $Status
    created_at = [DateTime]::UtcNow.ToString('o')
    remote_mutation_observed = [bool]$RemoteMutationObserved
    paid_generation_observed = [bool]$PaidGenerationObserved
    artifacts = $artifacts
}
$parent = Split-Path -Parent $recordPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$json = $record | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($recordPath, $json + "`n", $utf8)
$record | ConvertTo-Json -Compress -Depth 6
