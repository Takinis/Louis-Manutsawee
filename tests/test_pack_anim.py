"""Run: DST_PYTHON=... python -m unittest discover -s tests -p test_pack_anim.py"""
import copy
import io
import json
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dstanim
import pack_anim


class PackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        parent = ROOT / "workspace/pack_anim_tests"
        parent.mkdir(parents=True, exist_ok=True)
        # Keep fixtures and failures for inspection; do not recursively remove directories.
        cls.run_directory = Path(tempfile.mkdtemp(prefix="run-", dir=parent))

    def setUp(self):
        self.folder = Path(tempfile.mkdtemp(prefix="case-", dir=self.run_directory))
        self.source = self.folder / "source"
        (self.source / "body").mkdir(parents=True)
        frame = dict(frameNum=0, duration=1, x=1.25, y=-8.5, width=16, height=16, vertNum=6, vertIdx=0)
        self.build = dict(version=6, name="test_build", symbols=[
            dict(name="body", frames=[frame]),
            dict(name="empty", frames=[dict(frame, vertNum=0)]),
        ])
        self.animation = dict(version=4, banks=[dict(name="test_bank", animations=[
            dict(name="idle_loop_down", frameRate=23.976, frames=[
                dict(x=0, y=-5, width=20, height=25, events=["step", 123], elements=[
                    dict(symbol="body", frameNum=0, layerName="body", a=1, b=0, c=0, d=1,
                         tx=2.5, ty=-3.25, zIndex=0)
                ])
            ])
        ])])
        self.Save()
        image = Image.new("RGBA", (16, 16))
        image.paste((225, 170, 190, 255), (3, 4, 12, 14))
        image.save(self.source / "body/body-0.png")

    def Save(self):
        (self.source / "build.json").write_text(json.dumps(self.build))
        (self.source / "anim.json").write_text(json.dumps(self.animation))

    def Pack(self, **kwargs):
        options = dict(output=self.folder / "result.zip", codec="rgba", atlas_size=64)
        options.update(kwargs)
        return pack_anim.Pack(self.source, **options)

    def test_rgba_roundtrip_and_direction(self):
        before = (self.source / "build.json").read_bytes()
        result = self.Pack(source_zip=True)
        self.assertEqual(result["sprites"], 1)
        self.assertTrue(result["verified"])
        self.assertEqual(result["roundTrip"][0]["max"], 0)
        packed = dstanim.Build(result["output"])
        self.assertEqual(packed.FindFrame(dstanim.StringHash("body"), 0).bbox, (1.25, -8.5, 16, 16))
        self.assertEqual(packed.FindFrame(dstanim.StringHash("empty"), 0).vert_count, 0)
        animations, _ = dstanim.ReadAnim(result["output"])
        self.assertEqual((animations[0].name, animations[0].facing), ("idle_loop", 8))
        self.assertEqual(animations[0].frames[0].events, [dstanim.StringHash("step"), 123])
        self.assertEqual(before, (self.source / "build.json").read_bytes())

    def test_dxt5_roundtrip(self):
        result = self.Pack(codec="dxt5")
        self.assertLess(result["roundTrip"][0]["mean"], 4)

    def test_nested_zip_source_and_build_only(self):
        archive = self.folder / "editable.zip"
        with zipfile.ZipFile(archive, "w") as z:
            for file in self.source.rglob("*"):
                if file.is_file():
                    z.write(file, "nested/export/" + file.relative_to(self.source).as_posix())
        result = pack_anim.Pack(archive, self.folder / "nested.zip", codec="rgba", atlas_size=64,
                                build_only=True, source_zip=True)
        with zipfile.ZipFile(result["output"]) as z:
            self.assertNotIn("anim.bin", z.namelist())
        with zipfile.ZipFile(self.folder / "nested-source.zip") as z:
            self.assertIn("anim.json", z.namelist())

    def test_overwrite_requires_flag_and_backs_up(self):
        result = self.Pack()
        original = Path(result["output"]).read_bytes()
        with self.assertRaises(FileExistsError):
            self.Pack()
        self.Pack(overwrite=True)
        backups = list((self.folder / ".pack-backups").glob("result.zip.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), original)

    def test_dynamic_block_layout(self):
        # Reference vectors produced by dont-starve-anim-tool.
        for expected in (
            "9593978f958d8d939d9b9f879d85859b1011121314151617",
            "9593978f958d8d939d9b9f879d85859b8583879f859d9d8318",
        ):
            encoded = bytes.fromhex(expected)
            data = bytes(range(len(encoded)))
            self.assertEqual(dstanim.EncodeDyn(data), encoded)
            self.assertEqual(dstanim.DecodeDyn(encoded), data)

    def test_dynamic_roundtrip(self):
        with patch.object(pack_anim, "ROOT", self.folder):
            result = self.Pack(output=None, dynamic=True)
        output = Path(result["output"])
        self.assertEqual(output, self.folder / "anim/dynamic/test_build.zip")
        sidecar = output.with_suffix(".dyn")
        data = sidecar.read_bytes()
        self.assertEqual(result["dyn"], str(sidecar))
        self.assertEqual(result["dynHash"], pack_anim.Digest(data))
        self.assertEqual(json.loads(output.with_suffix(".pack.json").read_text()), result)
        with zipfile.ZipFile(output) as package:
            self.assertEqual(package.namelist(), ["anim.bin", "build.bin"])
        decoded = dstanim.DecodeDyn(data)
        self.assertEqual(dstanim.DecodeDyn(decoded), decoded)
        with zipfile.ZipFile(io.BytesIO(decoded)) as package:
            self.assertEqual(package.namelist(), ["atlas-0.tex"])
            self.assertEqual(package.getinfo("atlas-0.tex").compress_type, zipfile.ZIP_STORED)
        self.assertEqual(dstanim.Build(output).Atlas(0).getpixel((4, 4)), (225, 170, 190, 255))

    def test_dynamic_overwrite_preflights_companion(self):
        sidecar = self.folder / "result.dyn"
        sidecar.write_bytes(b"previous")
        with self.assertRaisesRegex(FileExistsError, r"result\.dyn"):
            self.Pack(dynamic=True)
        self.assertFalse(sidecar.with_suffix(".zip").exists())
        result = self.Pack(dynamic=True, overwrite=True, build_only=True)
        with zipfile.ZipFile(result["output"]) as package:
            self.assertEqual(package.namelist(), ["build.bin"])
        backup, = (self.folder / ".pack-backups").glob("result.dyn.*")
        self.assertEqual(backup.read_bytes(), b"previous")

    def test_failed_install_restores_dynamic_pair(self):
        result = self.Pack(dynamic=True)
        output, sidecar = Path(result["output"]), Path(result["dyn"])
        report = output.with_suffix(".pack.json")
        original = {file: file.read_bytes() for file in (output, sidecar, report)}
        replace = os.replace

        def FailReport(source, destination):
            if destination == report:
                raise OSError("simulated report install failure")
            replace(source, destination)

        Image.new("RGBA", (16, 16), "blue").save(self.source / "body/body-0.png")
        with patch.object(pack_anim.os, "replace", side_effect=FailReport):
            with self.assertRaisesRegex(OSError, "simulated report"):
                self.Pack(dynamic=True, overwrite=True, name="changed")
        self.assertEqual({file: file.read_bytes() for file in original}, original)
        self.assertFalse((self.folder / ".pack-anim.lock").exists())

    def test_refuses_dynamic_and_input_outputs(self):
        with self.assertRaisesRegex(ValueError, "protected"):
            self.Pack(output=ROOT / "anim/dynamic/test_blocked.zip")
        with self.assertRaisesRegex(ValueError, "inside"):
            self.Pack(output=self.source / "output.zip")

    def test_missing_visible_sprite(self):
        self.build["symbols"][0]["name"] = "missing"
        self.Save()
        with self.assertRaisesRegex(ValueError, "Missing visible sprite"):
            self.Pack()

    def test_canvas_mismatch(self):
        self.build["symbols"][0]["frames"][0]["width"] = 17
        self.Save()
        with self.assertRaisesRegex(ValueError, "Canvas mismatch"):
            self.Pack()

    def test_rejects_non_unit_export_scale(self):
        self.build["scale"] = 0.5
        self.Save()
        with self.assertRaisesRegex(ValueError, "scale must be 1"):
            self.Pack()

    def test_transparent_sprite(self):
        Image.new("RGBA", (16, 16)).save(self.source / "body/body-1.png")
        self.build["symbols"][0]["frames"].append(dict(self.build["symbols"][0]["frames"][0], frameNum=1))
        self.Save()
        result = self.Pack()
        self.assertEqual(dstanim.Build(result["output"]).FindFrame(dstanim.StringHash("body"), 1).vert_count, 0)

    def test_new_art_in_empty_metadata_frame(self):
        (self.source / "empty").mkdir()
        Image.new("RGBA", (16, 16), "white").save(self.source / "empty/empty-0.png")
        result = self.Pack()
        self.assertEqual(result["sprites"], 2)

    def test_reject_duplicate_symbols_and_frames(self):
        self.build["symbols"].append(copy.deepcopy(self.build["symbols"][0]))
        self.Save()
        with self.assertRaisesRegex(ValueError, "Duplicate symbol"):
            self.Pack()
        self.build["symbols"].pop()
        self.build["symbols"][0]["frames"].append(copy.deepcopy(self.build["symbols"][0]["frames"][0]))
        self.Save()
        with self.assertRaisesRegex(ValueError, "Overlapping"):
            self.Pack()

    def test_multiple_atlases(self):
        self.build["symbols"] = [dict(name="body", frames=[])]
        for i in range(6):
            self.build["symbols"][0]["frames"].append(dict(frameNum=i, duration=1, x=0, y=0,
                                                          width=48, height=48, vertNum=6))
            Image.new("RGBA", (48, 48), (200, 100, 50, 255)).save(self.source / f"body/body-{i}.png")
        self.Save()
        result = self.Pack()
        self.assertEqual(len(result["atlases"]), 6)
        dynamic = self.Pack(output=self.folder / "dynamic.zip", dynamic=True)
        build = dstanim.Build(dynamic["output"])
        self.assertEqual(len(build.atlases), 6)
        for index in range(len(build.atlases)):
            self.assertEqual(build.Atlas(index).getpixel((4, 4)), (200, 100, 50, 255))

    def test_facing_suffixes_and_literal_mode(self):
        base = self.animation["banks"][0]["animations"][0]
        self.animation["banks"][0]["animations"] = [dict(base, name="loop_" + suffix) for suffix in dstanim.FACING_BYTES]
        self.Save()
        result = self.Pack()
        animations, _ = dstanim.ReadAnim(result["output"])
        self.assertEqual({a.facing for a in animations}, set(dstanim.FACING_BYTES.values()))
        self.assertTrue(all(a.name == "loop" for a in animations))
        result = self.Pack(output=self.folder / "literal.zip", literal_names=True)
        animations, _ = dstanim.ReadAnim(result["output"])
        self.assertTrue(all(a.name.startswith("loop_") and a.facing == 255 for a in animations))

    def test_unsafe_zip_paths(self):
        archive = self.folder / "unsafe.zip"
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr("../build.json", "{}")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            pack_anim.Source(archive)

    def test_rejects_compiled_zip_as_source(self):
        result = self.Pack()
        with self.assertRaisesRegex(ValueError, "build.json"):
            pack_anim.Source(result["output"])

    def test_ghost_alias_uses_approved_source(self):
        self.assertEqual(pack_anim.ResolveSource("ghost_kiritzuka_build"),
                         ROOT / "workspace/kiritzuka_ghost_design/build")


if __name__ == "__main__":
    unittest.main()
