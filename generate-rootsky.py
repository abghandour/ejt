#!/usr/bin/env python3
"""
Generate rootsky.json from russian-word-roots.json

Rules:
- Skip roots with fewer than 5 children
- Each day = 1 root, 5 randomly picked children from that root
- Exhaust all children of a root before moving to the next root
- Roots are shuffled randomly (seeded for reproducibility)
- Start date: Feb 1, 2026 (20260201)
- wordOptions: 5 wrong translations from OTHER roots
  - The 6 total options (1 correct + 5 wrong) must have 2 nouns, 2 verbs, 2 adjectives
  - So the 5 wrong picks complement the correct word's type
- Extra properties: rootWord, rootTranslation
"""

import json
import random
from datetime import datetime, timedelta

SEED = 42
random.seed(SEED)

with open('russian-word-roots.json', 'r', encoding='utf-8') as f:
    roots = json.load(f)

# Filter roots with at least 5 children
eligible = [r for r in roots if len(r.get('children', [])) >= 5]
print(f"Total roots: {len(roots)}, eligible (>=5 children): {len(eligible)}")

# Shuffle roots randomly
random.shuffle(eligible)

# Build a pool of all words by type from ALL roots (for wrong option picking)
all_nouns = []
all_verbs = []
all_adjs = []

for r in roots:
    for ch in r.get('children', []):
        entry = {'translation': ch['translation'], 'rootKey': r['rootKey']}
        t = ch.get('type', '').lower()
        if t == 'noun':
            all_nouns.append(entry)
        elif t == 'verb':
            all_verbs.append(entry)
        elif t == 'adjective':
            all_adjs.append(entry)

print(f"Word pool — nouns: {len(all_nouns)}, verbs: {len(all_verbs)}, adjectives: {len(all_adjs)}")

def pick_wrong_options(correct_translation, correct_type, correct_root_key):
    """
    Pick 5 wrong translations so that total 6 options = 2 nouns, 2 verbs, 2 adjectives.
    The correct word counts as one of its type, so we need:
    - If correct is noun: 1 more noun, 2 verbs, 2 adj
    - If correct is verb: 2 nouns, 1 more verb, 2 adj
    - If correct is adjective: 2 nouns, 2 verbs, 1 more adj
    All wrong options must come from OTHER roots.
    """
    need = {'noun': 2, 'verb': 2, 'adjective': 2}
    ct = correct_type.lower()
    if ct in need:
        need[ct] -= 1  # correct word fills one slot

    pools = {
        'noun': [e for e in all_nouns if e['rootKey'] != correct_root_key and e['translation'] != correct_translation],
        'verb': [e for e in all_verbs if e['rootKey'] != correct_root_key and e['translation'] != correct_translation],
        'adjective': [e for e in all_adjs if e['rootKey'] != correct_root_key and e['translation'] != correct_translation],
    }

    wrong = []
    used_translations = {correct_translation}

    for typ in ['noun', 'verb', 'adjective']:
        count = need[typ]
        available = [e for e in pools[typ] if e['translation'] not in used_translations]
        picks = random.sample(available, min(count, len(available)))
        for p in picks:
            wrong.append(p['translation'])
            used_translations.add(p['translation'])

    # If we couldn't fill all 5 (unlikely), pad from any pool
    while len(wrong) < 5:
        all_pool = all_nouns + all_verbs + all_adjs
        available = [e for e in all_pool if e['rootKey'] != correct_root_key and e['translation'] not in used_translations]
        if not available:
            break
        pick = random.choice(available)
        wrong.append(pick['translation'])
        used_translations.add(pick['translation'])

    return wrong[:5]


# Generate days
start_date = datetime(2026, 2, 1)
result = {}
day_offset = 0

for root in eligible:
    children = root['children'][:]
    random.shuffle(children)

    # Process in chunks of 5
    for i in range(0, len(children) - (len(children) % 5), 5):
        chunk = children[i:i+5]
        date_str = (start_date + timedelta(days=day_offset)).strftime('%Y%m%d')
        day_entries = []

        for child in chunk:
            wrong_opts = pick_wrong_options(
                child['translation'],
                child.get('type', 'noun'),
                root['rootKey']
            )
            day_entries.append({
                'wordOfTheDay': child['word'],
                'translation': child['translation'],
                'wordOptions': wrong_opts,
                'rootWord': root['rootWord'],
                'rootTranslation': root['rootTranslation']
            })

        result[date_str] = day_entries
        day_offset += 1

print(f"Generated {day_offset} days, from 20260201 to {(start_date + timedelta(days=day_offset-1)).strftime('%Y%m%d')}")

with open('rootsky.json', 'w', encoding='utf-8') as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

print("Written rootsky.json")
