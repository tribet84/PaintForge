#!/usr/bin/env python3
"""Adds paints to a brand catalogue, refusing anything that looks unsafe.

Catalogue ids become the key an inventory entry is stored under in Firestore,
so a bad one is not a typo — it is a permanent broken row in every user's
account. This script is the gate: it derives ids the same way every time and
rejects duplicates, malformed colours and blank fields rather than trusting
the caller to have been careful.

Usage:
    tool/add_paints.py <brand.json> <additions.json>

additions.json is a list of {"name", "range", "code"(optional), "hex"}.
"""
import json
import re
import sys


def slug(name: str) -> str:
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def make_id(brand_prefix: str, code: str | None, name: str, rng: str,
            name_ranges: dict[str, set[str]]) -> str:
    """Builds the permanent catalogue id for a paint.

    Vallejo and The Army Painter number their pots, and the number is the
    stable identity. Citadel does not, so the name carries it — but the same
    Citadel name appears in more than one range: "Abaddon Black" exists as
    Base and again as Air, and they are different products a painter can own
    separately. Where a name is not unique, the range goes into the id.
    """
    if code:
        return f"{brand_prefix}-{re.sub(r'[^a-z0-9]', '', code.lower())}-{slug(name)}"
    if len(name_ranges.get(name.lower(), set()) | {rng}) > 1:
        return f"{brand_prefix}-{slug(rng)}-{slug(name)}"
    return f"{brand_prefix}-{slug(name)}"


def main() -> int:
    catalogue_path, additions_path = sys.argv[1], sys.argv[2]
    catalogue = json.load(open(catalogue_path))
    additions = json.load(open(additions_path))

    prefix = {'citadel': 'citadel', 'vallejo': 'vallejo',
              'army_painter': 'tap', 'green_stuff_world': 'gsw'}[
        catalogue_path.split('/')[-1].removesuffix('.json')]

    existing_ids = {p['id'] for p in catalogue['paints']}
    # Which ranges each name already appears in, so a name that is about to
    # become ambiguous gets a range-qualified id.
    name_ranges: dict[str, set[str]] = {}
    for p in catalogue['paints']:
        name_ranges.setdefault(p['name'].lower(), set()).add(p['range'])
    # Same name in the same range is a duplicate; the same name across two
    # ranges is not (Model Color and Game Color both have a "Black").
    existing_keys = {(p['name'].lower(), p['range']) for p in catalogue['paints']}

    added, skipped, errors = [], [], []
    for entry in additions:
        name, rng = entry.get('name', '').strip(), entry.get('range', '').strip()
        hexv, code = entry.get('hex', '').strip(), (entry.get('code') or '').strip()

        if not name or not rng:
            errors.append(f'missing name or range: {entry}')
            continue
        # A blank colour is allowed on purpose: a name verified from the
        # manufacturer is worth listing before anyone has measured the pot.
        # A malformed one is not — that is a mistake, not a gap.
        if hexv and not re.fullmatch(r'#[0-9A-Fa-f]{6}', hexv):
            errors.append(f'{name}: bad hex {hexv!r}')
            continue

        pid = make_id(prefix, code, name, rng, name_ranges)
        if pid in existing_ids or (name.lower(), rng) in existing_keys:
            skipped.append(name)
            continue

        catalogue['paints'].append({
            'id': pid, 'name': name, 'range': rng,
            'code': code or None,
            **({'hex': hexv.upper()} if hexv else {}),
        })
        existing_ids.add(pid)
        existing_keys.add((name.lower(), rng))
        name_ranges.setdefault(name.lower(), set()).add(rng)
        added.append(name)

    if errors:
        print('REJECTED — nothing written:')
        for e in errors:
            print('  ', e)
        return 1

    catalogue['paints'].sort(key=lambda p: (p['range'], p['name']))
    with open(catalogue_path, 'w') as f:
        json.dump(catalogue, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f'added {len(added)}, already present {len(skipped)}, '
          f'total now {len(catalogue["paints"])}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
