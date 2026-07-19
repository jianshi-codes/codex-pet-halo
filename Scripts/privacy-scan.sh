#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

scan_tracked_and_pending() {
    local label="$1"
    local pattern="$2"
    local excluded_glob="${3:-}"
    local excluded_path="${excluded_glob#!}"
    local files=()
    while IFS= read -r -d '' file; do
        if [[ -n "$excluded_glob" && "$file" == "$excluded_path" ]]; then
            continue
        fi
        files+=("$file")
    done < <(git ls-files --cached --others --exclude-standard -z)

    if [[ ${#files[@]} -eq 0 ]]; then
        return
    fi

    local scan_status=0
    grep -EIHn -- "$pattern" "${files[@]}" || scan_status=$?
    if [[ $scan_status -eq 0 ]]; then
        echo "error: privacy scan found $label" >&2
        exit 1
    fi
    if [[ $scan_status -ne 1 ]]; then
        echo "error: privacy scan could not inspect files for $label" >&2
        exit "$scan_status"
    fi
}

scan_tracked_and_pending "a user-specific absolute path" '/Users/[A-Za-z0-9._-]+/'
scan_tracked_and_pending "a possible credential" '(gh[opusr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|Bearer[[:space:]]+[A-Za-z0-9._~+/=-]{20,})'
scan_tracked_and_pending "a possible authorization header" '(Authorization|authorization):[[:space:]]*(Basic|Bearer)[[:space:]]+'
# M0 deliberately uses a synthetic email value to prove that identity data is redacted.
scan_tracked_and_pending "an email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' '!Tests/test_normalization.py'

echo "Privacy and absolute-path scans passed"
