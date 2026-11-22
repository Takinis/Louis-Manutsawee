#!/usr/bin/env python3
"""Compile editable animation exports into verified DST animation packages."""
import argparse
import hashlib
import io
import json
import math
import os
import shutil
import struct
import sys
import uuid
import zipfile
from datetime import datetime
from pathlib import Path, PurePosixPath

import numpy as np
from PIL import Image

import dstanim

ROOT = Path(__file__).resolve().parent.parent


def Digest(data):
    return hashlib.sha256(data).hexdigest()


def SafeName(name):
    if not isinstance(name, str) or name in ("", ".", "..") or any(c in name for c in "/\\\0"):
        raise ValueError(f"Invalid resource name: {name!r}")
    return name


def Integer(value, label, minimum=0):
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= 0xFFFFFFFF:
        raise ValueError(f"{label} must be an integer >= {minimum}")
    return value


def Numbers(values):
    result = tuple(float(v) for v in values)
    if not all(math.isfinite(v) for v in result):
        raise ValueError("Non-finite animation/build coordinate")
    return result


class Source:
    """Read a directory or a single-root source ZIP without extracting files."""
    def __init__(self, path):
        self.path = Path(path).resolve()
        self.zip = None
        self.prefix = ""
        self.hashes = {}
        self.archive_hash = None
        if self.path.is_dir():
            if not (self.path / "build.json").is_file():
                raise ValueError(f"No build.json in {self.path}")
        elif self.path.is_file() and zipfile.is_zipfile(self.path):
            self.archive_hash = Digest(self.path.read_bytes())
            self.zip = zipfile.ZipFile(self.path)
            names = self.zip.namelist()
            if len(names) != len(set(names)):
                self.close()
                raise ValueError("Duplicate source ZIP entries")
            for name in names:
                p = PurePosixPath(name)
                if p.is_absolute() or ".." in p.parts or "\\" in name:
                    self.close()
                    raise ValueError(f"Unsafe source ZIP path: {name}")
            roots = [n for n in names if PurePosixPath(n).name == "build.json" and not n.startswith("__MACOSX/")]
            if len(roots) != 1:
                self.close()
                raise ValueError("Source ZIP must contain exactly one build.json (compiled ZIPs are not sources)")
            self.prefix = roots[0][:-len("build.json")]
        else:
            raise ValueError(f"Source not found or not a source ZIP: {self.path}")

    def close(self):
        if self.zip is not None:
            self.zip.close()

    def exists(self, relative):
        if self.zip is not None:
            return self.prefix + relative in self.zip.namelist()
        file = (self.path / relative).resolve()
        if not file.is_relative_to(self.path):
            raise ValueError(f"Source symlink escapes its directory: {relative}")
        return file.is_file()

    def read(self, relative):
        if not self.exists(relative):
            raise ValueError(f"Missing source file: {relative}")
        data = self.zip.read(self.prefix + relative) if self.zip is not None else (self.path / relative).read_bytes()
        self.hashes[relative] = Digest(data)
        return data

    def verify_unchanged(self):
        if self.zip is not None:
            if Digest(self.path.read_bytes()) != self.archive_hash:
                raise ValueError("Source ZIP changed during packing")
        else:
            for relative, digest in self.hashes.items():
                if Digest((self.path / relative).read_bytes()) != digest:
                    raise ValueError(f"Source changed during packing: {relative}")


def ResolveSource(value):
    candidate = Path(value).expanduser()
    if candidate.exists():
        return candidate.resolve()
    alias_file = ROOT / "tools/pack_anim_sources.json"
    aliases = json.loads(alias_file.read_text()) if alias_file.exists() else {}
    if value in aliases:
        return (ROOT / aliases[value]).resolve()
    return (ROOT / "exported" / value).resolve()


