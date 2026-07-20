import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "PetHalo" / "Assets.xcassets"


def png_size(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"not a PNG: {path}")
    width, height, _, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, color_type


class M8IconAssetTests(unittest.TestCase):
    def test_app_icon_catalog_is_complete_rgba_and_originally_named(self) -> None:
        contents_path = ASSETS / "AppIcon.appiconset" / "Contents.json"
        contents = json.loads(contents_path.read_text(encoding="utf-8"))
        filenames = {entry["filename"] for entry in contents["images"]}
        expected_sizes = {16, 32, 64, 128, 256, 512, 1024}
        self.assertEqual(
            filenames,
            {f"app-icon-{size}.png" for size in expected_sizes},
        )
        for size in expected_sizes:
            width, height, color_type = png_size(contents_path.parent / f"app-icon-{size}.png")
            self.assertEqual((width, height), (size, size))
            self.assertEqual(color_type, 6, "AppIcon PNG must retain an alpha channel")

    def test_menu_bar_icon_is_a_two_scale_template_asset(self) -> None:
        contents_path = ASSETS / "MenuBarIcon.imageset" / "Contents.json"
        contents = json.loads(contents_path.read_text(encoding="utf-8"))
        self.assertEqual(
            contents["properties"]["template-rendering-intent"],
            "template",
        )
        self.assertEqual(png_size(contents_path.parent / "menu-bar-icon.png"), (18, 18, 6))
        self.assertEqual(png_size(contents_path.parent / "menu-bar-icon-2x.png"), (36, 36, 6))

        source = (ROOT / "PetHalo" / "Application" / "PetHaloApp.swift").read_text(
            encoding="utf-8"
        )
        self.assertIn('MenuBarExtra(menuModel.applicationName, image: "MenuBarIcon")', source)
        self.assertNotIn('systemImage: "circle.dashed"', source)


if __name__ == "__main__":
    unittest.main()
