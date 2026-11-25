#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Show freshness of the local Andromede ecosystem clones and their doc entry points.
# Usage: ecosystem_status.sh [--fetch] [ROOT]
#   --fetch  run `git fetch` (read-only for the working tree) before computing commits behind origin's default branch
#   ROOT     directory holding the clones (default: $ANDROMEDE_ROOT or the current directory)
# Runs on Linux, macOS and Windows (Git Bash / MSYS2 / Cygwin / WSL). Native PowerShell: ecosystem_status.ps1.
# Only bash and git are required, so it behaves the same whatever coreutils the platform ships.
set -u

FETCH=0
if [ "${1:-}" = "--fetch" ]; then FETCH=1; shift; fi
ROOT="${1:-${ANDROMEDE_ROOT:-$PWD}}"

command -v git >/dev/null 2>&1 || { echo "git not found in PATH" >&2; exit 1; }

# A Windows-style ROOT (C:\dev or C:/dev, e.g. from a Windows ANDROMEDE_ROOT) is converted to the shell's own form.
case "$ROOT" in
  [A-Za-z]:[\\/]*|[A-Za-z]:)
    if command -v cygpath >/dev/null 2>&1; then ROOT=$(cygpath -u "$ROOT")
    elif command -v wslpath >/dev/null 2>&1; then ROOT=$(wslpath -u "$ROOT")
    fi ;;
esac

REPOS="GEMS GemsPy GEMS-ViewsBuilder Antares_Simulator antares-xpansion antares_craft AntaREST antares-launcher antares-doc antares-datamanager-front antares-datamanager-back antares-datamanager-generator AntaresLegacyModels-to-GEMS-Converter PyPSA-to-GEMS-Converter"

# Count output lines in pure bash (no `wc`, whose padding differs between platforms).
count_lines() { local n=0 line; while IFS= read -r line; do [ -n "$line" ] && n=$((n + 1)); done; echo "$n"; }

printf '%-38s %-26s %-11s %-8s %-6s %s\n' REPO BRANCH LAST_COMMIT BEHIND DIRTY DOCS
for r in $REPOS; do
  d="$ROOT/$r"
  # -e, not -d: .git is a file in worktrees and submodules.
  if [ ! -e "$d/.git" ]; then
    printf '%-38s %s\n' "$r" "NOT CLONED -> git clone https://github.com/AntaresSimulatorTeam/$r.git $d"
    continue
  fi
  branch=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
  last=$(git -C "$d" log -1 --format=%cs 2>/dev/null)
  [ $FETCH -eq 1 ] && git -C "$d" fetch --quiet origin 2>/dev/null
  # "behind" is measured against the remote DEFAULT branch (origin/HEAD), not the checked-out branch's upstream,
  # so a clone sitting on a feature branch is still reported correctly and flagged with a leading '*'.
  default=$(git -C "$d" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  behind="-"
  if [ -n "$default" ]; then
    behind=$(git -C "$d" rev-list --count "HEAD..$default" 2>/dev/null)
    [ "origin/$branch" != "$default" ] && branch="*$branch"
  fi
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | count_lines)
  # Markdown files tracked under docs/ or doc/ (git pathspec '*' also matches subfolders); avoids `find`,
  # which resolves to the unrelated find.exe on Windows when System32 comes first in PATH.
  docs=""
  for p in docs doc; do
    [ -d "$d/$p" ] && docs="$p/ ($(git -C "$d" ls-files -- "$p/*.md" 2>/dev/null | count_lines) md)"
  done
  printf '%-38s %-26s %-11s %-8s %-6s %s\n' "$r" "$branch" "$last" "$behind" "$dirty" "${docs:-none}"
done
echo
echo "'*' = not on the remote default branch: read files with 'git -C <repo> show <default>:<path>' and say so."
echo "BEHIND = commits on the remote default branch missing from HEAD (run with --fetch for fresh numbers)."
