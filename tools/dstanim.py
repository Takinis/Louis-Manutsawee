#!/usr/bin/env python3
"""Read, render and write Don't Starve Together animation packages.

Works straight from the packed zips, so what it draws uses the same frames, vertices and atlas
the game does. Rendering needs Pillow; reading and writing do not.

    dstanim.py list <anim.zip>
    dstanim.py show <anim.zip> <animation> <frame>
    dstanim.py render <anim.zip> <animation> <frame> <out.png> --build <build.zip> [--weapon <swap.zip>]
"""
import argparse
import io
import os
import struct
import sys
import zipfile
from pathlib import Path

FACINGS = {8: "down", 192: "downside", 5: "side", 48: "upside", 2: "up"}
FACING_BYTES = {name: byte for byte, name in FACINGS.items()}
# What the game has hidden on a player holding a weapon with no hat on.
PLAYER_HIDDEN_LAYERS = {"arm_normal", "hat", "hair_hat", "head_hat", "head_hat_nohelm", "head_hat_helm"}

# DYN block layout used by dont-starve-anim-tool (src/lib/kfiles/dyn.ts).
DYN_BYTE_ORDER = (5, 3, 6, 7, 4, 2, 0, 1)
DYN_XOR_TABLES = tuple(bytes(value ^ key for value in range(256)) for key in range(0x8D, 0x95))


