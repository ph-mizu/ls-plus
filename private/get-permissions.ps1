# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function initialize-ls-access-check {
    # Access evaluation is defined as pure managed ACL matching
    # and requires no initialization.
    return
}


function new-ls-permissions-object {
    return [pscustomobject]@{
        read        = $false
        write       = $false
        execute     = $false
        delete      = $false
        append      = $false
        permissions = $false
        ownership   = $false
        synchronize = $false
        plus        = $false
        bang        = $false
    }
}


# The current user and group SID set is resolved once per session
# and shared by all per-file evaluations.
$script:LsPlusSidCache = $null
$script:LsPlusSidTranslateCache = @{}


function get-ls-current-sids {
    if ($null -ne $script:LsPlusSidCache) {
        return $script:LsPlusSidCache
    }

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    if ($null -eq $identity) {
        $script:LsPlusSidCache = @{
            UserSid = $null
            Sids    = (New-Object System.Collections.Generic.HashSet[string])
        }
        return $script:LsPlusSidCache
    }

    $sids = New-Object System.Collections.Generic.HashSet[string]
    $userSid = $identity.User.Value
    [void]$sids.Add($userSid)

    foreach ($group in $identity.Groups) {
        try {
            [void]$sids.Add($group.Value)
        }
        catch {
        }
    }

    $script:LsPlusSidCache = @{
        UserSid = $userSid
        Sids    = $sids
    }

    return $script:LsPlusSidCache
}


function get-ls-rule-sid-string {
    param(
        [System.Security.Principal.IdentityReference]
        $identityReference
    )

    $key = $identityReference.Value

    if ($script:LsPlusSidTranslateCache.ContainsKey($key)) {
        return $script:LsPlusSidTranslateCache[$key]
    }

    $sidString = $null

    try {
        if ($identityReference -is [System.Security.Principal.SecurityIdentifier]) {
            $sidString = $identityReference.Value
        }
        else {
            $sidString = (
                $identityReference.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                )
            ).Value
        }
    }
    catch {
        $sidString = $null
    }

    $script:LsPlusSidTranslateCache[$key] = $sidString

    return $sidString
}


function expand-ls-generic-rights {
    param(
        [int]
        $rights
    )

    # Generic rights are stored unexpanded on directory ACEs
    # (e.g. 0x10000000). The generic-to-specific mapping is
    # identical for files and directories (ListDirectory shares
    # its bit with ReadData, Traverse with Execute), so one
    # table covers both. Accumulation uses long to keep the
    # high generic bits intact.
    $expanded = [long]$rights

    if (($expanded -band 0x80000000L) -ne 0) {
        $expanded = $expanded -bor 0x120089L
    }

    if (($expanded -band 0x40000000L) -ne 0) {
        $expanded = $expanded -bor 0x120116L
    }

    if (($expanded -band 0x20000000L) -ne 0) {
        $expanded = $expanded -bor 0x1200A0L
    }

    if (($expanded -band 0x10000000L) -ne 0) {
        $expanded = $expanded -bor 0x1F01FFL
    }

    return $expanded
}


function test-ls-inherit-only {
    param(
        [System.Security.AccessControl.AuthorizationRule]
        $rule
    )

    # InheritOnly ACEs target child objects, never this object.
    return (
        ($rule.PropagationFlags -band
         [System.Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0
    )
}


function test-ls-right {
    param(
        [System.Security.AccessControl.FileSystemSecurity]
        $acl,

        [int]
        $mask
    )

    $info = get-ls-current-sids

    if ($null -eq $info.UserSid) {
        return $false
    }

    $rules = @($acl.Access)

    if ($rules.Count -eq 0) {
        # Null DACL means everyone has full access.
        return $true
    }

    # Deny takes precedence over Allow.
    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Deny) {
            continue
        }

        if (test-ls-inherit-only -rule $rule) {
            continue
        }

        $sidString = get-ls-rule-sid-string -identityReference $rule.IdentityReference

        if ($null -eq $sidString) {
            continue
        }

        if (-not $info.Sids.Contains($sidString)) {
            continue
        }

        $effective = expand-ls-generic-rights `
            -rights ([int]$rule.FileSystemRights)

        if (($effective -band $mask) -ne 0) {
            return $false
        }
    }

    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }

        if (test-ls-inherit-only -rule $rule) {
            continue
        }

        $sidString = get-ls-rule-sid-string -identityReference $rule.IdentityReference

        if ($null -eq $sidString) {
            continue
        }

        if (-not $info.Sids.Contains($sidString)) {
            continue
        }

        $effective = expand-ls-generic-rights `
            -rights ([int]$rule.FileSystemRights)

        if (($effective -band $mask) -ne 0) {
            return $true
        }
    }

    return $false
}


