# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

Set-StrictMode -Version Latest

$privatePath = Join-Path $PSScriptRoot 'private'

Get-ChildItem `
    -LiteralPath $privatePath `
    -Filter '*.ps1' `
    -File |
    Sort-Object Name |
    ForEach-Object {
        . $_.FullName
}


function ls {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ValueFromRemainingArguments = $true
        )]
        [object[]]
        $arguments
    )

    # '-d' is a prefix of the common -Debug parameter, so PowerShell
    # binds 'ls -d ...' to -Debug instead of $arguments. The module
    # never uses Write-Debug, so treat it as the directory flag.
    if ($PSBoundParameters.ContainsKey('Debug')) {
        $arguments = @('-d') + @($arguments)
    }

    $options = convert-to-ls-options -arguments $arguments

    if ($options.help) {
        show-ls-help
        return
    }

    $groups = get-ls-item-groups `
        -paths $options.paths `
        -options $options

    if ($options.acl) {
        format-ls-acl `
            -groups $groups `
            -options $options

        return
    }

    foreach ($group in $groups) {
        if ($null -ne $group.header) {
            Write-Output $group.header
        }

        if ($options.long) {
            format-ls-long `
                -items $group.items `
                -options $options
        }
        elseif ($options.one) {
            format-ls-one `
                -items $group.items `
                -options $options
        }
        else {
            format-ls-wide `
                -items $group.items `
                -options $options
        }
    }
}


# Remove the built-in PowerShell ls alias so the module function takes precedence.
if (Test-Path Alias:\ls) {
    Remove-Item Alias:\ls -Force
}

Export-ModuleMember -Function ls