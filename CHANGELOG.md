# Changelog

All notable changes to ls-plus are documented here, newest first.
Versioning follows SemVer; ModuleVersion in ls-plus.psd1 is the
source of truth.

## [0.2.0] - 2026-09-22

### Added

- Permission markers attached without spaces in ^+! order:
  ^ for Hidden or System attributes, + for effectively granted
  rare rights (0x10, 0x40), ! for non-inherited rules targeting
  the current user.
- Data-handle flags (rwxa) require Synchronize.

### Changed

- Deny-restricted entries now show dark rwxa instead of data
  bits that could never open a handle.

## [0.1.0]

First functional release of the ls command.

### Added

- ls entry function with Linux-style short and long options
  (-aAlhtSR1dF, --acl, --help, --).
- Wide, long, one-per-line and ACL output formats.
- Effective-access permission string (rwxdap os) evaluated with
  pure managed ACL matching for the current user.
- Linux-default sorting (time/size descending, -r reverses).
- Human-readable sizes without spaces (100B, 2.9K).
- Reparse-point links shown as l with link -> target pointers;
  -R never descends into them.
- Case-sensitive short-option parsing (-r and -R are distinct).
- Effective write honors the ReadOnly attribute (files only).

### Notes

- Testing requires removing the built-in alias first:
  Remove-Item Alias:\ls -Force, then Import-Module.
- samples/ fixtures are excluded from this release.

## [0.0.0]

### Added

- Module manifest only (ls-plus.psd1 at v0.0.0). No functionality.