def PackBuild(build):
    output = io.BytesIO()
    write = output.write

    def Text(value):
        raw = value.encode("utf-8")
        write(struct.pack("<I", len(raw)) + raw)

    symbols = sorted(build["symbols"], key=lambda s: dstanim.StringHash(s["name"]))
    write(struct.pack("<4sIII", b"BILD", 6, len(symbols), sum(len(s["frames"]) for s in symbols)))
    Text(build["name"])
    write(struct.pack("<I", len(build["atlases"])))
    for name in build["atlases"]:
        Text(name)
    for symbol in symbols:
        write(struct.pack("<II", dstanim.StringHash(symbol["name"]), len(symbol["frames"])))
        for frame in symbol["frames"]:
            write(struct.pack("<II4fII", frame["frameNum"], frame["duration"],
                              *[frame[k] for k in ("x", "y", "width", "height")],
                              frame["vertIdx"], frame["vertNum"]))
    write(struct.pack("<I", len(build["verts"])))
    for vertex in build["verts"]:
        write(struct.pack("<6f", *vertex))
    write(struct.pack("<I", len(symbols)))
    for symbol in symbols:
        write(struct.pack("<I", dstanim.StringHash(symbol["name"])))
        Text(symbol["name"])
    return output.getvalue()


def PackAnimation(data, literal_names=False):
    if data.get("version") != 4:
        raise ValueError("Only anim.json version 4 is supported")
    animations, hashes, seen = [], {}, set()

    def Named(name):
        if not isinstance(name, str):
            raise ValueError("Animation names, symbols and layers must be strings")
        key = dstanim.StringHash(name)
        if key in hashes and hashes[key].lower() != name.lower():
            raise ValueError(f"Animation hash collision: {name}")
        hashes[key] = name
        return key

    for bank in data["banks"]:
        bank_hash = Named(bank["name"])
        for item in bank["animations"]:
            name, facing = item["name"], item.get("facing", 255)
            if "facing" not in item and not literal_names:
                for suffix, mask in sorted(dstanim.FACING_BYTES.items(), key=lambda p: -len(p[0])):
                    if name.endswith("_" + suffix):
                        name, facing = name[:-len(suffix) - 1], mask
                        break
            Integer(facing, "facing", 1)
            if facing > 255 or not name:
                raise ValueError("Invalid animation name/facing")
            key = (bank_hash, name, facing)
            if key in seen:
                raise ValueError(f"Duplicate animation variant: {key}")
            seen.add(key)
            rate = Numbers([item["frameRate"]])[0]
            if rate <= 0:
                raise ValueError("Animation frameRate must be positive")
            frames = []
            for frame in item["frames"]:
                events = []
                for event in frame.get("events", []):
                    if isinstance(event, dict):
                        event = event["name"]
                    events.append(Named(event) if isinstance(event, str) else Integer(event, "event hash"))
                elements = []
                for e in sorted(frame["elements"], key=lambda e: e["zIndex"]):
                    elements.append(dstanim.Element(Named(e["symbol"]), Integer(e["frameNum"], "frameNum"),
                        Named(e["layerName"]), *Numbers(e[k] for k in ("a", "b", "c", "d", "tx", "ty", "zIndex"))))
                frames.append(dstanim.Frame(Numbers(frame[k] for k in ("x", "y", "width", "height")), events, elements))
            if not frames:
                raise ValueError(f"Animation has no frames: {name}")
            animations.append(dstanim.Animation(name, facing, bank_hash, rate, frames))
    return dstanim.PackAnim(animations, hashes), animations


