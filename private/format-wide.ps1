function format-ls-wide {
    param(
        [System.IO.FileSystemInfo[]]
        $items,

        [pscustomobject]
        $options
    )

    if ($items.Count -eq 0) {
        return
    }

    $names = @(
        foreach ($item in $items) {
            get-ls-display-name `
                -item $item `
                -classify:$options.classify
        }
    )

    $maxLength = 0

    foreach ($name in $names) {
        if ($name.Length -gt $maxLength) {
            $maxLength = $name.Length
        }
    }

    $columnGap = 2
    $cellWidth = $maxLength + $columnGap
    $terminalWidth = get-ls-terminal-width

    $columns = [math]::Floor(
        $terminalWidth / $cellWidth
    )

    if ($columns -lt 1) {
        $columns = 1
    }

    if ($columns -gt $names.Count) {
        $columns = $names.Count
    }

    $rows = [math]::Ceiling(
        $names.Count / $columns
    )

    for ($row = 0; $row -lt $rows; $row++) {
        $line = ''

        for ($column = 0; $column -lt $columns; $column++) {
            $index = $row + ($column * $rows)

            if ($index -ge $names.Count) {
                continue
            }

            $name = $names[$index]

            if ($column -lt ($columns - 1)) {
                $line += $name.PadRight($cellWidth)
            }
            else {
                $line += $name
            }
        }

        Write-Output $line.TrimEnd()
    }
}


function format-ls-one {
    param(
        [System.IO.FileSystemInfo[]]
        $items,

        [pscustomobject]
        $options
    )

    foreach ($item in $items) {
        Write-Output (
            get-ls-display-name `
                -item $item `
                -classify:$options.classify
        )
    }
}