def _TransformDyn(data, encode):
    size = len(DYN_BYTE_ORDER)
    # The final block stays unchanged, even when it is exactly eight bytes long.
    end = max(0, (len(data) - 1) // size * size)
    result = bytearray(data)
    for index, permuted in enumerate(DYN_BYTE_ORDER):
        source, target = (index, permuted) if encode else (permuted, index)
        result[target:end:size] = data[source:end:size].translate(DYN_XOR_TABLES[index])
    return bytes(result)


def EncodeDyn(zip_data):
    return _TransformDyn(zip_data, encode=True)


def DecodeDyn(data):
    if data.startswith(b"PK"):
        return data
    return _TransformDyn(data, encode=False)


def StringHash(text):
    value = 0
    for char in text.lower().encode():
        value = (value * 65599 + char) & 0xFFFFFFFF
    return value


class Element:
    __slots__ = ("symbol", "frame", "layer", "a", "b", "c", "d", "tx", "ty", "z")

    def __init__(self, symbol, frame, layer, a, b, c, d, tx, ty, z):
        self.symbol, self.frame, self.layer = symbol, frame, layer
        self.a, self.b, self.c, self.d, self.tx, self.ty, self.z = a, b, c, d, tx, ty, z

    def Copy(self):
        return Element(self.symbol, self.frame, self.layer, self.a, self.b, self.c, self.d, self.tx, self.ty, self.z)


class Frame:
    def __init__(self, bbox, events, elements):
        self.bbox, self.events, self.elements = bbox, events, elements


class Animation:
    def __init__(self, name, facing, root, rate, frames):
        self.name, self.facing, self.root, self.rate, self.frames = name, facing, root, rate, frames

    def FullName(self):
        return self.name + "_" + FACINGS.get(self.facing, str(self.facing))


def ReadZip(path, member):
    with zipfile.ZipFile(path) as package:
        return package.read(member)


def ReadAnim(path):
    """Returns the animations and the hash table that names their symbols and layers."""
    data = ReadZip(path, "anim.bin")
    magic, version = struct.unpack_from("<4sI", data, 0)
    if magic != b"ANIM":
        raise ValueError(path + " is not an animation package")
    count = struct.unpack_from("<I", data, 20)[0]
    offset, animations = 24, []
    for _ in range(count):
        length = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        name = data[offset:offset + length].decode()
        offset += length
        facing = data[offset]
        root, rate, frame_count = struct.unpack_from("<IfI", data, offset + 1)
        offset += 13
        frames = []
        for _ in range(frame_count):
            bbox = struct.unpack_from("<4f", data, offset)
            offset += 16
            event_count = struct.unpack_from("<I", data, offset)[0]
            offset += 4
            events = list(struct.unpack_from("<%dI" % event_count, data, offset))
            offset += event_count * 4
            element_count = struct.unpack_from("<I", data, offset)[0]
            offset += 4
            elements = []
            for _ in range(element_count):
                elements.append(Element(*struct.unpack_from("<3I7f", data, offset)))
                offset += 40
            frames.append(Frame(bbox, events, elements))
        animations.append(Animation(name, facing, root, rate, frames))
    hash_count = struct.unpack_from("<I", data, offset)[0]
    offset += 4
    hashes = {}
    for _ in range(hash_count):
        key, length = struct.unpack_from("<II", data, offset)
        offset += 8
        hashes[key] = data[offset:offset + length].decode(errors="replace")
        offset += length
    return animations, hashes


def PackAnim(animations, hashes, version=4):
    used = set()
    out = io.BytesIO()
    element_total = frame_total = event_total = 0
    for animation in animations:
        frame_total += len(animation.frames)
        for frame in animation.frames:
            element_total += len(frame.elements)
            event_total += len(frame.events)
    out.write(struct.pack("<4sIIIII", b"ANIM", version, element_total, frame_total, event_total, len(animations)))
    for animation in animations:
        name = animation.name.encode()
        out.write(struct.pack("<I", len(name)) + name)
        out.write(struct.pack("<BIfI", animation.facing, animation.root, animation.rate, len(animation.frames)))
        used.add(animation.root)
        for frame in animation.frames:
            out.write(struct.pack("<4f", *frame.bbox))
            out.write(struct.pack("<I", len(frame.events)))
            for event in frame.events:
                out.write(struct.pack("<I", event))
                used.add(event)
            out.write(struct.pack("<I", len(frame.elements)))
            for e in frame.elements:
                out.write(struct.pack("<3I7f", e.symbol, e.frame, e.layer, e.a, e.b, e.c, e.d, e.tx, e.ty, e.z))
                used.add(e.symbol)
                used.add(e.layer)
    named = sorted(key for key in used if key in hashes)
    out.write(struct.pack("<I", len(named)))
    for key in named:
        text = hashes[key].encode()
        out.write(struct.pack("<II", key, len(text)) + text)
    return out.getvalue()


def WriteAnimZip(path, animations, hashes):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("anim.bin", PackAnim(animations, hashes))


class BuildFrame:
    def __init__(self, num, duration, bbox, vert_index, vert_count):
        self.num, self.duration, self.bbox = num, duration, bbox
        self.vert_index, self.vert_count = vert_index, vert_count


class Build:
    def __init__(self, path, dynamic_path=None):
        self.path = path
        self.dynamic_path = Path(dynamic_path) if dynamic_path is not None else None
        self._dynamic_data = None
        data = ReadZip(path, "build.bin")
        self.version, symbol_count = struct.unpack_from("<4xII", data, 0)
        length = struct.unpack_from("<I", data, 16)[0]
        self.name = data[20:20 + length].decode()
        offset = 20 + length
        atlas_count = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        self.atlases = []
        for _ in range(atlas_count):
            length = struct.unpack_from("<I", data, offset)[0]
            offset += 4
            self.atlases.append(data[offset:offset + length].decode())
            offset += length
        self.symbols = {}
        for _ in range(symbol_count):
            symbol, frame_count = struct.unpack_from("<II", data, offset)
            offset += 8
            frames = []
            for _ in range(frame_count):
                num, duration = struct.unpack_from("<II", data, offset)
                bbox = struct.unpack_from("<4f", data, offset + 8)
                vert_index, vert_count = struct.unpack_from("<II", data, offset + 24)
                offset += 32
                frames.append(BuildFrame(num, duration, bbox, vert_index, vert_count))
            self.symbols[symbol] = frames
        total = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        self.verts = list(struct.unpack_from("<%df" % (total * 6), data, offset))
        self.tail = data[offset + total * 24:]
        self.images = {}

    def Pack(self):
        out = io.BytesIO()
        frame_total = sum(len(frames) for frames in self.symbols.values())
        out.write(struct.pack("<4sIII", b"BILD", self.version, len(self.symbols), frame_total))
        name = self.name.encode()
        out.write(struct.pack("<I", len(name)) + name)
        out.write(struct.pack("<I", len(self.atlases)))
        for atlas in self.atlases:
            text = atlas.encode()
            out.write(struct.pack("<I", len(text)) + text)
        for symbol, frames in self.symbols.items():
            out.write(struct.pack("<II", symbol, len(frames)))
            for frame in frames:
                out.write(struct.pack("<II4fII", frame.num, frame.duration, *frame.bbox, frame.vert_index, frame.vert_count))
        out.write(struct.pack("<I", len(self.verts) // 6))
        out.write(struct.pack("<%df" % len(self.verts), *self.verts))
        out.write(self.tail)
        return out.getvalue()

    def Save(self):
        """Writes the build back into its package, leaving the other members as they are."""
        with zipfile.ZipFile(self.path) as package:
            members = {name: package.read(name) for name in package.namelist()}
        members["build.bin"] = self.Pack()
        with zipfile.ZipFile(self.path, "w", zipfile.ZIP_DEFLATED) as package:
            for name, data in members.items():
                package.writestr(name, data)

    def FindFrame(self, symbol, num):
        """The frame showing at num: the last one starting at or before it, held for its duration."""
        best = None
        for frame in self.symbols.get(symbol, ()):
            if frame.num <= num and (best is None or frame.num > best.num):
                best = frame
        return best

    def Atlas(self, index):
        if index not in self.images:
            name = self.atlases[index]
            try:
                texture = ReadZip(self.path, name)
            except KeyError:
                if self._dynamic_data is None:
                    path = self.dynamic_path or Path(self.path).with_suffix(".dyn")
                    if self.dynamic_path is None and not path.is_file():
                        raise
                    self._dynamic_data = DecodeDyn(path.read_bytes())
                texture = ReadZip(io.BytesIO(self._dynamic_data), name)
            self.images[index] = DecodeTex(texture)
        return self.images[index]


def DecodeBlock(data, offset, palette_only, pixels, px, py, width, height, alpha):
    c0, c1, bits = struct.unpack_from("<HHI", data, offset)
    colours = []
    for value in (c0, c1):
        colours.append((((value >> 11) & 31) * 255 // 31, ((value >> 5) & 63) * 255 // 63, (value & 31) * 255 // 31))
    a, b = colours
    if palette_only or c0 > c1:
        colours.append(tuple((2 * x + y) // 3 for x, y in zip(a, b)))
        colours.append(tuple((x + 2 * y) // 3 for x, y in zip(a, b)))
    else:
        colours.append(tuple((x + y) // 2 for x, y in zip(a, b)))
        colours.append((0, 0, 0))
    for y in range(4):
        row = py + y
        if row >= height:
            break
        for x in range(4):
            column = px + x
            if column >= width:
                continue
            colour = colours[(bits >> (2 * (y * 4 + x))) & 3]
            index = (row * width + column) * 4
            pixels[index:index + 3] = bytes(colour)
            if alpha is not None:
                pixels[index + 3] = alpha[y * 4 + x]
            elif not palette_only and c0 <= c1 and ((bits >> (2 * (y * 4 + x))) & 3) == 3:
                pixels[index + 3] = 0
            else:
                pixels[index + 3] = 255


def DecodeTex(data):
    """Decodes the top mip of a KTEX atlas into an RGBA image, right way up."""
    from PIL import Image

    if data[:4] != b"KTEX":
        raise ValueError("Not a KTEX texture")
    flags = struct.unpack_from("<I", data, 4)[0]
    pixel_format, mip_count = (flags >> 4) & 31, (flags >> 13) & 31
    offset = 8
    width, height, _, size = struct.unpack_from("<HHHI", data, offset)
    offset = 8 + mip_count * 10
    body = data[offset:offset + size]
    pixels = bytearray(width * height * 4)
    if pixel_format == 4:
        pixels[:] = body
    else:
        block = 8 if pixel_format == 0 else 16
        at = 0
        for py in range(0, height, 4):
            for px in range(0, width, 4):
                alpha = None
                if pixel_format == 1:
                    raw = int.from_bytes(body[at:at + 8], "little")
                    alpha = [((raw >> (4 * i)) & 15) * 17 for i in range(16)]
                elif pixel_format == 2:
                    a0, a1 = body[at], body[at + 1]
                    raw = int.from_bytes(body[at + 2:at + 8], "little")
                    table = [a0, a1]
                    if a0 > a1:
                        table += [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
                    else:
                        table += [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
                    alpha = [table[(raw >> (3 * i)) & 7] for i in range(16)]
                DecodeBlock(body, at + (0 if pixel_format == 0 else 8), pixel_format != 0, pixels, px, py, width, height, alpha)
                at += block
    return Image.frombytes("RGBA", (width, height), bytes(pixels)).transpose(Image.FLIP_TOP_BOTTOM)


def DrawTriangle(canvas, atlas, tri, element, scale, origin):
    from PIL import Image, ImageDraw

    width, height = atlas.size
    source, target = [], []
    for x, y, _, u, v, _ in tri:
        source.append((u * width, (1 - v) * height))
        target.append(((element.a * x + element.c * y + element.tx) * scale + origin[0],
                       (element.b * x + element.d * y + element.ty) * scale + origin[1]))
    xs, ys = [p[0] for p in target], [p[1] for p in target]
    left, top = int(min(xs)) - 1, int(min(ys)) - 1
    right, bottom = int(max(xs)) + 2, int(max(ys)) + 2
    (x0, y0), (x1, y1), (x2, y2) = target
    det = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
    if abs(det) < 1e-6 or right <= left or bottom <= top:
        return
    (u0, v0), (u1, v1), (u2, v2) = source
    # Screen to atlas, for the output pixels of the crop at (left, top).
    a = ((u1 - u0) * (y2 - y0) - (u2 - u0) * (y1 - y0)) / det
    b = ((u2 - u0) * (x1 - x0) - (u1 - u0) * (x2 - x0)) / det
    d = ((v1 - v0) * (y2 - y0) - (v2 - v0) * (y1 - y0)) / det
    e = ((v2 - v0) * (x1 - x0) - (v1 - v0) * (x2 - x0)) / det
    c = u0 - a * (x0 - left) - b * (y0 - top)
    f = v0 - d * (x0 - left) - e * (y0 - top)
    size = (right - left, bottom - top)
    piece = atlas.transform(size, Image.AFFINE, (a, b, c, d, e, f), Image.BILINEAR)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon([(x - left, y - top) for x, y in target], fill=255)
    empty = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(Image.composite(piece, empty, mask), (max(left, 0), max(top, 0)),
                           (max(-left, 0), max(-top, 0)))


def DrawElement(canvas, build, element, scale, origin):
    frame = build.FindFrame(element.symbol, element.frame)
    if frame is None:
        return False
    verts = build.verts
    for start in range(frame.vert_index, frame.vert_index + frame.vert_count, 3):
        tri = [verts[(start + i) * 6:(start + i) * 6 + 6] for i in range(3)]
        atlas_index = int(tri[0][5])
        DrawTriangle(canvas, build.Atlas(atlas_index if atlas_index < len(build.atlases) else 0), tri, element, scale, origin)
    return True


SWAP_OBJECT = StringHash("swap_object")


def RenderFrame(frame, hashes, build, weapon=None, size=(420, 420), origin=(210, 340), scale=1, background=None,
                hidden=PLAYER_HIDDEN_LAYERS, weapon_symbol=None):
    """Draws one frame. Elements are stored front first, so they go down back to front."""
    from PIL import Image

    canvas = Image.new("RGBA", size, background or (0, 0, 0, 0))
    for element in reversed(frame.elements):
        if hashes.get(element.layer, "").lower() in hidden:
            continue
        if element.symbol == SWAP_OBJECT:
            if weapon is not None:
                override = element.Copy()
                override.symbol = weapon_symbol
                DrawElement(canvas, weapon, override, scale, origin)
            continue
        DrawElement(canvas, build, element, scale, origin)
    return canvas


def FindAnimation(animations, full_name):
    for animation in animations:
        if animation.FullName() == full_name or animation.name == full_name:
            return animation
    raise KeyError(full_name)


def Main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("list", "show", "render"))
    parser.add_argument("package")
    parser.add_argument("animation", nargs="?")
    parser.add_argument("frame", nargs="?", type=int, default=0)
    parser.add_argument("out", nargs="?")
    parser.add_argument("--build")
    parser.add_argument("--weapon")
    args = parser.parse_args()
    animations, hashes = ReadAnim(args.package)
    if args.command == "list":
        for animation in animations:
            print(animation.FullName(), "raw=" + animation.name, "frames=%d" % len(animation.frames),
                  "rate=%g" % animation.rate, "root=" + hashes.get(animation.root, hex(animation.root)))
    elif args.command == "show":
        frame = FindAnimation(animations, args.animation).frames[args.frame]
        print("bbox", frame.bbox, "events", [hashes.get(e, e) for e in frame.events])
        for index, e in enumerate(frame.elements):
            print(index, hashes.get(e.symbol, hex(e.symbol)), e.frame, hashes.get(e.layer, hex(e.layer)),
                  *("%.2f" % v for v in (e.a, e.b, e.c, e.d, e.tx, e.ty, e.z)))
    else:
        build = Build(args.build)
        weapon = Build(args.weapon) if args.weapon else None
        symbol = next(iter(weapon.symbols)) if weapon else None
        RenderFrame(FindAnimation(animations, args.animation).frames[args.frame], hashes, build, weapon,
                    weapon_symbol=symbol, background=(235, 235, 235, 255)).save(args.out)


if __name__ == "__main__":
    sys.exit(Main())
