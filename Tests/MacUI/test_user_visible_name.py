import plistlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class MacUserVisibleNameTests(unittest.TestCase):
    def test_plist_names_are_kxsf(self):
        info = plistlib.loads((ROOT / "App/Mac/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleDisplayName"], "KXSF")
        self.assertEqual(info["CFBundleName"], "KXSF")

    def test_generator_source_declares_name(self):
        text = (ROOT / "project.yml").read_text()
        mac = text.split("  KXSFMac:\n", 1)[1].split("\n  KXSF:\n", 1)[0]
        self.assertRegex(mac, r"CFBundleName: KXSF\n")

    def test_target_and_signing_unchanged(self):
        text = (ROOT / "project.yml").read_text()
        self.assertIn("PRODUCT_NAME: KXSFMac", text)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: com.KXSF.fm", text)


if __name__ == "__main__":
    unittest.main()
