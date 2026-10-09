Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Assert-ChildPath([string]$Parent, [string]$Child) {
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "path escapes parent: $childFull"
    }
    return $childFull
}

function Test-IsReparsePoint([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Assert-PackageIntegrity([string]$PackageRoot) {
    $root = [IO.Path]::GetFullPath($PackageRoot)
    $checksumPath = Join-Path $root 'checksums.sha256'
    if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
        throw 'checksums.sha256 is missing'
    }
    $expected = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in [IO.File]::ReadAllLines($checksumPath, [Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
            throw 'invalid checksum line'
        }
        $relative = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
        if ([IO.Path]::IsPathRooted($relative) -or ($relative -split '[\\/]') -contains '..') {
            throw 'unsafe checksum path'
        }
        $full = Assert-ChildPath $root (Join-Path $root $relative)
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "checksum file missing: $relative"
        }
        if (Test-IsReparsePoint $full) {
            throw "reparse-point package file rejected: $relative"
        }
        $actual = Get-Sha256Hex $full
        if ($actual -ne $Matches[1].ToLowerInvariant()) {
            throw "hash mismatch: $relative"
        }
        $expected[$relative] = $actual
    }
    $actualFiles = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File | ForEach-Object {
        $_.FullName.Substring($root.TrimEnd('\', '/').Length + 1)
    })
    foreach ($relative in $actualFiles) {
        if ($relative -ieq 'checksums.sha256') { continue }
        if (-not $expected.ContainsKey($relative)) {
            throw "unmanifested package file: $relative"
        }
    }
    return $true
}

function Assert-SkillTree([string]$SkillRoot) {
    $root = [IO.Path]::GetFullPath($SkillRoot)
    $entrypoint = Join-Path $root 'SKILL.md'
    if (-not (Test-Path -LiteralPath $entrypoint -PathType Leaf)) {
        throw 'invalid skill tree: SKILL.md missing'
    }
    $text = [IO.File]::ReadAllText($entrypoint, [Text.Encoding]::UTF8)
    if ($text -notmatch '(?s)^---\s*\r?\n.*?\r?\n---\s*\r?\n' -or
        $text -notmatch '(?m)^name:\s*ai-comic-director\s*$' -or
        $text -notmatch '(?m)^description:\s*\S.+$') {
        throw 'invalid skill tree: frontmatter'
    }
    foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "invalid skill tree: reparse point $($item.FullName)"
        }
    }
    return $true
}

function Write-JsonNew([hashtable]$Value, [string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) {
        throw "output already exists: $full"
    }
    $parent = Split-Path -Parent $full
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($full, (($Value | ConvertTo-Json -Depth 8) + "`n"), $utf8)
    return $full
}

function Assert-OfficialDownloadUri([string]$Uri) {
    $parsed = [Uri]$Uri
    if ($parsed.Scheme -ne 'https' -or $parsed.Host -ne 'liblibai-web-static.liblib.cloud') {
        throw "untrusted LibTV download URI: $Uri"
    }
    return $parsed.AbsoluteUri
}
