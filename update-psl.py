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
    psl_str = add_punycoded_rules(normalize(fetch_psl()))
    write_dat(os.path.join(src_dir, 'Resources/public_suffix_list.dat'), psl_str)
    write_dat(os.path.join(src_dir, 'Resources/public_suffix_list_frozen.dat'), psl_str)
    write_spm_source(os.path.join(src_dir, 'Sources/SPMPSL.swift'), psl_str)
