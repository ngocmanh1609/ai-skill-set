#!/usr/bin/env bash
# Prints one line per Firebase Analytics event from an `adb logcat -s FA-SVC:V FA:V`
# capture: time, event name, then its params without the noisy ga_* ones.
#
#   fa_events.sh <fa.log> [since HH:MM:SS] [name-regex]
#
#   fa_events.sh fa.log                      # every event
#   fa_events.sh fa.log 15:10:18             # events after 15:10:18
#   fa_events.sh fa.log 15:10:18 promotion   # only names matching "promotion"
set -euo pipefail

log=${1:?usage: fa_events.sh <fa.log> [since HH:MM:SS] [name-regex]}
since=${2:-00:00:00}
filter=${3:-.}

grep -a 'FA-SVC.*Logging event: ' "$log" |
  awk -v since="$since" '$2 >= since' |
  perl -ne '
    # Built-in events carry their short code: name=screen_view(_vs).
    next unless /^\S+ (\S+) .*?Logging event: origin=\w+,name=(\w+)(?:\(\w+\))?,params=Bundle\[\{(.*)\}\]\s*$/;
    my ($t, $name, $p) = ($1, $2, $3);
    $p =~ s/ga_event_origin\(_o\)=\w+(, )?//;
    $p =~ s/ga_(?:previous_)?(?:screen_)?class\(_[a-z]+\)=\w+(, )?//g;
    $p =~ s/ga_(?:previous_|screen_)id\(_[a-z]+\)=-?\d+(, )?//g;
    $p =~ s/(?:engagement_time_msec\(_et\)|manual_tracking\(_mst\))=\d+(, )?//g;
    $p =~ s/ga_previous_screen\(_pn\)=/from=/;
    $p =~ s/ga_screen\(_sn\)=/screen=/;
    $p =~ s/, $//;
    print "$t  $name  $p\n";
  ' |
  awk -v f="$filter" '$2 ~ f'
