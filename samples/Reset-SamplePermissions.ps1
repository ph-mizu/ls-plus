# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

# Re-applies the samples/ demo state that git cannot preserve:
# Windows ACLs, the Hidden flag, the sized demo file, and the
# junction/symlink entries. Idempotent. Run after cloning.
# Must run in the same user context that will demo ls-plus.
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

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
#    (mini Local Settings).
Reset-DenyRule -path (Join-Path $root 'locked') -rights '(OI)(CI)R'

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
