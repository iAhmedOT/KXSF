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


ROOT = Path(__file__).resolve().parents[2]
PLIST = (ROOT / "App/Mac/Info.plist").read_text()
PROJECT_YML = (ROOT / "project.yml").read_text()
MAC_PLAYER = (ROOT / "App/Mac/MacRadioPlayer.swift").read_text()


class MacLifecycleContractTests(unittest.TestCase):
    """Static checks only. Dock/minimize/close/reopen/quit need a real run (Pixel)."""

    def test_app_is_a_regular_dock_app_not_an_accessory(self):
        self.assertNotIn("LSUIElement", PLIST)
        self.assertNotIn("LSUIElement", PROJECT_YML)

    def test_closing_the_window_does_not_quit(self):
        signature = "func applicationShouldTerminateAfterLastWindowClosed"
        self.assertIn(signature, SOURCE)
        body = SOURCE.split(signature, 1)[1].split("\n", 1)[0]
        self.assertTrue(body.rstrip().endswith("{ false }"), body)

    def test_main_window_scene_exists_and_menu_bar_can_reopen_it(self):
        self.assertIn('Window("KXSF", id: MacWindowID.main)', SOURCE)
        self.assertIn("Open KXSF Window", SOURCE)
        self.assertIn("applicationShouldHandleReopen", SOURCE)

    def test_explicit_quit_paths_terminate(self):
        self.assertIn('Button("Quit KXSF") { NSApplication.shared.terminate(nil) }', SOURCE)
        self.assertIn("func applicationWillTerminate", SOURCE)

    def test_player_is_owned_once_by_the_delegate_and_views_do_not_create_it(self):
        self.assertEqual(SOURCE.count("MacRadioPlayer()"), 1)
        self.assertEqual(SOURCE.count("LiveShowStore()"), 1)
        self.assertEqual(SOURCE.count("MenuBarSession(transport:"), 1)

    def test_window_views_never_start_or_stop_playback_on_appearance(self):
        # Playback is only toggled by the user's button (through the shared session).
        self.assertEqual(SOURCE.count("player.play()"), 0)
        self.assertEqual(SOURCE.count("player.pause()"), 1)  # applicationWillTerminate only

    def test_player_is_not_the_ios_audio_service(self):
        self.assertNotIn("AudioPlayerService", SOURCE)
        self.assertNotIn("AVAudioSession", MAC_PLAYER)

    def test_mac_target_files_are_unchanged_in_membership(self):
        pbx = (ROOT / "KXSF.xcodeproj/project.pbxproj").read_text()
        for name in ("KXSFMacApp.swift", "MacRadioPlayer.swift", "LiveShowStore.swift"):
            self.assertIn(name, pbx)
        # Everything Mac needs lives in these three files + KXSFCore; no new Mac-only file.
        self.assertEqual(sorted(p.name for p in (ROOT / "App/Mac").glob("*.swift")),
                         ["KXSFMacApp.swift", "MacRadioPlayer.swift"])


if __name__ == "__main__":
    unittest.main()
