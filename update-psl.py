#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""Refresh the bundled Public Suffix List.

Rewrites both bundled .dat resources and the SPM string literal from a single
download, so every build path ships the same snapshot.
"""

import os
import re
import sys
from urllib.request import urlopen

PSL_URL = 'https://publicsuffix.org/list/public_suffix_list.dat'
SPM_PSL_PATTERN = re.compile(r'(let SPM_PSL = """\n).*?(\n""")', re.DOTALL)
# Rules sharing a parent suffix are collapsed once this many of them change.
GROUP_THRESHOLD = 5
# Every bullet opens with this, so an unreleased section that saw more than one
# refresh reads as a list of them.
ENTRY_PREFIX = 'The bundled Public Suffix List is refreshed.'
REMOVAL_EFFECT = (' — hosts under a removed rule now parse as registrable domains under its '
                  'parent suffix.')
UNRELEASED_HEADING = '## [Unreleased]'


def fetch_psl():
    with urlopen(PSL_URL) as response:
        return response.read().decode('utf-8')


def normalize(psl_str):
    # Remove comment
    psl_str = re.sub(r'//.*', '', psl_str)
    # Remove duplicated line breaks
    psl_str = re.sub(r'\n{2,}|^\n', '\n', psl_str)
    # Remove blank line from beginning and end
    psl_str = re.sub(r'^\n?|\n$\s{,0}', '', psl_str)
    return psl_str


def add_punycoded_rules(psl_str):
    lines = []
    skipped = []
    for line in psl_str.splitlines():
        lines.append(line)
        try:
            punycoded = line.encode('idna').decode('utf-8')
        except UnicodeError:
            skipped.append(line)
            continue
        if punycoded != line:
            lines.append(punycoded)
    if skipped:
        print('Could not punycode %d rule(s): %s' % (len(skipped), ', '.join(skipped)), file=sys.stderr)
    return '\n'.join(lines)


def diff_rules(old_str, new_str):
    """Return the rules added and removed between two generated lists.

    Both sides are compared as sets, so a rule that only moved is not a change.
    The punycoded variant this script writes after an internationalized rule is
    dropped from the additions, since it says nothing the rule itself does not.
    """
    old_rules = set(old_str.splitlines())
    new_rules = set(new_str.splitlines())
    added = new_rules - old_rules
    removed = old_rules - new_rules
    for rule in list(added):
        try:
            punycoded = rule.encode('idna').decode('utf-8')
        except UnicodeError:
            continue
        if punycoded != rule:
            added.discard(punycoded)
    return added, removed


def summarize_rules(rules):
    """Render rules as a comma-separated list, collapsing crowded parent suffixes.

    A registry that adds a rule per region contributes dozens of near-identical
    entries; naming the parent once keeps the changelog readable.
    """
    groups = {}
    for rule in rules:
        parent = rule.split('.', 1)[1] if '.' in rule else ''
        groups.setdefault(parent, []).append(rule)
    collapsed = []
    individual = []
    for parent, members in groups.items():
        if parent and len(members) >= GROUP_THRESHOLD:
            collapsed.append((parent, '%d rules under `%s`' % (len(members), parent)))
        else:
            individual.extend(members)
    fragments = [text for _, text in sorted(collapsed)]
    fragments.extend('`%s`' % rule for rule in sorted(individual))
    return ', '.join(fragments)


def render_entry(added, removed):
    """Render the changelog bullet for a refresh, or None when nothing changed."""
    if not added and not removed:
        return None
    parts = [ENTRY_PREFIX]
    if added:
        parts.append('Added: %s.' % summarize_rules(added))
    if removed:
        parts.append('Removed: %s%s' % (summarize_rules(removed), REMOVAL_EFFECT))
    return ' '.join(parts)


def _apply_to_changed_section(section, line):
    changed = re.search(r'^### Changed\n', section, re.MULTILINE)
    if changed is None:
        return '%s\n\n### Changed\n\n%s\n\n' % (section.rstrip('\n'), line)
    following = re.compile(r'^### ', re.MULTILINE).search(section, changed.end())
    body_end = following.start() if following else len(section)
    body = '%s\n%s\n\n' % (section[changed.end():body_end].rstrip('\n'), line)
    return section[:changed.end()] + body + section[body_end:]


def update_changelog(text, bullet):
    """Put the bullet under Unreleased / Changed, opening either heading if needed.

    Each refresh appends its own bullet. A bullet already there reports the delta
    of an earlier refresh, which this one says nothing about, so replacing it
    would drop those rules from the release notes.
    """
    line = '- %s' % bullet
    start = text.find(UNRELEASED_HEADING + '\n')
    if start == -1:
        opened = '%s\n\n### Changed\n\n%s\n\n' % (UNRELEASED_HEADING, line)
        anchor = re.search(r'^## \[', text, re.MULTILINE)
        if anchor is None:
            return '%s\n\n%s' % (text.rstrip('\n'), opened)
        return text[:anchor.start()] + opened + text[anchor.start():]
    following = re.compile(r'^## ', re.MULTILINE).search(text, start + len(UNRELEASED_HEADING))
    end = following.start() if following else len(text)
    return text[:start] + _apply_to_changed_section(text[start:end], line) + text[end:]


def write_dat(path, psl_str):
    with open(path, mode='w') as f:
        f.write(psl_str)


def write_spm_source(path, psl_str):
    # The literal is unescaped, so any backslash or quote run would break it.
    if '\\' in psl_str or '"""' in psl_str:
        sys.exit('The list contains characters that cannot be embedded in the Swift literal')
    with open(path) as f:
        source = f.read()
    replaced, count = SPM_PSL_PATTERN.subn(lambda match: match.group(1) + psl_str + match.group(2), source)
    if count != 1:
        sys.exit('Could not locate the SPM_PSL literal in %s' % path)
    with open(path, mode='w') as f:
        f.write(replaced)


if __name__ == '__main__':
    src_dir = os.path.dirname(os.path.abspath(__file__))
    dat_path = os.path.join(src_dir, 'Resources/public_suffix_list.dat')
    changelog_path = os.path.join(src_dir, 'CHANGELOG.md')
    # Read before overwriting: the bundled list is the only record of what the
    # previous snapshot held.
    try:
        with open(dat_path) as f:
            previous = f.read()
    except FileNotFoundError:
        previous = None
    psl_str = add_punycoded_rules(normalize(fetch_psl()))
    write_dat(dat_path, psl_str)
    write_dat(os.path.join(src_dir, 'Resources/public_suffix_list_frozen.dat'), psl_str)
    write_spm_source(os.path.join(src_dir, 'Sources/SPMPSL.swift'), psl_str)
    entry = render_entry(*diff_rules(previous, psl_str)) if previous is not None else None
    if entry:
        with open(changelog_path) as f:
            changelog = f.read()
        with open(changelog_path, mode='w') as f:
            f.write(update_changelog(changelog, entry))
        print(entry)
