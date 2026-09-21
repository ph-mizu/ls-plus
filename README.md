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

## Usage

```powershell
ls [OPTIONS] [PATH...]
ls -la
ls -lh --time
ls -R /path
ls --acl file.txt
```

Run `ls --help` for the full option list. Supported short
options: `-aAlhtSR1dF`; long options: `--all`,
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

Markers are attached without spaces in `^+!` order:

| Marker | Meaning                                          |
| ------ | ------------------------------------------------ |
| ^      | Hidden or System attribute set                   |
| +      | Rare rights effectively granted (`0x10`, `0x40`) |
| !      | A non-inherited rule targets the current user    |

Type indicators with `-F`: `/` directory, `@` link,
`*` executable. Links show `name -> target` in long format.

## Samples

`samples/` holds permission fixtures (deny, explicit grant,
hidden, junction, sized file). Git cannot preserve Windows
ACLs, so re-apply the demo state after cloning:

```powershell
.\samples\Reset-SamplePermissions.ps1
```

## Versioning

SemVer on `ModuleVersion` in `ls-plus.psd1`; changes are
recorded in `CHANGELOG.md`.

## License

PHMZ Non-Commercial Reciprocal License v0.1 -- custom
source-available, non-commercial, strong reciprocal terms.
Not OSI-approved. See `LICENSE` for the full text.
