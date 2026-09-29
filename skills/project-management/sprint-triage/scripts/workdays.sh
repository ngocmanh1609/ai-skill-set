#!/usr/bin/env bash
# Count working days (Mon–Fri) from FROM to TO, both inclusive, and print the number.
# Used to scale capacity to what's left of a sprint.
#
# Usage: workdays.sh [FROM] TO      dates as YYYY-MM-DD; FROM defaults to today
#
# Public holidays and personal leave aren't known here: subtract them from the result.
# Works with BSD date (macOS) and GNU date (Linux). Dates are read at 12:00 so
# daylight-saving shifts can't push a day over midnight.
set -euo pipefail

if [ $# -eq 1 ]; then from="$(date +%Y-%m-%d)"; to="$1"
elif [ $# -eq 2 ]; then from="$1"; to="$2"
else echo "usage: $0 [FROM] TO   (YYYY-MM-DD)" >&2; exit 2
fi

if date -j -f "%Y-%m-%d %H:%M" "2000-01-01 12:00" +%s >/dev/null 2>&1; then
  to_epoch() { date -j -f "%Y-%m-%d %H:%M" "$1 12:00" +%s; }
  weekday() { date -r "$1" +%u; }
else
  to_epoch() { date -d "$1 12:00" +%s; }
  weekday() { date -d "@$1" +%u; }
fi

start=$(to_epoch "$from") || { echo "error: bad date: $from" >&2; exit 2; }
end=$(to_epoch "$to") || { echo "error: bad date: $to" >&2; exit 2; }

count=0
t=$start
while [ "$t" -le "$end" ]; do
  [ "$(weekday "$t")" -le 5 ] && count=$((count + 1))
  t=$((t + 86400))
done
echo "$count"
