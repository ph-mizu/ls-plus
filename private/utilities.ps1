# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function get-ls-terminal-width {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width

        if ($width -gt 0) {
            return $width
        }
    }
    catch {
    }

    return 120
}


function test-ls-reparse-point {
    param(
        [System.IO.FileSystemInfo]
        $item
    )

    # Windows PowerShell 5.1 leaves LinkType empty for junctions
    # (e.g. 'C:\Users\<user>\Local Settings'), so fall back to the
    # ReparsePoint attribute bit which covers symlinks and junctions.
    if ($item.LinkType) {
        return $true
    }

    return [bool](
        $item.Attributes -band
        [System.IO.FileAttributes]::ReparsePoint
    )
}


function get-ls-link-target {
    param(
        [System.IO.FileSystemInfo]
        $item
    )

    if ($item.Target) {
        return [string]$item.Target
    }

    # Readable junctions/symlinks normally populate .Target, but
    # PowerShell 5.1 leaves it empty in some cases (and always when
    # the link itself denies read, e.g. 'Local Settings'). Fall back
    # to fsutil; if that fails too, there is no arrow to show.
    try {
        $fsutil = Get-Command fsutil `
            -CommandType Application `
            -ErrorAction Stop

        $lines = @(
            & $fsutil reparsepoint query $item.FullName 2>$null
        )

        foreach ($line in $lines) {
            if ($line -match 'Print Name:\s*(.+)') {
                $printed = $Matches[1].Trim()

                if ($printed) {
                    return $printed
                }
            }
        }

        foreach ($line in $lines) {
            if ($line -match 'Substitute Name:\s*(.+)') {
                return (
                    $Matches[1].Trim() -replace '^\\\?\?\\', ''
                )
            }
        }
    }
    catch {
    }

    return $null
}


function get-ls-type-mark {
    param(
        [System.IO.FileSystemInfo]
        $item
    )

    # Reparse point first: a symlink-to-directory is still a link.
    if (test-ls-reparse-point -item $item) {
        return '@'
    }

    if ($item.PSIsContainer) {
        return '/'
    }

    $extension = $item.Extension.ToLowerInvariant()

    $executableExtensions = @(
        '.exe'
        '.com'
        '.bat'
        '.cmd'
        '.ps1'
    )

    if ($executableExtensions -contains $extension) {
        return '*'
    }

    return ''
}


function get-ls-display-name {
    param(
        [System.IO.FileSystemInfo]
        $item,

        [switch]
        $classify
    )

    $name = $item.Name

    if ($classify) {
        $name += get-ls-type-mark -item $item
    }

    return $name
}


function format-ls-size {
    param(
        [long]
        $bytes,

        [switch]
        $humanReadable
    )

    if (-not $humanReadable) {
        return [string]$bytes
    }

    if ($bytes -lt 1024) {
        return "${bytes}B"
    }

    $units = @(
        'K'
        'M'
        'G'
        'T'
        'P'
        'E'
    )

    $value = [double]$bytes
    $unitIndex = -1

    while (
        $value -ge 1024 -and
        $unitIndex -lt ($units.Count - 1)
    ) {
        $value /= 1024
        $unitIndex++
    }

    # No spaces anywhere in human-readable sizes: '100B', '2.9K'.
    if ($value -ge 10) {
        return '{0:N0}{1}' -f $value, $units[$unitIndex]
    }

    return '{0:N1}{1}' -f $value, $units[$unitIndex]
}