# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

@{
    RootModule        = 'ls-plus.psm1'
    ModuleVersion     = '0.2.1'
    GUID              = '7b9f0d53-9b4d-4e72-9d2d-5a5a7b7f3d41'

    Author            = 'phmz'
    Description       = 'Linux-style ls for PowerShell.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('ls')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}