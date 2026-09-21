# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function format-ls-long {
    param(
        [System.IO.FileSystemInfo[]]
        $items,

        [pscustomobject]
        $options
    )

    if ($items.Count -eq 0) {
        return
    }

    $rows = @()

    foreach ($item in $items) {
        $permission = get-ls-permission-string -item $item

        if ($item.PSIsContainer) {
            $size = '-'
        }
        else {
            $size = format-ls-size `
                -bytes $item.Length `
                -humanReadable:$options.humanReadable
        }

        $time = $item.LastWriteTime.ToString(
            'yyyy MMM dd HH:mm',
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $name = get-ls-display-name `
            -item $item `
            -classify:$options.classify

        # Linux-style link pointer: 'link -> target'.
        if (test-ls-reparse-point -item $item) {
            $linkTarget = get-ls-link-target -item $item

            if ($linkTarget) {
                $name = "$name -> $linkTarget"
            }
        }

        $rows += [pscustomobject]@{
            permission = $permission
            size       = $size
            time       = $time
            name       = $name
        }
    }

    $permissionWidth = (
        $rows |
            ForEach-Object { $_.permission.Length } |
            Measure-Object -Maximum
    ).Maximum

    $sizeWidth = (
        $rows |
            ForEach-Object { $_.size.Length } |
            Measure-Object -Maximum
    ).Maximum

    foreach ($row in $rows) {
        $permissionText = $row.permission.PadRight(
            $permissionWidth
        )

        $sizeText = $row.size.PadLeft(
            $sizeWidth
        )

        Write-Output (
            '{0} {1} {2} {3}' -f `
                $permissionText,
                $sizeText,
                $row.time,
                $row.name
        )
    }
}