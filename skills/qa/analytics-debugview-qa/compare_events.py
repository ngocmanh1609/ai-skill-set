#!/usr/bin/env python3
"""Compares the Firebase Analytics events in an Android logcat capture with the
expected events of one test case, and reports what is missing, extra, or wrong.

  compare_events.py <expected.json> <fa.log> --case <id> [--since HH:MM:SS] [--until HH:MM:SS]

<fa.log> comes from `adb logcat -v time -s FA-SVC:V FA:V`. --since is inclusive,
--until exclusive. Exit code: 0 pass, 1 fail, 2 bad input.

expected.json:

  {
    "ignore": ["param_you_do_not_check"],
    "cases": [
      {
        "id": "2",
        "title": "Tap the popup creative",
        "events": [
          {
            "name": "select_promotion",
            "match": {"creative_slot": "popup"},
            "count": 1,
            "params": {
              "creative_slot": "popup",
              "promotion_id": "01a0423f-de6b-7f04-b7ea-34c70e31e449",
              "promotion_name": "*"
            },
            "optional": {"creative_name": "*"},
            "items": [{"item_id": "re:[0-9a-f-]{36}", "item_name": "*"}],
            "source": "SC-12345 AC 2; docs/specs/event-tracking.md BR-49"
          }
        ],
        "absent": ["add_to_cart", {"name": "view_promotion", "match": {"creative_slot": "popup"}}]
      }
    ]
  }

Value rules: "*" means present and not empty, "re:<regex>" must match the whole
value, anything else must equal the logged value as text. "match" picks which
logged events of that name belong to the entry (default: all of them). Leave
"items" out when the event must carry no items. Params Firebase adds by itself
(names with a "(_code)" suffix, or starting with "_", "ga_", "firebase_", or
"google_") are never reported as extra, except firebase_error.
"""
import argparse
import json
import re
import sys

LINE = re.compile(
    r'^\S+ (\S+) [VDIWE]/(FA(?:-SVC)?)\s*\(\s*\d+\): Logging event: '
    r'origin=(\w+),name=(\w+)(?:\(_\w+\))?,params=Bundle\[\{(.*)\}\]\s*$'
)
KEY = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)(\(_[A-Za-z0-9_]+\))?=')
ITEM_SEP = '}], Bundle[{'
ERROR_PARAMS = ('firebase_error', 'firebase_error_value', 'firebase_error_length')
AUTO_PREFIXES = ('_', 'ga_', 'firebase_', 'google_')


def split_params(text):
    # Splits "k=v, k=v" only at commas outside brackets that start a new key,
    # so values with ", " in them and nested item bundles stay whole.
    parts, depth, start, i = [], 0, 0, 0
    while i < len(text):
        c = text[i]
        if c in '[{':
            depth += 1
        elif c in ']}':
            depth -= 1
        elif depth == 0 and text.startswith(', ', i) and KEY.match(text, i + 2):
            parts.append(text[start:i])
            i += 2
            start = i
            continue
        i += 1
    parts.append(text[start:])
    return [p for p in parts if p]


def split_items(text):
    items, depth, start, i = [], 0, 0, 0
    while i < len(text):
        if depth == 0 and text.startswith(ITEM_SEP, i):
            items.append(text[start:i])
            i += len(ITEM_SEP)
            start = i
            continue
        c = text[i]
        if c in '[{':
            depth += 1
        elif c in ']}':
            depth -= 1
        i += 1
    items.append(text[start:])
    return items


def parse_bundle(text):
    """Returns {name: value} and the set of names Firebase added by itself."""
    params, auto = {}, set()
    for part in split_params(text):
        m = KEY.match(part)
        if not m:
            continue
        name, coded, value = m.group(1), m.group(2), part[m.end():]
        if value.startswith('[Bundle[{') and value.endswith('}]]'):
            value = [parse_bundle(b)[0] for b in split_items(value[len('[Bundle[{'):-len('}]]')])]
        params[name] = value
        if name not in ERROR_PARAMS and (coded or name.startswith(AUTO_PREFIXES)):
            auto.add(name)
    return params, auto


def read_events(path, since, until):
    by_tag, unparsed = {'FA-SVC': [], 'FA': []}, 0
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            if 'Logging event: ' not in line:
                continue
            m = LINE.match(line.rstrip('\n'))
            if not m:
                unparsed += 1
                continue
            time, tag, origin, name, body = m.groups()
            if time < since or (until and time >= until):
                continue
            params, auto = parse_bundle(body)
            by_tag[tag].append({'time': time, 'origin': origin, 'name': name, 'params': params, 'auto': auto})
    # Google Play services (FA-SVC) and the app (FA) can both log the same event.
    return by_tag['FA-SVC'] or by_tag['FA'], unparsed


def check_value(rule, actual):
    if isinstance(actual, list):
        return 'is a list of bundles'
    if rule == '*':
        return None if actual != '' else 'is empty'
    if isinstance(rule, str) and rule.startswith('re:'):
        return None if re.fullmatch(rule[3:], actual) else 'does not match /%s/' % rule[3:]
    return None if str(rule) == actual else 'expected %s' % rule


