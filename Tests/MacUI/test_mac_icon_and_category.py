import json
import os
import plistlib
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ICONSET = ROOT / "App/Assets.xcassets/AppIcon.appiconset"

# (point size, scale) -> pixel size required by macOS ICNS generation.
MAC_SLOTS = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
             (256, 1), (256, 2), (512, 1), (512, 2)]


def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} is not a PNG"
    return struct.unpack(">II", data[16:24])


class MacCategoryTests(unittest.TestCase):
    def test_plist_category_is_music(self):
        info = plistlib.loads((ROOT / "App/Mac/Info.plist").read_bytes())
        self.assertEqual(info["LSApplicationCategoryType"], "public.app-category.music")
        self.assertEqual(info["CFBundleName"], "KXSF")

    def test_generator_declares_category_in_mac_target(self):
        text = (ROOT / "project.yml").read_text()
        mac = text.split("  KXSFMac:\n", 1)[1].split("\n  KXSF:\n", 1)[0]
        self.assertIn("LSApplicationCategoryType: public.app-category.music\n", mac)
        self.assertIn("CFBundleName: KXSF\n", mac)
        # iOS target must not gain the category.
        ios = text.split("\n  KXSF:\n", 1)[1]
        self.assertNotIn("LSApplicationCategoryType", ios)


class MacIconTests(unittest.TestCase):
    def setUp(self):
        self.contents = json.loads((ICONSET / "Contents.json").read_text())
        self.images = self.contents["images"]

    def test_ios_entry_preserved(self):
        ios = [i for i in self.images if i.get("platform") == "ios"]
        self.assertEqual(ios, [{
            "filename": "AppIcon-1024.png", "idiom": "universal",
            "platform": "ios", "size": "1024x1024"}])
        self.assertEqual(png_size(ICONSET / "AppIcon-1024.png"), (1024, 1024))

    def test_all_standard_mac_slots_present_with_correct_pixels(self):
        mac = {(i["size"], i["scale"]): i for i in self.images if i.get("idiom") == "mac"}
        for pt, scale in MAC_SLOTS:
            with self.subTest(size=pt, scale=scale):
                entry = mac.get((f"{pt}x{pt}", f"{scale}x"))
                self.assertIsNotNone(entry, "missing mac slot")
                path = ICONSET / entry["filename"]
                self.assertTrue(path.is_file(), f"missing file {path.name}")
                self.assertEqual(png_size(path), (pt * scale, pt * scale))

    def test_each_mac_slot_has_its_own_file(self):
        # Slots must not share a file: actool's ICNS output was observed to
        # drop slots (incl. 512x512@2x) when filenames were reused.
        names = [i["filename"] for i in self.images if i.get("idiom") == "mac"]
        self.assertEqual(len(names), len(set(names)), "mac slots share files")

    def test_512_at_2x_present(self):
        self.assertTrue(any(i.get("idiom") == "mac" and i.get("size") == "512x512"
                            and i.get("scale") == "2x" for i in self.images))

    def test_generator_script_declares_icns_build_phase(self):
        text = (ROOT / "project.yml").read_text()
        mac = text.split("  KXSFMac:\n", 1)[1].split("\n  KXSF:\n", 1)[0]
        self.assertIn("postBuildScripts:", mac)
        self.assertIn("make_mac_icns.sh", mac)
        self.assertNotIn("make_mac_icns", text.split("\n  KXSF:\n", 1)[1])
        pbx = (ROOT / "KXSF.xcodeproj/project.pbxproj").read_text()
        self.assertIn("Generate Mac AppIcon.icns", pbx)
        self.assertIn("make_mac_icns.sh", pbx)
        for pt, scale in MAC_SLOTS:
            name = f"AppIcon-mac-{pt}x{pt}@{scale}x.png"
            self.assertIn(name, mac)
            self.assertIn(name, pbx)

    def test_icns_script_references_only_catalog_slots(self):
        script = (ROOT / "Scripts/make_mac_icns.sh").read_text()
        referenced = {i["filename"] for i in self.images if i.get("idiom") == "mac"}
        for name in referenced:
            self.assertIn(name, script)


# Acceptable ICNS chunk types for each required pixel size. iconutil may encode
# a size as PNG-based (icp4/icp5/ic07..ic14) or legacy types, so accept any.
REQUIRED_ICNS_SIZES = {
    16: {b"icp4", b"ic04"}, 32: {b"icp5", b"ic11", b"ic05"},
    64: {b"ic12"}, 128: {b"ic07"}, 256: {b"ic08", b"ic13"},
    512: {b"ic09", b"ic14"}, 1024: {b"ic10"},
}


def icns_chunks(path):
    data = Path(path).read_bytes()
    assert data[:4] == b"icns", "not an ICNS file"
    assert struct.unpack(">I", data[4:8])[0] == len(data), "bad ICNS length"
    pos, chunks = 8, []
    while pos + 8 <= len(data):
        kind, length = struct.unpack(">4sI", data[pos:pos + 8])
        chunks.append((kind, data[pos + 8:pos + length]))
        pos += length
    return chunks


@unittest.skipUnless(os.environ.get("KXSF_MAC_APP"),
                     "set KXSF_MAC_APP=/path/to/KXSFMac.app to check a built app")
class BuiltMacAppTests(unittest.TestCase):
    def setUp(self):
        self.app = Path(os.environ["KXSF_MAC_APP"])

    def test_built_icns_has_all_required_sizes(self):
        chunks = icns_chunks(self.app / "Contents/Resources/AppIcon.icns")
        kinds = {k for k, _ in chunks}
        for size, types in REQUIRED_ICNS_SIZES.items():
            with self.subTest(size=size):
                self.assertTrue(kinds & types, f"no {size}px chunk; got {sorted(kinds)}")
        # The 1024px chunk must hold a real 1024x1024 PNG.
        payload = dict(chunks)[b"ic10"]
        self.assertEqual(payload[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", payload[16:24]), (1024, 1024))

    def test_built_icns_round_trips_through_iconutil(self):
        import subprocess, tempfile
        icns = self.app / "Contents/Resources/AppIcon.icns"
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "out.iconset"
            subprocess.run(["/usr/bin/iconutil", "-c", "iconset", str(icns),
                            "-o", str(out)], check=True)
            for pt, scale in MAC_SLOTS:
                name = f"icon_{pt}x{pt}" + ("@2x" if scale == 2 else "") + ".png"
                with self.subTest(file=name):
                    self.assertEqual(png_size(out / name), (pt * scale, pt * scale))

    def test_built_plist_icon_and_category(self):
        info = plistlib.loads((self.app / "Contents/Info.plist").read_bytes())
        self.assertEqual(info["LSApplicationCategoryType"], "public.app-category.music")
        self.assertEqual(info.get("CFBundleIconFile", info.get("CFBundleIconName")) is not None, True)


if __name__ == "__main__":
    unittest.main()