function test-ls-sid-applies-to-me {
    param(
        [System.Security.Principal.IdentityReference]
        $identityReference
    )

    $info = get-ls-current-sids

    if ($null -eq $info.UserSid) {
        return $false
    }

    $sidString = get-ls-rule-sid-string `
        -identityReference $identityReference

    if ($null -eq $sidString) {
        return $false
    }

    return $info.Sids.Contains($sidString)
}


function test-ls-anomaly {
    param(
        [System.Security.AccessControl.FileSystemSecurity]
        $acl
    )

    # '+' marker: the effective rights deviate from every standard
    # bundle. A Deny targeting the current user is itself anomalous,
    # as allow-based DACLs rarely contain one. A companion bit is
    # defined as present exactly when its carrier is present:
    # WriteEA 0x10 and WriteAttrs 0x100 accompany WriteData 0x2;
    # ReadEA 0x8 and ReadAttrs 0x80 accompany ReadData 0x1. A carrier
    # without its companion forms an incomplete bundle.
    # DeleteSubdirectoriesAndFiles 0x40 has no standard carrier
    # outside FullControl, so any effective grant is anomalous.
    foreach ($rule in @($acl.Access)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Deny) {
            continue
        }

        if (test-ls-inherit-only -rule $rule) {
            continue
        }

        if (test-ls-sid-applies-to-me `
                -identityReference $rule.IdentityReference) {
            return $true
        }
    }

    if (test-ls-right -acl $acl -mask 0x2) {
        if (-not (test-ls-right -acl $acl -mask 0x10)) {
            return $true
        }

        if (-not (test-ls-right -acl $acl -mask 0x100)) {
            return $true
        }
    }

    if (test-ls-right -acl $acl -mask 0x1) {
        if (-not (test-ls-right -acl $acl -mask 0x8)) {
            return $true
        }

        if (-not (test-ls-right -acl $acl -mask 0x80)) {
            return $true
        }
    }

    return (test-ls-right -acl $acl -mask 0x40)
}


