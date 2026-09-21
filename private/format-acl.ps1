# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function format-ls-acl {
    param(
        [object[]]
        $groups,

        [pscustomobject]
        $options
    )

    foreach ($group in $groups) {
        foreach ($item in $group.items) {
            Write-Output "[$($item.FullName)]"

            try {
                $acl = Get-Acl `
                    -LiteralPath $item.FullName `
                    -ErrorAction Stop
            }
            catch {
                Write-Output "error: $($_.Exception.Message)"
                continue
            }

            $permission = get-ls-permission-string -item $item
            $type = $permission.Substring(0, 1)
            $ownerRights = $permission.Substring(1)

            Write-Output "Type:        $type"
            Write-Output "OwnerRights: $ownerRights"
            Write-Output "Owner:       $($acl.Owner)"
            Write-Output "Path:        $($item.FullName)"
            Write-Output ""

            Write-Output "ACL:"

            foreach ($rule in $acl.Access) {
                Write-Output (
                    '{0} {1} {2} inherit={3} propagate={4} inherited={5}' -f `
                        $rule.AccessControlType,
                        $rule.IdentityReference.Value,
                        $rule.FileSystemRights,
                        $rule.InheritanceFlags,
                        $rule.PropagationFlags,
                        $rule.IsInherited
                )
            }
        }
    }
}