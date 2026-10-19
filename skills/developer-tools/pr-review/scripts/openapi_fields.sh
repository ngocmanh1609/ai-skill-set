#!/usr/bin/env bash
# Check whether API paths, schemas, or fields a PR's DTOs use exist in the OpenAPI spec.
# Answers "do the fields this PR maps actually exist?" without reading a 7k-line YAML.
#
# Usage: openapi_fields.sh <openapi_url> <term>...
#   term forms:
#     /api/v1/orders/{id}              path exists?
#     order_response                   schema exists?
#     partially_delivered              which schemas/paths define this field?
#     order_response.discount_total    is this field defined inside that schema?
#
# The URL may carry basic-auth credentials; it is never printed.
# The spec is cached for 60 minutes (API docs change during a sprint, but not minute to minute).
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <openapi_url> <term>..." >&2
  exit 2
fi

url="$1"; shift
cache_dir="${TMPDIR:-/tmp}/pr-review"
cache="$cache_dir/openapi.yaml"
mkdir -p "$cache_dir"

if [ ! -s "$cache" ] || [ -z "$(find "$cache" -mmin -60 2>/dev/null)" ]; then
  if ! curl -fsS "$url" -o "$cache.tmp"; then
    echo "error: could not download the OpenAPI spec (check api_contract in .claude/pr-review.yml)" >&2
    rm -f "$cache.tmp"
    exit 1
  fi
  mv "$cache.tmp" "$cache"
fi

for term in "$@"; do
  awk -v term="$term" '
    # Track where we are: top-level section, then a path (2-space indent under paths:)
    # or a schema (4-space indent under components:).
    # Keys may be quoted ("/api/v1/orders/{id}":), so quotes are stripped before comparing.
    /^[A-Za-z]/ { top = $1; ctx = ""; next }
    top == "paths:" && /^  ["\047]?\// {
      ctx = $1; gsub(/["\047]/, "", ctx); sub(/:$/, "", ctx)
      if (ctx == term) path_hit = 1
      next
    }
    top == "components:" && /^    ["\047]?[A-Za-z0-9_]+["\047]?:[[:space:]]*$/ {
      ctx = $1; gsub(/["\047]/, "", ctx); sub(/:$/, "", ctx); schemas[ctx] = 1; next
    }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      gsub(/["\047]/, "", line)
      if (index(term, ".") && substr(term, 1, 1) != "/") {
        split(term, t, ".")
        if (ctx == t[1] && line ~ ("^" t[2] ":")) dotted_hit = 1
      } else if (line ~ ("^" term ":") && ctx != "") {
        where[ctx] = 1
      }
    }
    END {
      if (substr(term, 1, 1) == "/") {
        print term ": " (path_hit ? "path FOUND" : "path NOT FOUND")
      } else if (index(term, ".")) {
        split(term, t, ".")
        if (!(t[1] in schemas)) print term ": schema " t[1] " NOT FOUND"
        else print term ": " (dotted_hit ? "FOUND" : "NOT FOUND in " t[1])
      } else {
        s = ""
        for (k in where) s = s (s ? ", " : "") k
        if (term in schemas) s = "schema FOUND" (s ? "; also a field in: " s : "")
        print term ": " (s ? s : "NOT FOUND")
      }
    }
  ' "$cache"
done
