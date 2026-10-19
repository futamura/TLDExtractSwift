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
# Rules that differ in one label, or share a domain, are collapsed once this many
# of them change.
GROUP_THRESHOLD = 5
# Every bullet opens with this, so an unreleased section that saw more than one
# refresh reads as a list of them.
ENTRY_PREFIX = 'The bundled Public Suffix List is refreshed.'
REMOVAL_EFFECT = (' — hosts under a removed rule now parse as registrable domains under its '
                  'parent suffix.')
# A removed top-level rule takes its whole namespace with it: no suffix is left
# for its hosts to match, so the library returns nil instead of falling back.
ORPHANED_REMOVAL_EFFECT = (' — no parent suffix is left to fall back to, so `parse` now returns '
                           '`nil` for hosts under %s.')
# A suffix whose own wildcard replaces it stops being a public suffix, and the
# labels under it start being ones.
SUFFIX_REPLACED_EFFECT = ('`%s` gives way to `%s`: it now parses as a registrable domain, and '
                          'every label directly under it is a public suffix.')
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
    remaining = set(rules)
    collapsed = []

    # First, rules that differ in a single label. When that label is the leftmost
    # one they share a parent; when it sits further in, as with
    # `consent-portal.<region>.example.com`, every rule has its own parent and only
    # the pattern ties them together. The top-level label is never the varying
    # one: rules under different TLDs have nothing in common worth naming.
    patterns = {}
    for rule in remaining:
        for key in _patterns(rule):
            patterns.setdefault(key, set()).add(rule)
    while True:
        candidates = [(len(members & remaining), key) for key, members in patterns.items()]
        count, key = max(candidates, default=(0, None))
        if count < GROUP_THRESHOLD:
            break
        remaining -= patterns[key]
        kind, text = key
        if kind == 'under':
            collapsed.append((text, '%d rules under `%s`' % (count, text)))
        else:
            collapsed.append((text, '%d rules of the form `%s`' % (count, text)))

    # Then whatever is left under one domain, however its rules are nested. The
    # last two labels stand in for the registrable domain, and the group is named
    # after the longest suffix its rules share.
    domains = {}
    for rule in remaining:
        labels = _labels(rule)
        if len(labels) > 2:
            domains.setdefault(tuple(labels[-2:]), []).append(labels)
    for members in domains.values():
        if len(members) < GROUP_THRESHOLD:
            continue
        shared = members[0]
        for labels in members[1:]:
            while labels[-len(shared):] != shared:
                shared = shared[1:]
        suffix = '.'.join(shared)
        remaining -= {rule for rule in remaining if _labels(rule) in members}
        collapsed.append((suffix, '%d rules under `%s`' % (len(members), suffix)))

    fragments = [text for _, text in sorted(collapsed)]
    fragments.extend('`%s`' % rule for rule in sorted(remaining))
    return ', '.join(fragments)


def _labels(rule):
    # A wildcard sits one label deeper than the rules it groups with, so a
    # registry adding `*.<region>.cs.example.com` per region is grouped under
    # `cs.example.com` rather than once per region.
    return (rule[2:] if rule.startswith('*.') else rule).split('.')


def _patterns(rule):
    labels = _labels(rule)
    keys = []
    if len(labels) > 1:
        keys.append(('under', '.'.join(labels[1:])))
    prefix = '*.' if rule.startswith('*.') else ''
    for i in range(1, len(labels) - 1):
        keys.append(('form', prefix + '.'.join(labels[:i] + ['<label>'] + labels[i + 1:])))
    return keys


def split_orphaned(removed):
    """Split removed rules by whether their hosts still have a suffix to fall back to.

    A top-level rule has no parent, and a rule whose top-level label is removed in
    the same refresh loses its parent along with it.
    """
    removed_tlds = {rule for rule in removed if '.' not in rule}
    orphaned = {rule for rule in removed if rule.rsplit('.', 1)[-1] in removed_tlds}
    return removed - orphaned, orphaned


def split_replaced(added, removed):
    """Pair each added wildcard with the removed rules it takes over.

    A registry that swaps its per-host rules for `*.example.dev` removes rules
    whose hosts still parse the same way, so reporting them as removals would
    describe a change that never happens. Only a rule exactly one label under the
    wildcard's suffix is covered; one further down loses its rule like any other.
    The suffix itself is paired too when it is removed in the same refresh, since
    its own behaviour does change, unless a wildcard one level up still covers
    it. A top-level suffix is left out: it has no parent to become registrable
    under.
    """
    replaced = {}
    for wildcard in added:
        if not wildcard.startswith('*.'):
            continue
        suffix = wildcard[2:]
        covered = {rule for rule in removed
                   if '*' not in rule and not rule.startswith('!') and '.' in rule
                   and rule.split('.', 1)[1] == suffix}
        if (suffix in removed and '.' in suffix
                and '*.' + suffix.split('.', 1)[1] not in added):
            covered.add(suffix)
        if covered:
            replaced[wildcard] = covered
    return replaced


def render_replacement(wildcard, covered):
    suffix = wildcard[2:]
    children = covered - {suffix}
    sentences = []
    if children:
        pronoun = 'it' if len(children) == 1 else 'them'
        sentences.append('`%s` replaces %s, so hosts under %s parse as before.'
                         % (wildcard, summarize_rules(children), pronoun))
    if suffix in covered:
        sentences.append(SUFFIX_REPLACED_EFFECT % (suffix, wildcard))
    return ' '.join(sentences)


def render_entry(added, removed):
    """Render the changelog bullet for a refresh, or None when nothing changed."""
    if not added and not removed:
        return None
    replaced = split_replaced(added, removed)
    added = added - set(replaced)
    removed = removed - set().union(*replaced.values())
    parts = [ENTRY_PREFIX]
    if added:
        parts.append('Added: %s.' % summarize_rules(added))
    for wildcard in sorted(replaced):
        parts.append(render_replacement(wildcard, replaced[wildcard]))
    with_parent, orphaned = split_orphaned(removed)
    if with_parent:
        parts.append('Removed: %s%s' % (summarize_rules(with_parent), REMOVAL_EFFECT))
    if orphaned:
        pronoun = 'it' if len(orphaned) == 1 else 'them'
        parts.append('Removed: %s%s' % (summarize_rules(orphaned), ORPHANED_REMOVAL_EFFECT % pronoun))
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