function test-ls-explicit-rule {
    param(
        [System.Security.AccessControl.FileSystemSecurity]
        $acl
    )

    # '!' marker: a non-inherited ACE (Allow or Deny) applies to
    # the current user.
    foreach ($rule in @($acl.Access)) {
        if ($rule.IsInherited) {
            continue
        }

        if (test-ls-inherit-only -rule $rule) {
            continue
        }

        if (test-ls-sid-applies-to-me `
                -identityReference $rule.IdentityReference) {
            return $true
        }
    }

    return $false
}


function get-ls-owner-permissions {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]
        $item
    )

    $permissions = new-ls-permissions-object

    try {
        $acl = Get-Acl -LiteralPath $item.FullName -ErrorAction Stop
    }
    catch {
        Write-Verbose "ls: cannot get ACL '$($item.FullName)': $($_.Exception.Message)"
        return $permissions
    }

    try {
        # Single-bit file/dir rights. Same bit covers both
        # (ReadData/ListDirectory = 0x1, etc.).
        $permissions.read = test-ls-right -acl $acl -mask 0x1
        $permissions.write = test-ls-right -acl $acl -mask 0x2
        $permissions.append = test-ls-right -acl $acl -mask 0x4
        $permissions.execute = test-ls-right -acl $acl -mask 0x20
        $permissions.delete = test-ls-right -acl $acl -mask 0x10000

        $readControl = test-ls-right -acl $acl -mask 0x20000
        $writeDac = test-ls-right -acl $acl -mask 0x40000
        $permissions.permissions = ($readControl -or $writeDac)

        $permissions.ownership = test-ls-right -acl $acl -mask 0x80000
        $permissions.synchronize = test-ls-right -acl $acl -mask 0x100000

        # Effective write: the OS blocks writes to ReadOnly files no
        # matter what the ACL says. Directories are exempt, Windows
        # ignores ReadOnly on them.
        if (
            (-not $item.PSIsContainer) -and
            [bool](
                $item.Attributes -band
                [System.IO.FileAttributes]::ReadOnly
            )
        ) {
            $permissions.write = $false
        }

        # Data-handle operations require Synchronize: without it no
        # handle opens, so r/w/x/a stay dark however the data bits
        # read. Control operations (p/o) use the security API path
        # and are unaffected.
        if (-not $permissions.synchronize) {
            $permissions.read = $false
            $permissions.write = $false
            $permissions.execute = $false
            $permissions.append = $false
        }

        # '+' suffix: rights deviate from standard bundles.
        $permissions.plus = test-ls-anomaly -acl $acl

        # '!' suffix: a hand-made explicit rule targets the user.
        $permissions.bang = test-ls-explicit-rule -acl $acl

        # Owner implicitly holds READ_CONTROL | WRITE_DAC.
        try {
            $ownerRef = New-Object System.Security.Principal.NTAccount($acl.Owner)
            $ownerSid = (
                $ownerRef.Translate(
                    [System.Security.Principal.SecurityIdentifier]
                )
            ).Value

            $info = get-ls-current-sids

            if ($ownerSid -eq $info.UserSid) {
                $permissions.permissions = $true
            }
        }
        catch {
        }

        return $permissions
    }
    catch {
        Write-Verbose "ls: cannot evaluate ACL '$($item.FullName)': $($_.Exception.Message)"
        return $permissions
    }
}


function get-ls-permission-string {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]
        $item
    )

    $permissions = get-ls-owner-permissions -item $item

    if (test-ls-reparse-point -item $item) {
        $type = 'l'
    }
    elseif ($item.PSIsContainer) {
        $type = 'd'
    }
    else {
        $type = '-'
    }

    if ($permissions.read) {
        $read = 'r'
    }
    else {
        $read = '-'
    }

    if ($permissions.write) {
        $write = 'w'
    }
    else {
        $write = '-'
    }

    if ($permissions.execute) {
        $execute = 'x'
    }
    else {
        $execute = '-'
    }

    if ($permissions.delete) {
        $delete = 'd'
    }
    else {
        $delete = '-'
    }

    if ($permissions.append) {
        $append = 'a'
    }
    else {
        $append = '-'
    }

    if ($permissions.permissions) {
        $permissionControl = 'p'
    }
    else {
        $permissionControl = '-'
    }

    if ($permissions.ownership) {
        $ownership = 'o'
    }
    else {
        $ownership = '-'
    }

    if ($permissions.synchronize) {
        $synchronize = 's'
    }
    else {
        $synchronize = '-'
    }

    $base = "$type$read$write$execute$delete$append$permissionControl$ownership$synchronize"

    # Marker suffixes in fixed order +^!: rare rights, hidden
    # attribute, explicit rule. Tightly attached, no spaces.
    $suffix = ''

    if ($permissions.plus) {
        $suffix += '+'
    }

    if (test-ls-hidden -item $item) {
        $suffix += '^'
    }

    if ($permissions.bang) {
        $suffix += '!'
    }

    return $base + $suffix
}
