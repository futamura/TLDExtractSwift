#!/usr/bin/env python3
# -*- coding:utf-8 -*-

"""Tests for the pure helpers in update-psl.py.

The script's filename is not a valid module name, so it is loaded by path.
Nothing here touches the network or the bundled files.
"""

import importlib.util
import os
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'update-psl.py')
_spec = importlib.util.spec_from_file_location('update_psl', _SCRIPT)
update_psl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(update_psl)


class DiffRulesTest(unittest.TestCase):
    def test_reports_added_and_removed_rules(self):
        added, removed = update_psl.diff_rules('com\nold.example\n', 'com\nnew.example\n')
        self.assertEqual(added, {'new.example'})
        self.assertEqual(removed, {'old.example'})

    def test_ignores_reordering(self):
        added, removed = update_psl.diff_rules('ac.pr\nest.pr\n', 'est.pr\nac.pr\n')
        self.assertEqual(added, set())
        self.assertEqual(removed, set())

    def test_drops_the_punycoded_variant_of_an_added_rule(self):
        added, removed = update_psl.diff_rules('com\n', 'com\nмосква\nxn--80adxhks\n')
        self.assertEqual(added, {'москва'})
        self.assertEqual(removed, set())

    def test_keeps_a_punycoded_rule_that_stands_on_its_own(self):
        added, removed = update_psl.diff_rules('com\n', 'com\nxn--80adxhks\n')
        self.assertEqual(added, {'xn--80adxhks'})
        self.assertEqual(removed, set())


class RenderEntryTest(unittest.TestCase):
    def test_lists_a_small_number_of_rules_individually_in_order(self):
        entry = update_psl.render_entry({'b.example', 'a.example'}, set())
        self.assertEqual(
            entry,
            'The bundled Public Suffix List is refreshed. Added: `a.example`, `b.example`.')

    def test_collapses_rules_that_share_a_parent_suffix(self):
        added = {'r%d.azurewebsites.net' % i for i in range(5)}
        entry = update_psl.render_entry(added, set())
        self.assertEqual(
            entry,
            'The bundled Public Suffix List is refreshed. '
            'Added: 5 rules under `azurewebsites.net`.')

    def test_keeps_a_group_below_the_threshold_expanded(self):
        added = {'r%d.azurewebsites.net' % i for i in range(4)}
        entry = update_psl.render_entry(added, set())
        self.assertIn('`r0.azurewebsites.net`', entry)
        self.assertNotIn('rules under', entry)

    def test_puts_collapsed_groups_before_individual_rules(self):
        added = {'r%d.azurewebsites.net' % i for i in range(5)} | {'a.example'}
        entry = update_psl.render_entry(added, set())
        self.assertEqual(
            entry,
            'The bundled Public Suffix List is refreshed. '
            'Added: 5 rules under `azurewebsites.net`, `a.example`.')

    def test_explains_the_effect_of_a_removal(self):
        entry = update_psl.render_entry(set(), {'xnbay.com'})
        self.assertEqual(
            entry,
            'The bundled Public Suffix List is refreshed. Removed: `xnbay.com` — hosts under a '
            'removed rule now parse as registrable domains under its parent suffix.')

    def test_reports_additions_before_removals(self):
        entry = update_psl.render_entry({'a.example'}, {'b.example'})
        self.assertEqual(
            entry,
            'The bundled Public Suffix List is refreshed. Added: `a.example`. '
            'Removed: `b.example` — hosts under a removed rule now parse as registrable '
            'domains under its parent suffix.')

    def test_returns_none_when_nothing_changed(self):
        self.assertIsNone(update_psl.render_entry(set(), set()))


HEADER = """# Changelog

All notable changes to this project are documented in this file.

"""

RELEASED = """## [4.0.5] - 2026-09-08

### Changed

- An earlier refresh.

[Unreleased]: https://example.com/compare/4.0.5...HEAD
"""


class UpdateChangelogTest(unittest.TestCase):
    def test_opens_an_unreleased_section_when_there_is_none(self):
        updated = update_psl.update_changelog(HEADER + RELEASED, 'A bullet.')
        self.assertEqual(
            updated,
            HEADER + '## [Unreleased]\n\n### Changed\n\n- A bullet.\n\n' + RELEASED)

    def test_appends_a_changed_section_to_an_existing_unreleased_section(self):
        unreleased = '## [Unreleased]\n\n### Added\n\n- A new thing.\n\n'
        updated = update_psl.update_changelog(HEADER + unreleased + RELEASED, 'A bullet.')
        self.assertEqual(
            updated,
            HEADER + unreleased + '### Changed\n\n- A bullet.\n\n' + RELEASED)

    def test_appends_to_an_existing_changed_section(self):
        unreleased = '## [Unreleased]\n\n### Changed\n\n- Something else.\n\n'
        updated = update_psl.update_changelog(HEADER + unreleased + RELEASED, 'A bullet.')
        self.assertEqual(
            updated,
            HEADER + '## [Unreleased]\n\n### Changed\n\n- Something else.\n- A bullet.\n\n'
            + RELEASED)

    def test_keeps_an_earlier_bullet_from_this_script(self):
        # Each run reports the delta since the last refresh, so an earlier bullet
        # describes rules this one says nothing about. Replacing it would lose them.
        earlier = update_psl.ENTRY_PREFIX + ' Added: `a.example`.'
        latest = update_psl.ENTRY_PREFIX + ' Added: `b.example`.'
        unreleased = '## [Unreleased]\n\n### Changed\n\n- %s\n\n' % earlier
        updated = update_psl.update_changelog(HEADER + unreleased + RELEASED, latest)
        self.assertEqual(
            updated,
            HEADER + '## [Unreleased]\n\n### Changed\n\n- %s\n- %s\n\n' % (earlier, latest)
            + RELEASED)


if __name__ == '__main__':
    unittest.main()
