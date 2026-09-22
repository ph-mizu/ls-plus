# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

# Generates the samples/ demo fixtures from scratch and applies the
# demo state that git cannot preserve (Windows ACLs, attribute flags,
# junction/symlink entries). Idempotent. Run after cloning.
# Must run in the same user context that will demo ls-plus.
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot 'samples'
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

# A previous run's deny blocks even Test-Path, which aborts this
# script under Stop preference. The deny is re-applied in section
# 2 below; lifting it here is safe on fresh roots (no locked dir).
& icacls (Join-Path $root 'locked') /remove:d ("*" + $sid) 2>$null | Out-Null

foreach ($dir in @('', 'sub', 'locked')) {
    $path = Join-Path $root $dir

    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

$fixtures = [ordered]@{
    'full.txt'          = "Full access sample file. Expect rwx in the permission string.`n"
    'granted.txt'       = "Explicit-grant sample file. Setup script grants R explicitly, expect ! marker.`n"
    'hidden-note.txt'   = "Hidden attribute sample. Visible only with -a. Setup script sets the Hidden flag.`n"
    'readonly-attr.txt' = "ReadOnly-attribute sample file. Setup script sets ReadOnly, expect w dark while readable.`n"
    'tool.ps1'          = "Write-Output 'tool sample: executable mark * expected with -F.'`n"
    'sub\inner.txt'     = "Inner file of the normal subdirectory.`n"
    'locked\secret.txt' = "Locked directory sample. Setup script denies R for the current user, expect list/open errors like Local Settings.`n"
}

foreach ($entry in $fixtures.GetEnumerator()) {
    $path = Join-Path $root $entry.Key

    if (-not (Test-Path -LiteralPath $path)) {
        $entry.Value | Set-Content -LiteralPath $path -NoNewline
    }
}

function Reset-DenyRule {
    param(
        [string]$path,
        [string]$rights
    )

    # Explicit denies are cleared first; re-runs are idempotent.
    & icacls $path /remove:d ("*" + $sid) 2>$null | Out-Null
    & icacls $path /deny ("*" + $sid + ":" + $rights) | Out-Null
}

# 1. ReadOnly-attribute file (readable, w dark via effective-write
#    folding). Attribute-based: an icacls deny always carries
#    Synchronize and would block reads too.
$readOnlySample = Get-Item -LiteralPath (Join-Path $root 'readonly-attr.txt') -Force
$readOnlySample.Attributes = $readOnlySample.Attributes -bor [System.IO.FileAttributes]::ReadOnly

# 1-b. Explicit-grant file (non-inherited Allow for current user).
$granted = Join-Path $root 'granted.txt'
& icacls $granted /remove:d ("*" + $sid) 2>$null | Out-Null
& icacls $granted /remove:g ("*" + $sid) 2>$null | Out-Null
& icacls $granted /grant ("*" + $sid + ":R") | Out-Null

# 2. Locked dir -> 'd-wx...' on the entry, list/open denied
#    (mini Local Settings). The payload is ensured while the deny
#    is lifted, then the deny is re-applied; ordering is significant
#    because the deny blocks reads and handle opens.
$lockedDir = Join-Path $root 'locked'
$lockedPayload = Join-Path $lockedDir 'secret.txt'
& icacls $lockedDir /remove:d ("*" + $sid) 2>$null | Out-Null
if (-not (Test-Path -LiteralPath $lockedPayload)) {
    $fixtures['locked\secret.txt'] | Set-Content -LiteralPath $lockedPayload -NoNewline
    Write-Output 'locked payload recreated.'
}
Reset-DenyRule -path $lockedDir -rights '(OI)(CI)R'

# 3. Hidden attribute sample (visible only with -a).
$hidden = Get-Item -LiteralPath (Join-Path $root 'hidden-note.txt') -Force
$hidden.Attributes = $hidden.Attributes -bor [System.IO.FileAttributes]::Hidden

# 4. Sized demo file for -h (recreated if missing).
$sized = Join-Path $root 'sized-3k.txt'

if (-not (Test-Path -LiteralPath $sized)) {
    "x" * 3000 | Set-Content -LiteralPath $sized -NoNewline
}

# 5. Junction entry -> 'l... link -> target' (no admin needed).
$jump = Join-Path $root 'app-link'
$sub = Join-Path $root 'sub'

# Junction removal uses rmdir: only the link itself is removed,
# and no confirmation prompt occurs (Remove-Item prompts for
# children on junctions).
if (Test-Path -LiteralPath $jump) {
    cmd /c rmdir $jump | Out-Null
}

cmd /c mklink /J $jump $sub | Out-Null

# 6. Symlink entry. Needs admin or Developer Mode; skip with a
#    warning when unavailable.
$symlink = Join-Path $root 'file-link.txt'
$symTarget = Join-Path $root 'full.txt'

if (Test-Path -LiteralPath $symlink) {
    Remove-Item -LiteralPath $symlink -Force
}

try {
    New-Item -ItemType SymbolicLink `
        -Path $symlink `
        -Target $symTarget `
        -ErrorAction Stop | Out-Null

    Write-Output 'symlink: file-link.txt created.'
}
catch {
    Write-Warning (
        'symlink skipped (needs admin/Developer Mode): ' +
        $_.Exception.Message
    )
}

Write-Output 'samples reset done.'
