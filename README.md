normalize-permissions.sh

Fix Permissions For Copied Files Between MacOS, Linux and USB exFAT drives

normalize-permissions.sh audits and fixes files after copying a project between macOS, Linux, and USB/exFAT drives.

FAT32/exFAT USB drives have no Unix permission bits, so mounting drivers often invent them — commonly making everything executable. macOS's own permission model is looser about the exec bit than Linux, so files can carry a meaningless-on-Mac exec bit that becomes meaningful (and dangerous to build tools) once they land on Linux. This tool finds and optionally strips those accidental bits, while leaving real executables (scripts with a shebang, ELF binaries, things in bin/ dirs etc) alone.

You can also use it to remove "apple double" files.

How to use:
   ./normalize-permissions.sh [path]               audit only (default: .)
   
   ./normalize-permissions.sh --fix [path]         strip suspicious exec bits
   
   ./normalize-permissions.sh --fix --yes [path]   fix without confirmation
   
   ./normalize-permissions.sh --clean-appledouble [path]   also remove ._* files
   

 Exit codes:
   0 = clean (or fixed)
   1 = suspicious files found (audit mode)
   2 = usage error

   Exit code 2 is usually a syntax or path error.
