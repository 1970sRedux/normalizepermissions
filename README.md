# normalize-permissions.sh

> Audit and fix incorrect executable permissions after copying projects between **macOS**, **Linux**, and **USB (FAT32/exFAT)** drives.

## Overview

`normalize-permissions.sh` helps detect and correct accidental executable permissions that commonly appear when files are copied between different operating systems and removable drives.

FAT32 and exFAT filesystems do **not** store Unix permission bits. As a result, mounting drivers often assign synthetic permissions, sometimes marking every file as executable.

On macOS, this usually goes unnoticed because the executable bit is less strictly enforced. Once the same project is copied to Linux, however, those unintended permissions can interfere with build systems, packaging tools, version control, and security expectations.

This script audits your project for suspicious executable permissions and can automatically remove them while preserving legitimate executables.

## Features

* Audit projects for suspicious executable permissions
* Remove accidental executable bits
* Preserve legitimate executables, including:

  * Scripts with a shebang (`#!/...`)
  * ELF binaries
  * Files inside `bin/` directories
  * Other recognized executable files

*  Optionally remove AppleDouble (`._*`) files created by macOS
*  Works well when moving projects between macOS, Linux, and USB drives

## Usage

### Audit only (default)

```bash
./normalize-permissions.sh [path]
```

Scans the specified directory (or the current directory if omitted) and reports suspicious executable permissions without making changes.

### Fix suspicious permissions

```bash
./normalize-permissions.sh --fix [path]
```

Removes accidental executable bits after confirmation.

### Fix without confirmation

```bash
./normalize-permissions.sh --fix --yes [path]
```

Runs non-interactively and applies fixes immediately.

### Remove AppleDouble files

```bash
./normalize-permissions.sh --clean-appledouble [path]
```

Also removes macOS AppleDouble (`._*`) metadata files.

## Exit Codes

| Code | Meaning                                                   |
| ---- | --------------------------------------------------------- |
| `0`  | No issues found, or all issues were successfully fixed    |
| `1`  | Suspicious executable permissions were found (audit mode) |
| `2`  | Usage error (invalid arguments or path)                   |

> **Note:** Exit code `2` usually indicates a command syntax error or an invalid path.

## Why This Exists

Copying projects through FAT32 or exFAT media can silently introduce incorrect executable permissions because those filesystems lack native Unix permission support.

These permissions may appear harmless on macOS but can cause unexpected behavior on Linux, including:

* Files incorrectly treated as executables
* Build or packaging inconsistencies
* Repository permission noise
* Potential security concerns

`normalize-permissions.sh` provides a quick way to restore sensible permissions before committing code, building software, or deploying projects.