def as_rules(value):
    if isinstance(value, dict):
        return value
    return {name: '*' for name in (value or [])}


def compare_bundle(where, required, optional, actual, auto, ignore):
    problems = []
    for name, rule in required.items():
        if name not in actual:
            problems.append(('missing', '%s%s' % (where, name)))
            continue
        why = check_value(rule, actual[name])
        if why:
            problems.append(('wrong', '%s%s=%s (%s)' % (where, name, actual[name], why)))
    for name, rule in optional.items():
        if name in actual and rule != '*':
            why = check_value(rule, actual[name])
            if why:
                problems.append(('wrong', '%s%s=%s (%s)' % (where, name, actual[name], why)))
    for name, value in actual.items():
        if name in required or name in optional or name in auto or name in ignore or name == 'items':
            continue
        if name in ERROR_PARAMS:
            problems.append(('firebase', '%s%s=%s' % (where, name, value)))
        else:
            problems.append(('extra', '%s%s=%s' % (where, name, value)))
    return problems


def compare_event(spec, event, ignore):
    params = event['params']
    problems = compare_bundle('', spec.get('params', {}), as_rules(spec.get('optional')), params, event['auto'], ignore)
    expected_items, actual_items = spec.get('items'), params.get('items')
    if expected_items is None:
        if actual_items is not None:
            problems.append(('extra', 'items (%d)' % len(actual_items) if isinstance(actual_items, list) else 'items'))
    elif not isinstance(actual_items, list):
        problems.append(('missing', 'items'))
    else:
        if len(actual_items) != len(expected_items):
            problems.append(('wrong', 'items count %d (expected %d)' % (len(actual_items), len(expected_items))))
        for i, (rules, item) in enumerate(zip(expected_items, actual_items), 1):
            problems += compare_bundle('items[%d].' % i, rules, {}, item, set(), ignore)
    return problems


def matches(event, name, match):
    return event['name'] == name and all(event['params'].get(k) == str(v) for k, v in (match or {}).items())


def label(name, match):
    return name + (' [%s]' % ', '.join('%s=%s' % kv for kv in match.items()) if match else '')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('expected')
    ap.add_argument('log')
    ap.add_argument('--case', required=True)
    ap.add_argument('--since', default='00:00:00')
    ap.add_argument('--until')
    args = ap.parse_args()

    try:
        with open(args.expected, encoding='utf-8') as f:
            contract = json.load(f)
        case = next(c for c in contract['cases'] if str(c['id']) == args.case)
    except (OSError, ValueError, KeyError, StopIteration) as e:
        print('Cannot read case %s from %s: %r' % (args.case, args.expected, e))
        return 2

    ignore = set(contract.get('ignore', []))
    events, unparsed = read_events(args.log, args.since, args.until)
    failed, claimed = False, set()
    print('Case %s%s, %s to %s' % (case['id'], ' (%s)' % case['title'] if case.get('title') else '',
                                   args.since, args.until or 'end'))

    for spec in case.get('events', []):
        found = [e for e in events if matches(e, spec['name'], spec.get('match'))]
        claimed.update(id(e) for e in found)
        want = spec.get('count', 1)
        ok_count = len(found) == want
        failed |= not ok_count
        print('  %s: expected %d, logged %d%s' % (label(spec['name'], spec.get('match')), want, len(found),
                                                 '' if ok_count else '  <-- FAIL'))
        for e in found:
            problems = compare_event(spec, e, ignore)
            failed |= bool(problems)
            print('    %s  %s' % (e['time'], 'FAIL' if problems else 'PASS'))
            for kind, text in problems:
                print('      %-8s %s' % (kind, text))
            app_params = sorted(n for n in e['params'] if n not in e['auto'] and n != 'items')
            n_items = len(e['params']['items']) if isinstance(e['params'].get('items'), list) else 0
            print('      DebugView should show params: %s; items: %d' % (', '.join(app_params) or '(none)', n_items))

    for entry in case.get('absent', []):
        name, match = (entry, None) if isinstance(entry, str) else (entry['name'], entry.get('match'))
        found = [e for e in events if matches(e, name, match)]
        failed |= bool(found)
        print('  must not fire %s: logged %d%s' % (label(name, match), len(found), '  <-- FAIL' if found else ''))
        for e in found:
            print('    %s' % e['time'])

    names = {s['name'] for s in case.get('events', [])}
    others = [e for e in events if e['name'] in names and id(e) not in claimed]
    for e in others:
        shown = ', '.join('%s=%s' % (k, v) for k, v in e['params'].items() if k not in e['auto'] and k != 'items')
        print('  note: %s %s also logged, matching no expected entry: %s' % (e['time'], e['name'], shown))
    if unparsed:
        print('  note: %d "Logging event" line(s) could not be parsed (maybe cut by logcat); check them by hand' % unparsed)

    print('RESULT: %s' % ('FAIL' if failed else 'PASS'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
