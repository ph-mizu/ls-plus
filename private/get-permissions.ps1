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

        $sidString = get-ls-rule-sid-string -identityReference $rule.IdentityReference

        if ($null -eq $sidString) {
            continue
        }

        if (-not $info.Sids.Contains($sidString)) {
            continue
        }

        if (([int]$rule.FileSystemRights -band $mask) -ne 0) {
            return $false
        }
    }

    foreach ($rule in $rules) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }

        $sidString = get-ls-rule-sid-string -identityReference $rule.IdentityReference

        if ($null -eq $sidString) {
            continue
        }

        if (-not $info.Sids.Contains($sidString)) {
            continue
        }

        if (([int]$rule.FileSystemRights -band $mask) -ne 0) {
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

    return "$type$read$write$execute$delete$append$permissionControl$ownership$synchronize"
}
