# ls-plus

Compact Linux-style `ls` for Windows PowerShell 5.1.

## Requirements

- Windows PowerShell 5.1 or later. PowerShell 7 and
  cross-platform behavior remain unverified.
- The built-in `ls` alias takes precedence over functions,
  so it must be removed manually before importing:

```powershell
Remove-Item Alias:\ls -Force
Import-Module .\ls-plus.psd1
```

To make this permanent, put both lines in your `$PROFILE`
with the absolute module path, e.g.
`C:\Users\<you>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`:

```powershell
Remove-Item Alias:\ls -Force
Import-Module E:\ls-plus\ls-plus.psd1
```

## Usage

```powershell
ls [OPTIONS] [PATH...]
```

Output formats (default is wide multi-column):

| Flags | Format |
| ----- | ------ |
| (none) | Wide listing, sorted down columns |
| `-l`, `--long` | Long listing: permissions, size, time, name |
| `-1`, `--one` | One item per line |
| `--acl` | Raw Windows ACL rules per item |
| `-h`, `--human-readable` | Human sizes with `-l` (`100B`, `2.9K`) |
| `-F`, `--classify` | Append `/` `@` `*` type indicators |

Sorting (`-t` time, `-S` size, `-n` name, `-r` reverse;
time/size default newest/largest first):

```powershell
ls -la               # long + hidden files
ls -lhSt             # human sizes, largest first, then by time
ls -R C:\path        # recursive (never follows links)
ls -d Docs           # list the directory itself, not its contents
ls --acl file.txt    # inspect raw ACL rules
```

Run `ls --help` for the full option list. Supported short
options: `-aAlhtSRn1dF`; long options: `--all`,
`--almost-all`, `--long`, `--human-readable`, `--time`,
`--size`, `--name`, `--reverse`, `--recursive`, `--one`,
`--directory`, `--classify`, `--acl`, `--help`.

## Permission String

Long format shows effective access for the current user as
`rwxdap` plus ownership (`o`) and synchronize (`s`) flags:

| Flag | Meaning                                        |
| ---- | ---------------------------------------------- |
| r    | Read (requires Synchronize)                    |
| w    | Write (requires Synchronize, no ReadOnly flag) |
| x    | Execute (requires Synchronize)                 |
| d    | Delete                                         |
| a    | Append (requires Synchronize)                  |
| p    | Read or change permissions                     |
| o    | Take ownership                                 |
| s    | Synchronize (without it no handle opens)       |

Markers are attached without spaces in `+^!` order:

| Marker | Meaning                                                      |
| ------ | ------------------------------------------------------------ |
| +      | Rights deviate from standard bundles (targeting Deny, incomplete bundle, `0x40`) |
| ^      | Hidden or System attribute set                               |
| !      | A non-inherited rule targets current user                    |

Type indicators with `-F`: `/` directory, `@` link,
`*` executable. Links show `name -> target` in long format.

## Samples

A fresh clone contains no `samples/` directory: fixtures are
generated local state, never committed. Expand them with:

```powershell
.\Reset-SamplePermissions.ps1
```

The script creates every fixture from scratch and applies the
Windows ACLs, attribute flags, and links that git cannot
preserve. Re-run it any time to repair demo state. Note:
symlink creation needs admin or Developer Mode and is skipped
with a warning otherwise.

| Fixture | Purpose | Expected markers |
| ------- | ------- | ---------------- |
| `full.txt` | Full-access baseline | none |
| `granted.txt` | Explicit grant for current user | `!` |
| `hidden-note.txt` | Hidden flag, visible only with `-a` | `^` |
| `locked/` + `secret.txt` | Deny-listed directory; list/open errors | `+!`, entry unreadable |
| `readonly-attr.txt` | ReadOnly attribute: readable, `w` dark | none (honest `-r-x`) |
| `sized-3k.txt` | Human-readable size demo | `2.9K` with `-h` |
| `sub/` + `inner.txt` | Normal subdirectory control group | none |
| `tool.ps1` | Executable mark | `*` with `-F` |
| `app-link` | Junction to `sub/` (`->` pointer, `-R` lists but never descends) | `l` type |

## Versioning

SemVer on `ModuleVersion` in `ls-plus.psd1`; changes are
recorded in `CHANGELOG.md`.

## License

PHMZ Non-Commercial Reciprocal License v0.1 -- custom
source-available, non-commercial, strong reciprocal terms.
Not OSI-approved. See `LICENSE` for the full text.