def EncodeTexture(image, codec):
    if codec == "dxt5":
        sys.path.insert(0, str(ROOT / "tools/bigportrait"))
        from bigportrait import EncodeTex
        return EncodeTex(image)
    mips = [image.convert("RGBA")]
    while mips[-1].width > 1 or mips[-1].height > 1:
        current = mips[-1]
        mips.append(current.resize((max(1, current.width // 2), max(1, current.height // 2)), Image.Resampling.LANCZOS))
    flags = 0xFFFC0000 | (4 << 4) | (1 << 9) | (len(mips) << 13)
    header, bodies = struct.pack("<4sI", b"KTEX", flags), []
    for mip in mips:
        pixels = np.array(mip.transpose(Image.Transpose.FLIP_TOP_BOTTOM))
        pixels[:, :, :3] = ((pixels[:, :, :3].astype(np.uint16) * pixels[:, :, 3:4] + 127) // 255).astype(np.uint8)
        body = pixels.tobytes()
        header += struct.pack("<HHHI", mip.width, mip.height, mip.width * 4, len(body))
        bodies.append(body)
    return header + b"".join(bodies)


def Compile(source, name=None, atlas_size=2048, codec="dxt5", build_only=False, literal_names=False):
    if atlas_size < 64 or atlas_size > 4096 or atlas_size & (atlas_size - 1):
        raise ValueError("Atlas size must be a power of two between 64 and 4096")
    if codec not in ("rgba", "dxt5"):
        raise ValueError("Unknown texture format")
    build = json.loads(source.read("build.json"))
    if build.get("version") != 6:
        raise ValueError("Only build.json version 6 is supported")
    if build.get("scale", 1) != 1:
        raise ValueError("Export scale must be 1; non-unit export scaling is not supported")
    build["name"] = SafeName(name or build["name"])
    build["verts"] = []
    sprites, hashes, frames_total = [], set(), 0
    for symbol in build["symbols"]:
        symbol_name = SafeName(symbol["name"])
        key = dstanim.StringHash(symbol_name)
        if key in hashes:
            raise ValueError(f"Duplicate symbol/hash: {symbol_name}")
        hashes.add(key)
        previous_end = -1
        symbol["frames"].sort(key=lambda f: f["frameNum"])
        for frame in symbol["frames"]:
            number = Integer(frame["frameNum"], "frameNum")
            duration = Integer(frame["duration"], "duration", 1)
            if number < previous_end:
                raise ValueError(f"Overlapping frame durations: {symbol_name}/{number}")
            previous_end = number + duration
            Numbers(frame[k] for k in ("x", "y", "width", "height"))
            relative = f"{symbol_name}/{symbol_name}-{number}.png"
            frames_total += 1
            original_vertices = frame.get("vertNum", 0)
            frame["vertIdx"], frame["vertNum"] = 0, 0
            if not source.exists(relative):
                if original_vertices:
                    raise ValueError(f"Missing visible sprite: {relative}")
                continue
            image = Image.open(io.BytesIO(source.read(relative))).convert("RGBA")
            if image.size != (frame["width"], frame["height"]):
                raise ValueError(f"Canvas mismatch: {relative}: {image.size} != {(frame['width'], frame['height'])}")
            box = image.getchannel("A").getbbox()
            if box is None:
                continue
            crop = image.crop(box)
            if crop.width + 8 > atlas_size or crop.height + 8 > atlas_size:
                raise ValueError(f"Sprite exceeds atlas size: {relative}; increase --atlas-size")
            sprites.append({"relative": relative, "box": box, "image": crop, "frame": frame})
    if not sprites:
        raise ValueError("Build has no visible PNG sprites")
    sprites.sort(key=lambda s: (-s["image"].height, -s["image"].width, s["relative"]))
    pages = [[]]
    x = y = 4
    row_height = 0
    for sprite in sprites:
        w, h = sprite["image"].size
        if x + w + 4 > atlas_size:
            x, y, row_height = 4, y + row_height + 8, 0
        if y + h + 4 > atlas_size:
            pages.append([])
            x = y = 4
            row_height = 0
        sprite.update(atlas=len(pages) - 1, x=x, y=y)
        pages[-1].append(sprite)
        x += (w + 11) // 4 * 4
        row_height = max(row_height, h)
    atlases, members = [], {}
    for index, page in enumerate(pages):
        height = 2 ** math.ceil(math.log2(max(s["y"] + s["image"].height + 4 for s in page)))
        atlas = Image.new("RGBA", (atlas_size, height))
        for sprite in page:
            atlas.paste(sprite["image"], (sprite["x"], sprite["y"]))
            f, box = sprite["frame"], sprite["box"]
            w, h = sprite["image"].size
            px, py = f["x"] - f["width"] / 2 + box[0], f["y"] - f["height"] / 2 + box[1]
            ax, ay = sprite["x"], sprite["y"]
            # Optional art stretch about the symbol pivot, independent of its SCML canvas.
            scale_y = Numbers([f.get("artScaleY", 1)])[0]
            if scale_y <= 0:
                raise ValueError("artScaleY must be positive")
            py *= scale_y
            corners = [(px, py, ax / atlas.width, 1 - ay / atlas.height),
                       (px + w, py, (ax + w) / atlas.width, 1 - ay / atlas.height),
                       (px, py + h * scale_y, ax / atlas.width, 1 - (ay + h) / atlas.height),
                       (px + w, py + h * scale_y, (ax + w) / atlas.width, 1 - (ay + h) / atlas.height)]
            f["vertIdx"], f["vertNum"] = len(build["verts"]), 6
            for corner in (0, 1, 2, 1, 3, 2):
                vx, vy, u, v = corners[corner]
                build["verts"].append((vx, vy, 0, u, v, index))
        members[f"atlas-{index}.tex"] = EncodeTexture(atlas, codec)
        atlases.append(atlas)
    build["atlases"] = [f"atlas-{i}.tex" for i in range(len(atlases))]
    members["build.bin"] = PackBuild(build)
    animations = []
    if not build_only and source.exists("anim.json"):
        members["anim.bin"], animations = PackAnimation(json.loads(source.read("anim.json")), literal_names)
    return {"build": build, "members": members, "atlases": atlases, "sprites": sprites,
            "frames": frames_total, "animations": animations, "codec": codec}


def Verify(path, compiled, dynamic=None):
    expected = compiled["build"]
    members = compiled["members"]
    zip_names = set(members)
    if dynamic is not None:
        atlas_names = expected["atlases"]
        zip_names.difference_update(atlas_names)
        with zipfile.ZipFile(io.BytesIO(dstanim.DecodeDyn(dynamic.read_bytes()))) as package:
            if sorted(package.namelist()) != sorted(atlas_names):
                raise ValueError("DYN member verification failed")
            if any(package.read(name) != members[name] for name in atlas_names):
                raise ValueError("DYN atlas verification failed")
    with zipfile.ZipFile(path) as package:
        if package.testzip() is not None or sorted(package.namelist()) != sorted(zip_names):
            raise ValueError("ZIP integrity/member verification failed")
    build = dstanim.Build(path, dynamic_path=dynamic)
    if (build.name != expected["name"] or len(build.symbols) != len(expected["symbols"])
            or build.atlases != expected["atlases"]):
        raise ValueError("Build metadata verification failed")
    for symbol in expected["symbols"]:
        frames = build.symbols[dstanim.StringHash(symbol["name"])]
        if len(frames) != len(symbol["frames"]):
            raise ValueError("Build frame count changed")
        for actual, frame in zip(frames, symbol["frames"]):
            if (actual.num, actual.duration, actual.vert_index, actual.vert_count) != (
                    frame["frameNum"], frame["duration"], frame["vertIdx"], frame["vertNum"]):
                raise ValueError("Build frame metadata changed")
            if not np.allclose(actual.bbox, [frame[k] for k in ("x", "y", "width", "height")], atol=1e-5):
                raise ValueError("Build anchors changed")
    if not np.allclose(np.asarray(build.verts).reshape(-1, 6), expected["verts"], atol=1e-5):
        raise ValueError("Build vertices/UVs changed")
    errors = []
    for i, atlas in enumerate(compiled["atlases"]):
        texture = compiled["members"][build.atlases[i]]
        flags = struct.unpack_from("<I", texture, 4)[0]
        mip_count = (flags >> 13) & 31
        end, previous = 8 + mip_count * 10, None
        for level in range(mip_count):
            w, h, pitch, size = struct.unpack_from("<HHHI", texture, 8 + level * 10)
            expected_size = w * h * 4 if compiled["codec"] == "rgba" else ((w + 3) // 4) * ((h + 3) // 4) * 16
            expected_pitch = w * 4 if compiled["codec"] == "rgba" else ((w + 3) // 4) * 16
            if size != expected_size or pitch != expected_pitch or (previous and (w, h) != tuple(max(1, n // 2) for n in previous)):
                raise ValueError("Invalid KTEX mip chain")
            previous, end = (w, h), end + size
        if previous != (1, 1) or end != len(texture):
            raise ValueError("Incomplete KTEX mip chain")
        original = np.array(atlas).astype(np.uint16)
        original[:, :, :3] = (original[:, :, :3] * original[:, :, 3:4] + 127) // 255
        decoded = np.array(build.Atlas(i)).astype(np.int32)
        difference = np.abs(decoded - original.astype(np.int32))
        mean, maximum = float(difference.mean()), int(difference.max())
        if compiled["codec"] == "rgba" and maximum != 0 or compiled["codec"] == "dxt5" and mean > 4:
            raise ValueError(f"Texture round trip failed: atlas {i}, mean={mean:.3f}, max={maximum}")
        errors.append({"atlas": i, "mean": round(mean, 4), "max": maximum})
    if "anim.bin" in compiled["members"]:
        actual, _ = dstanim.ReadAnim(str(path))
        expected_animations = compiled["animations"]
        if len(actual) != len(expected_animations):
            raise ValueError("Animation metadata verification failed")
        for a, b in zip(actual, expected_animations):
            if (a.name, a.facing, a.root, len(a.frames)) != (b.name, b.facing, b.root, len(b.frames)) or not math.isclose(a.rate, b.rate, rel_tol=1e-6):
                raise ValueError("Animation metadata verification failed")
            for af, bf in zip(a.frames, b.frames):
                if af.events != bf.events or len(af.elements) != len(bf.elements) or not np.allclose(af.bbox, bf.bbox):
                    raise ValueError("Animation frame verification failed")
                for ae, be in zip(af.elements, bf.elements):
                    if (ae.symbol, ae.frame, ae.layer) != (be.symbol, be.frame, be.layer):
                        raise ValueError("Animation symbol reference changed")
                    if not np.allclose([getattr(ae, k) for k in ("a", "b", "c", "d", "tx", "ty", "z")],
                                       [getattr(be, k) for k in ("a", "b", "c", "d", "tx", "ty", "z")]):
                        raise ValueError("Animation transform changed")
    return errors


def WriteZip(path, members, compression=zipfile.ZIP_DEFLATED):
    with zipfile.ZipFile(path, "w", compression) as package:
        for name in sorted(members):
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = compression
            package.writestr(info, members[name])


def CheckDestinations(destinations, overwrite):
    for destination in destinations:
        if destination.is_dir():
            raise IsADirectoryError(f"Output is a directory: {destination}")
        if (destination.exists() or destination.is_symlink()) and not overwrite:
            raise FileExistsError(f"Output already exists: {destination}; use --overwrite to back up and replace")


def InstallFiles(staged, overwrite):
    directory = next(iter(staged)).parent
    lock = directory / ".pack-anim.lock"
    try:
        handle = lock.open("x")
    except FileExistsError:
        raise FileExistsError(f"Output directory is locked: {lock}") from None
    try:
        CheckDestinations(staged, overwrite)
        backups = {}
        for destination in staged:
            if destination.exists() or destination.is_symlink():
                backup_dir = directory / ".pack-backups"
                backup_dir.mkdir(exist_ok=True)
                stamp = datetime.now().strftime("%Y%m%dT%H%M%S%f")
                backup = backup_dir / f"{destination.name}.{stamp}.{uuid.uuid4().hex[:8]}"
                shutil.copy2(destination, backup, follow_symlinks=False)
                backups[destination] = backup
        installed = []
        try:
            for destination, pending in staged.items():
                os.replace(pending, destination)
                installed.append(destination)
        except BaseException:
            for destination in reversed(installed):
                os.replace(destination, staged[destination])
                if destination in backups:
                    os.replace(backups[destination], destination)
            raise
    finally:
        handle.close()
        lock.unlink()


def Pack(source_path, output=None, name=None, codec="dxt5", atlas_size=2048,
         build_only=False, literal_names=False, overwrite=False, source_zip=False, dynamic=False):
    source = Source(source_path)
    try:
        build_name = SafeName(name or json.loads(source.read("build.json"))["name"])
        default_dir = ROOT / ("anim/dynamic" if dynamic else "anim")
        output = Path(output).expanduser().resolve() if output else default_dir / f"{build_name}.zip"
        if output.suffix.lower() != ".zip":
            raise ValueError("Output must be a .zip path")
        if not dynamic and (ROOT / "anim/dynamic") in output.parents:
            raise ValueError("Dynamic ZIP/DYN paths are protected; use --dynamic")
        report_file = output.with_suffix(".pack.json")
        editable_file = output.with_name(output.stem + "-source.zip")
        dynamic_file = output.with_suffix(".dyn") if dynamic else None
        destinations = [output]
        if dynamic_file is not None:
            destinations.append(dynamic_file)
        destinations.append(report_file)
        if source_zip:
            destinations.append(editable_file)
        for file in destinations:
            resolved = file.resolve()
            if resolved == source.path or source.path.is_dir() and resolved.is_relative_to(source.path):
                raise ValueError("Output must not replace or be placed inside the input")
        CheckDestinations(destinations, overwrite)
        compiled = Compile(source, name, atlas_size, codec, build_only, literal_names)
        output.parent.mkdir(parents=True, exist_ok=True)
        staged = {file: file.with_name(file.name + ".pending-" + uuid.uuid4().hex) for file in destinations}
        members = compiled["members"]
        if dynamic_file is not None:
            textures = {name: members[name] for name in compiled["build"]["atlases"]}
            archive = io.BytesIO()
            WriteZip(archive, textures, zipfile.ZIP_STORED)
            staged[dynamic_file].write_bytes(dstanim.EncodeDyn(archive.getvalue()))
            members = {name: data for name, data in members.items() if name not in textures}
        WriteZip(staged[output], members)
        errors = Verify(staged[output], compiled, staged.get(dynamic_file))
        if source_zip:
            if source.exists("anim.json") and "anim.json" not in source.hashes:
                source.read("anim.json")
            editable = {relative: source.read(relative) for relative in list(source.hashes)}
            WriteZip(staged[editable_file], editable)
        source.verify_unchanged()
        report = {"source": str(source.path), "output": str(output), "build": compiled["build"]["name"],
                  "format": codec, "atlases": [list(image.size) for image in compiled["atlases"]],
                  "symbols": len(compiled["build"]["symbols"]), "frames": compiled["frames"],
                  "sprites": len(compiled["sprites"]), "animations": len(compiled["animations"]),
                  "roundTrip": errors, "sourceHashes": source.hashes,
                  "zipHash": Digest(staged[output].read_bytes()), "verified": True}
        if dynamic_file is not None:
            report.update(dyn=str(dynamic_file), dynHash=Digest(staged[dynamic_file].read_bytes()))
        staged[report_file].write_text(json.dumps(report, indent=2) + "\n")
        InstallFiles(staged, overwrite)
        return report
    finally:
        source.close()


def Main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="export name, export directory or editable source ZIP")
    parser.add_argument("-o", "--output", help="output ZIP path (default: anim/<build-name>.zip)")
    parser.add_argument("--dynamic", action="store_true", help="write a ZIP/DYN pair (default directory: anim/dynamic)")
    parser.add_argument("--name", help="override the build name")
    parser.add_argument("--format", choices=("dxt5", "rgba"), default="dxt5", help="texture format (default: dxt5)")
    parser.add_argument("--atlas-size", type=int, default=2048)
    parser.add_argument("--build-only", action="store_true", help="omit anim.bin even when anim.json exists")
    parser.add_argument("--literal-names", action="store_true", help="do not interpret _down/_side/etc. animation suffixes")
    parser.add_argument("--source-zip", action="store_true", help="also save an editable source ZIP")
    parser.add_argument("--overwrite", action="store_true", help="back up existing outputs before replacing them")
    args = parser.parse_args()
    try:
        report = Pack(ResolveSource(args.source), args.output, args.name, args.format, args.atlas_size,
                      args.build_only, args.literal_names, args.overwrite, args.source_zip, dynamic=args.dynamic)
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        parser.exit(1, f"pack_anim: {error}\n")
    print(f"Packed: {report['output']}")
    if args.dynamic:
        print(f"Packed: {report['dyn']}")
    print(f"Build: {report['build']} | {report['sprites']} sprites | {len(report['atlases'])} atlases | {report['format']}")
    packages = "ZIP and DYN" if args.dynamic else "ZIP"
    print(f"Verified: {packages}, frame anchors, vertices, mipmaps, texture round trip and source preservation")


if __name__ == "__main__":
    Main()
