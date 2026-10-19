#!/usr/bin/env bash
# Say whether the distilled rules file still matches the docs it was made from.
# The rules file's first lines stamp each source with its git blob hash:
#   <!-- source: CLAUDE.md a1b2c3d... -->
#
# Usage: rules_check.sh <rules.md> [--stamp <source>...]
#   default   print "fresh", or "stale:" plus one line per changed/missing source; exit 0 either way
#   --stamp   print the stamp lines for the given sources (setup pastes them into the header)
# Paths are relative to the repo root; run from anywhere inside the repo.
set -euo pipefail

usage() { sed -n '2,10p' "$0" >&2; exit 2; }
[ $# -ge 1 ] || usage
root=$(git rev-parse --show-toplevel)

if [ "$1" = "--stamp" ]; then
  shift
  for s in "$@"; do
    [ -f "$root/$s" ] || { echo "error: $s not found" >&2; exit 1; }
    echo "<!-- source: $s $(git hash-object "$root/$s") -->"
  done
  exit 0
fi

rules="$1"; case "$rules" in /*) ;; *) rules="$root/$rules" ;; esac
[ -f "$rules" ] || { echo "missing: $rules"; exit 0; }

changed=""
while read -r _ _ src hash _; do
  if [ ! -f "$root/$src" ]; then changed+="  $src (deleted)"$'\n'
  elif [ "$(git hash-object "$root/$src")" != "$hash" ]; then changed+="  $src (changed)"$'\n'
  fi
done < <(grep -E '^<!-- source: ' "$rules")

if [ -z "$changed" ]; then echo "fresh"; else printf 'stale:\n%s' "$changed"; fi
