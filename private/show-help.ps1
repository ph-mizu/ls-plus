# SPDX-License-Identifier: LicenseRef-PHMZ-NCRL-0.1
# Copyright (c) 2026 PHMZ

function show-ls-help {
    Write-Output @'
Usage:
  ls [OPTIONS] [PATH...]

Options:
  -a, --all              Include hidden files
  -A, --almost-all       Include hidden files, excluding . and ..
  -l, --long             Use long listing format
  -h, --human-readable   Print human-readable file sizes
  -t, --time             Sort by modification time
  -S, --size             Sort by file size
  -n, --name             Sort by name
  -r, --reverse          Reverse sort order
  -R, --recursive        List directories recursively
  -1, --one              List one item per line
  -d, --directory        List directories themselves
  -F, --classify         Append type indicators to file names
      --acl              Show Windows ACL information
      --help             Display this help message

Type indicators:
  /                      Directory
  @                      Symbolic link
  *                      Executable file

Owner permission flags (effective access for the current user):
  r                      Read (requires Synchronize)
  w                      Write (requires Synchronize and no ReadOnly flag)
  x                      Execute (requires Synchronize)
  d                      Delete
  a                      Append (requires Synchronize)
  p                      Read or change permissions
  o                      Take ownership
  s                      Synchronize (without it no handle opens)

Permission markers (attached, no spaces, order +^!):
  ^                      Hidden or System attribute set
  +                      Rights deviate from standard bundles (targeting Deny, incomplete bundle, rare 0x40)
  !                      A non-inherited rule targets the current user

Unmapped rights (see --acl for details):
  0x8 / 0x10             Read/write extended attributes (rarely used)
  0x40                   Delete subdirectories and files (dirs only)
  0x80                   Read attributes (implied by r)
  0x100                  Write attributes (implied by write access)

Examples:
  ls
  ls -lahtr
  ls -l -a -h
  ls -R /path
  ls --acl file.txt
'@
}