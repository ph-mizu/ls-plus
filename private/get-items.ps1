# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function test-ls-hidden {
    param(
        [System.IO.FileSystemInfo]
        $item
    )

    # Hidden and System are defined as concealed without -a,
    # matching Explorer and cmd dir defaults.
    return [bool](
        $item.Attributes -band
        ([System.IO.FileAttributes]::Hidden -bor
         [System.IO.FileAttributes]::System)
    )
}


function get-ls-sorted-items {
    param(
        [System.IO.FileSystemInfo[]]
        $items,

        [pscustomobject]
        $options
    )

    # Sort order is defined as: name ascending, time and size
    # descending (newest first, largest first). The -r flag
    # reverses the resulting order.
    switch ($options.sort) {
        'time' {
            $items = @(
                $items | Sort-Object LastWriteTime -Descending
            )
        }

        'size' {
            $items = @(
                $items | Sort-Object `
                    -Property @{
                        Expression = {
                            if ($_.PSIsContainer) {
                                [long]0
                            }
                            else {
                                [long]$_.Length
                            }
                        }
                        Descending = $true
                    }
            )
        }

        default {
            $items = @(
                $items | Sort-Object Name
            )
        }
    }

    if ($options.reverse) {
        [array]::Reverse($items)
    }

    return $items
}


function get-ls-directory-items {
    param(
        [System.IO.DirectoryInfo]
        $directory,

        [pscustomobject]
        $options
    )

    try {
        $items = @(
            Get-ChildItem `
                -LiteralPath $directory.FullName `
                -Force `
                -ErrorAction Stop
        )
    }
    catch {
        Write-Error "ls: cannot open '$($directory.FullName)': $($_.Exception.Message)"
        return @()
    }

    if (-not $options.all) {
        $items = @(
            $items |
                Where-Object {
                    -not (test-ls-hidden -item $_)
                }
        )
    }

    return get-ls-sorted-items `
        -items $items `
        -options $options
}


function get-ls-item-groups {
    param(
        [System.Collections.Generic.List[string]]
        $paths,

        [pscustomobject]
        $options
    )

    if ($paths.Count -eq 0) {
        $paths = [System.Collections.Generic.List[string]]::new()
        $paths.Add('.')
    }

    $files = [System.Collections.Generic.List[object]]::new()
    $directories = [System.Collections.Generic.List[object]]::new()

    foreach ($path in $paths) {
        try {
            $resolved = Get-Item `
                -LiteralPath $path `
                -Force `
                -ErrorAction Stop
        }
        catch {
            Write-Error "ls: cannot access '$path': $($_.Exception.Message)"
            continue
        }

        if (
            $resolved.PSIsContainer -and
            -not $options.directory
        ) {
            $directories.Add($resolved)
        }
        else {
            $files.Add($resolved)
        }
    }

    $groups = [System.Collections.Generic.List[object]]::new()

    if ($options.directory) {
        $items = @($files)

        if ($directories.Count -gt 0) {
            $items += @($directories)
        }

        # @() wrapper: a bare 'return $items' unwraps single-element
        # arrays, leaving a FileSystemInfo with no .Count under
        # Set-StrictMode (e.g. 'ls -d <one-path>').
        $items = @(
            get-ls-sorted-items `
                -items $items `
                -options $options
        )

        if ($items.Count -gt 0) {
            $groups.Add(
                [pscustomobject]@{
                    header = $null
                    items  = @($items)
                }
            )
        }

        return $groups
    }

    if ($files.Count -gt 0) {
        $sortedFiles = get-ls-sorted-items `
            -items @($files) `
            -options $options

        $groups.Add(
            [pscustomobject]@{
                header = $null
                items  = @($sortedFiles)
            }
        )
    }

    foreach ($directory in $directories) {
        $items = get-ls-directory-items `
            -directory $directory `
            -options $options

        if ($options.recursive) {
            $groups.Add(
                [pscustomobject]@{
                    header = "$($directory.FullName):"
                    items  = @($items)
                }
            )

            get-ls-recursive-groups `
                -directory $directory `
                -options $options `
                -groups $groups
        }
        else {
            $header = $null

            if ($paths.Count -gt 1) {
                $header = "$($directory.FullName):"
            }

            $groups.Add(
                [pscustomobject]@{
                    header = $header
                    items  = @($items)
                }
            )
        }
    }

    return $groups
}


function get-ls-recursive-groups {
    param(
        [System.IO.DirectoryInfo]
        $directory,

        [pscustomobject]
        $options,

        [System.Collections.Generic.List[object]]
        $groups
    )

    try {
        $children = @(
            Get-ChildItem `
                -LiteralPath $directory.FullName `
                -Directory `
                -Force `
                -ErrorAction Stop
        )
    }
    catch {
        return
    }

    if (-not $options.all) {
        $children = @(
            $children |
                Where-Object {
                    -not (test-ls-hidden -item $_)
                }
        )
    }

    $children = get-ls-sorted-items `
        -items $children `
        -options $options

    # GNU ls -R: never descend into reparse points found during
    # recursion (only an explicitly given path is followed). Legacy
    # junctions such as 'Local Settings' deny listing anyway, so
    # descending only spams access-denied errors and risks loops.
    $children = @(
        $children |
            Where-Object {
                -not (test-ls-reparse-point -item $_)
            }
    )

    foreach ($child in $children) {
        $items = get-ls-directory-items `
            -directory $child `
            -options $options

        $groups.Add(
            [pscustomobject]@{
                header = "$($child.FullName):"
                items  = @($items)
            }
        )

        get-ls-recursive-groups `
            -directory $child `
            -options $options `
            -groups $groups
    }
}