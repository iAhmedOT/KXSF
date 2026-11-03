"""Source-contract checks; not a substitute for native visual acceptance."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / "App/Mac/KXSFMacApp.swift").read_text()


class MenuBarContractTests(unittest.TestCase):
    def test_only_one_status_item_is_created(self):
        self.assertEqual(SOURCE.count("NSStatusBar.system.statusItem("), 1)

    def test_tab_picker_hides_its_label(self):
        self.assertIn('.pickerStyle(.segmented).labelsHidden()', SOURCE)
        self.assertIn('Picker("Destination",', SOURCE)

    def test_listen_keeps_playback_control(self):
        listen = SOURCE.split('private var listen: some View {', 1)[1].split('private var shows:', 1)[0]
        self.assertIn('Button { session.togglePlayback() }', listen)
        self.assertIn('"Listen live"', listen)


if __name__ == "__main__":
    unittest.main()
