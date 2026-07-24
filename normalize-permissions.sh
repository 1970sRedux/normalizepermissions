#!/usr/bin/env bash
#
# normalize-permissions.sh — audit and fix accidentally-executable files
# after copying a project between macOS, Linux, and USB/exFAT drives.
#
# Why this exists:
#   FAT32/exFAT USB drives have no Unix permission bits, so mounting drivers
#   often invent them — commonly making everything executable. macOS's own
#   permission model is looser about the exec bit than Linux, so files can
#   carry a meaningless-on-Mac exec bit that becomes meaningful (and
#   dangerous to build tools) once they land on Linux. This tool finds and
#   optionally strips those accidental bits, while leaving real executables
#   (scripts with a shebang, ELF binaries, things in bin/ dirs) alone.
#
# Usage:
#   ./normalize-permissions.sh [path]              # audit only (default: .)
#   ./normalize-permissions.sh --fix [path]        # strip suspicious exec bits
#   ./normalize-permissions.sh --fix --yes [path]  # fix without confirmation
#   ./normalize-permissions.sh --clean-appledouble [path]  # also remove ._* files
#
# Exit codes:
#   0 = clean (or fixed)
#   1 = suspicious files found (audit mode)
#   2 = usage error

set -euo pipefail

TARGET="."
FIX=0
ASSUME_YES=0
CLEAN_APPLEDOUBLE=0

usage() {
    grep '^#' "$0" | sed '1d;s/^# \{0,1\}//'
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --fix) FIX=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --clean-appledouble) CLEAN_APPLEDOUBLE=1 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *) TARGET="$1" ;;
    esac
    shift
done

if [ ! -d "$TARGET" ]; then
    echo "Error: '$TARGET' is not a directory." >&2
    exit 2
fi

# Heuristics for "this SHOULD be executable, leave it alone":
#   - has a shebang (#!...) as its first line
#   - is a recognized binary/executable format per `file`
#   - lives in a directory conventionally full of executables (bin/, .git/hooks/)
#   - is itself a directory (execute bit on dirs means "traversable", unrelated concern)
is_legitimately_executable() {
    local f="$1"

    case "$f" in
        */bin/*|*/.git/hooks/*|*/sbin/*) return 0 ;;
    esac

    # Shebang check
    if head -c 2 "$f" 2>/dev/null | grep -q '^#!'; then
        return 0
    fi

    # Binary/script format check via `file`, if available
    if command -v file >/dev/null 2>&1; then
        local desc
        desc="$(file -b "$f" 2>/dev/null || true)"
        case "$desc" in
            *ELF*|*Mach-O*|*"shell script"*|*executable*|*script*) return 0 ;;
        esac
    fi

    return 1
}

echo "Scanning: $TARGET"
echo

mapfile -t exec_files < <(find "$TARGET" -type f -perm -u+x 2>/dev/null)

suspicious=()
for f in "${exec_files[@]}"; do
    if ! is_legitimately_executable "$f"; then
        suspicious+=("$f")
    fi
done

if [ "${#suspicious[@]}" -eq 0 ]; then
    echo "No suspicious executable bits found (${#exec_files[@]} legitimate executables checked)."
else
    echo "Found ${#suspicious[@]} file(s) marked executable with no apparent reason:"
    echo
    for f in "${suspicious[@]}"; do
        kind="unknown"
        if command -v file >/dev/null 2>&1; then
            kind="$(file -b "$f" 2>/dev/null || echo unknown)"
        fi
        printf '  %s\n      -> %s\n' "$f" "$kind"
    done
    echo
fi

if [ "$CLEAN_APPLEDOUBLE" -eq 1 ]; then
    mapfile -t appledouble < <(find "$TARGET" -type f -name '._*' 2>/dev/null)
    mapfile -t dsstore < <(find "$TARGET" -type f -name '.DS_Store' 2>/dev/null)
    ad_total=$(( ${#appledouble[@]} + ${#dsstore[@]} ))
    if [ "$ad_total" -gt 0 ]; then
        echo "Found $ad_total macOS metadata file(s) (._* AppleDouble / .DS_Store):"
        for f in "${appledouble[@]}" "${dsstore[@]}"; do
            [ -n "$f" ] && echo "  $f"
        done
        echo
    fi
fi

if [ "$FIX" -eq 0 ]; then
    if [ "${#suspicious[@]}" -gt 0 ]; then
        echo "Audit mode only — no changes made. Re-run with --fix to strip these bits."
        exit 1
    fi
    exit 0
fi

# --fix mode from here
if [ "${#suspicious[@]}" -eq 0 ] && [ "$CLEAN_APPLEDOUBLE" -eq 0 -o "${ad_total:-0}" -eq 0 ]; then
    echo "Nothing to fix."
    exit 0
fi

if [ "$ASSUME_YES" -eq 0 ]; then
    read -r -p "Proceed with fixing the above? [y/N] " reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted, no changes made."; exit 1 ;;
    esac
fi

for f in "${suspicious[@]}"; do
    chmod a-x -- "$f"
    echo "  stripped exec bit: $f"
done

if [ "$CLEAN_APPLEDOUBLE" -eq 1 ] && [ "${ad_total:-0}" -gt 0 ]; then
    for f in "${appledouble[@]}" "${dsstore[@]}"; do
        [ -n "$f" ] && rm -f -- "$f" && echo "  removed: $f"
    done
fi

echo
echo "Done."
