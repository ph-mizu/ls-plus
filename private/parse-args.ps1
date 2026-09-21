function convert-to-ls-options {
    param(
        [object[]]
        $arguments
    )

    $options = [ordered]@{
        all            = $false
        almostAll      = $false
        long           = $false
        humanReadable  = $false

        sort           = 'name'
        reverse        = $false

        recursive      = $false
        one            = $false
        directory      = $false
        classify       = $false
        acl            = $false
        help           = $false

        paths          = [System.Collections.Generic.List[string]]::new()
    }

    $endOfOptions = $false

    foreach ($argument in @($arguments)) {
        $token = [string]$argument

        if ($endOfOptions) {
            $options.paths.Add($token)
            continue
        }

        if ($token -eq '--') {
            $endOfOptions = $true
            continue
        }

        if ($token.StartsWith('--')) {
            switch ($token) {
                '--all' {
                    $options.all = $true
                    continue
                }

                '--almost-all' {
                    $options.almostAll = $true
                    continue
                }

                '--long' {
                    $options.long = $true
                    continue
                }

                '--human-readable' {
                    $options.humanReadable = $true
                    continue
                }

                '--time' {
                    $options.sort = 'time'
                    continue
                }

                '--size' {
                    $options.sort = 'size'
                    continue
                }

                '--name' {
                    $options.sort = 'name'
                    continue
                }

                '--reverse' {
                    $options.reverse = $true
                    continue
                }

                '--recursive' {
                    $options.recursive = $true
                    continue
                }

                '--one' {
                    $options.one = $true
                    continue
                }

                '--directory' {
                    $options.directory = $true
                    continue
                }

                '--classify' {
                    $options.classify = $true
                    continue
                }

                '--acl' {
                    $options.acl = $true
                    continue
                }
                '--help' {
    		    $options.help = $true
                    continue
                }

                default {
                    throw "ls: unknown option '$token'"
                }
            }

            continue
        }

        if (
            $token.StartsWith('-') -and
            $token.Length -gt 1
        ) {
            $shortOptions = $token.Substring(1)

            foreach ($character in $shortOptions.ToCharArray()) {
                # Short-option parsing is case-sensitive: -r is defined
                # as reverse and -R as recursive; the two flags are
                # distinct, as are -a and -A.
                switch -CaseSensitive ($character) {
                    'a' {
                        $options.all = $true
                    }

                    'A' {
                        $options.almostAll = $true
                    }

                    'l' {
                        $options.long = $true
                    }

                    'h' {
                        $options.humanReadable = $true
                    }

                    't' {
                        $options.sort = 'time'
                    }

                    'S' {
                        $options.sort = 'size'
                    }

                    'n' {
                        $options.sort = 'name'
                    }

                    'r' {
                        $options.reverse = $true
                    }

                    'R' {
                        $options.recursive = $true
                    }

                    '1' {
                        $options.one = $true
                    }

                    'd' {
                        $options.directory = $true
                    }

                    'F' {
                        $options.classify = $true
                    }

                    default {
                        throw "ls: unknown option '-$character'"
                    }
                }
            }

            continue
        }

        $options.paths.Add($token)
    }

    # -a takes precedence over -A.
    if ($options.all) {
        $options.almostAll = $false
    }

    [pscustomobject]$options
}