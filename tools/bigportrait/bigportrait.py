"""Build character-select portraits (bigportraits) for this mod's skins.

A portrait is posed from a skin's exported game textures (exported/<skin>/) and the native
animation transforms, so its proportions match the game. A JSON spec describes the pose; the
commands below render it, help inspect it, and install it into bigportraits/ as PNG, DXT5 TEX
and atlas XML. Run with the pyenv Python that has PIL, numpy and OpenCV:

    ~/.pyenv/versions/3.10.14/bin/python tools/bigportrait/bigportrait.py <command> ...

See tools/bigportrait/README.md for the spec format and the workflow.
"""
import argparse
import copy
import json
import math
import re
import struct
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TOOL = Path(__file__).resolve().parent
ROOT = TOOL.parents[1]
GAME_ANIM = ROOT / "../../data/anim"
EXPORTED = ROOT / "exported"
PORTRAITS = ROOT / "bigportraits"
PLATE = TOOL / "plate.png"
sys.path.insert(0, str(ROOT / "tools"))
import dstanim  # noqa: E402

# Pose canvas: sprites drawn at SCALE with the anim origin (the feet) at ORIGIN.
SIZE = (700, 900)
SCALE = 1.65
ORIGIN = (350, 780)
PORTRAIT_SIZE = (512, 1024)
# Engine layers an empty-handed player hides.
HIDDEN = {"arm_carry", "hat", "hair_hat", "head_hat", "head_hat_nohelm", "head_hat_helm"}
ARM_SYMBOLS = ("arm_upper_skin", "arm_lower", "hand")
BASE_LAYERS = ("legs", "bodice", "skirt", "head")
ARM_DEFAULTS = dict(source=None, upper=0, forearm=0, foreshorten=1.0, elbow_slide=0, hand=None,
                    hand_turn=0, hand_scale=1.0, mirror=False, hand_follows_forearm=False)
PORTRAIT_DEFAULTS = dict(align="body", x=244, feet=572, scale=440 / 530)
# The character-select frame shown in game: the oval part of the 512x1024 sheet.
OVAL_UV = dict(u1="0.0009765625", u2="0.9580078125", v1="0.36181640625", v2="0.99951171875")
# Arm layers that end up mostly hidden usually mean a limb vanished behind the body.
MIN_VISIBLE = {"upper": 0.15, "lower": 0.25, "hand": 0.25}

_ANIMS = {}
_BUILDS = {}


def Fail(message):
    raise SystemExit(f"bigportrait: {message}")


# ---------------------------------------------------------------------------------------------
# Skin textures and native frames


class Skin:
    def __init__(self, name):
        self.name = name
        self.dir = EXPORTED / name
        if not (self.dir / "build.json").exists():
            Fail(f"no export at {self.dir.relative_to(ROOT)} (need build.json and symbol PNGs)")
        self.frames = {}
        for symbol in json.loads((self.dir / "build.json").read_text())["symbols"]:
            for frame in symbol["frames"]:
                if (self.dir / symbol["name"] / f"{symbol['name']}-{frame['frameNum']}.png").exists():
                    self.frames[symbol["name"], frame["frameNum"]] = frame
        self.cache = {}

    def Has(self, symbol, frame=None):
        return any(key[0] == symbol and (frame is None or key[1] == frame) for key in self.frames)

    def Resolve(self, symbol, frame):
        # The build frame shown at an anim frame number: the last one starting at or before it.
        numbers = sorted(key[1] for key in self.frames if key[0] == symbol)
        if not numbers:
            return None
        return max([n for n in numbers if n <= frame] or numbers[:1])

    def Texture(self, symbol, frame):
        if (symbol, frame) not in self.cache:
            self.cache[symbol, frame] = Image.open(self.dir / symbol / f"{symbol}-{frame}.png").convert("RGBA")
        return self.cache[symbol, frame]


def Anim(package):
    if package not in _ANIMS:
        path = GAME_ANIM / package
        if not path.exists():
            Fail(f"no game animation package {package}")
        _ANIMS[package] = dstanim.ReadAnim(str(path))
    return _ANIMS[package]


def NativeFrame(reference):
    """'package.zip:animation:frame' -> (frame, hashes)."""
    try:
        package, name, index = reference.split(":")
    except ValueError:
        Fail(f"frame reference '{reference}' must be package.zip:animation:frame")
    animations, hashes = Anim(package)
    frames = dstanim.FindAnimation(animations, name).frames
    if not 0 <= int(index) < len(frames):
        Fail(f"{name} has {len(frames)} frames")
    return frames[int(index)], hashes


def SymbolName(hashes, element):
    return hashes.get(element.symbol, "").lower()


def Shown(frame, hashes):
    return [e for e in frame.elements if hashes.get(e.layer, "").lower() not in HIDDEN]


def Layer():
    return Image.new("RGBA", SIZE)


def Stamp(canvas, image, a, b, c, d, tx, ty):
    determinant = a * d - b * c
    inverse = (d / determinant, -c / determinant, (c * ty - d * tx) / determinant,
               -b / determinant, a / determinant, (b * tx - a * ty) / determinant)
    canvas.alpha_composite(image.transform(SIZE, Image.Transform.AFFINE, inverse, Image.Resampling.BICUBIC))


def StampFrame(skin, canvas, symbol, frame, element):
    metadata = skin.frames[symbol, frame]
    x = metadata["x"] - metadata["width"] / 2
    y = metadata["y"] - metadata["height"] / 2
    Stamp(canvas, skin.Texture(symbol, frame),
          element.a * SCALE, element.b * SCALE, element.c * SCALE, element.d * SCALE,
          ORIGIN[0] + SCALE * (element.tx + element.a * x + element.c * y),
          ORIGIN[1] + SCALE * (element.ty + element.b * x + element.d * y))


def Rotate(element, pivot, degrees, scale=1):
    # Turns an anim element clockwise on screen about a pivot in anim units.
    t = math.radians(degrees)
    cos, sin = math.cos(t) * scale, math.sin(t) * scale
    pose = element.Copy()
    pose.a, pose.b = cos * element.a - sin * element.b, sin * element.a + cos * element.b
    pose.c, pose.d = cos * element.c - sin * element.d, sin * element.c + cos * element.d
    dx, dy = element.tx - pivot[0], element.ty - pivot[1]
    pose.tx = pivot[0] + (cos * dx - sin * dy) / scale
    pose.ty = pivot[1] + (sin * dx + cos * dy) / scale
    return pose


def ArmParts(frame, hashes, side):
    # One side's arm in a frame: the forearm on that side (far = left on screen), and the upper
    # arm and hand nearest it.
    shown = Shown(frame, hashes)
    found = {name: [e for e in shown if SymbolName(hashes, e) == name] for name in ARM_SYMBOLS}
    if len(found["arm_lower"]) < 2:
        Fail("frame has fewer than two forearms; pick a frame with both arms visible")
    lower = sorted(found["arm_lower"], key=lambda e: e.tx)[0 if side == "far" else -1]
    pick = lambda name: min(found[name], key=lambda e: (e.tx - lower.tx) ** 2 + (e.ty - lower.ty) ** 2)
    return {"arm_upper_skin": pick("arm_upper_skin"), "arm_lower": lower, "hand": pick("hand")}


def Alpha(image, threshold=24):
    return np.asarray(image)[:, :, 3] > threshold


# ---------------------------------------------------------------------------------------------
# Spec


def LoadSpec(path, overrides=()):
    path = Path(path).resolve()
    spec = json.loads(path.read_text())
    spec["_dir"] = path.parent
    for item in overrides:
        key, _, value = item.partition("=")
        target = spec
        parts = key.split(".")
        for part in parts[:-1]:
            target = target.setdefault(part, {}) if not isinstance(target, list) else target[int(part)]
        try:
            target[parts[-1]] = json.loads(value)
        except json.JSONDecodeError:
            target[parts[-1]] = value
    return spec


def Merge(spec, variant):
    merged = copy.deepcopy({k: v for k, v in spec.items() if k != "_dir"})
    merged["_dir"] = spec["_dir"]
    for key, value in variant.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            for inner, item in value.items():
                if isinstance(item, dict) and isinstance(merged[key].get(inner), dict):
                    merged[key][inner].update(item)
                else:
                    merged[key][inner] = item
        else:
            merged[key] = value
    return merged


# ---------------------------------------------------------------------------------------------
# Composition


def PoseArm(skin, parts, config, shoulder):
    c = dict(ARM_DEFAULTS, **config)
    # Parts from another frame are moved so their shoulder sits on the base pose's shoulder.
    dx, dy = shoulder[0] - parts["arm_upper_skin"].tx, shoulder[1] - parts["arm_upper_skin"].ty
    parts = {name: e.Copy() for name, e in parts.items()}
    for e in parts.values():
        e.tx, e.ty = e.tx + dx, e.ty + dy
    upper = Rotate(parts["arm_upper_skin"], shoulder, c["upper"])
    lower = Rotate(parts["arm_lower"], shoulder, c["upper"])
    hand = Rotate(parts["hand"], shoulder, c["upper"])
    # A bent elbow shows the end of the upper sleeve the straight forearm covered; sliding the
    # forearm down the upper arm lets its rounded end cap that sleeve end again.
    if c["elbow_slide"]:
        length = math.hypot(lower.tx - shoulder[0], lower.ty - shoulder[1])
        ux, uy = (lower.tx - shoulder[0]) / length, (lower.ty - shoulder[1]) / length
        for e in (lower, hand):
            e.tx += ux * c["elbow_slide"]
            e.ty += uy * c["elbow_slide"]
    elbow = (lower.tx, lower.ty)
    shortened = lower.Copy()
    shortened.c, shortened.d = lower.c * c["foreshorten"], lower.d * c["foreshorten"]
    lower = Rotate(shortened, elbow, c["forearm"])
    hand.tx = elbow[0] + (hand.tx - elbow[0]) * c["foreshorten"]
    hand.ty = elbow[1] + (hand.ty - elbow[1]) * c["foreshorten"]
    wrist = Rotate(hand, elbow, c["forearm"])
    grip = parts["hand"].Copy()
    if c["hand_follows_forearm"]:
        grip = Rotate(grip, (grip.tx, grip.ty), c["upper"] + c["forearm"])
    if c["mirror"]:
        grip.a, grip.b = -grip.a, -grip.b
    grip = Rotate(grip, (grip.tx, grip.ty), c["hand_turn"], c["hand_scale"])
    grip.tx, grip.ty = wrist.tx, wrist.ty
    layers = {"upper": Layer(), "lower": Layer(), "hand": Layer()}
    StampFrame(skin, layers["upper"], "arm_upper_skin", skin.Resolve("arm_upper_skin", parts["arm_upper_skin"].frame), upper)
    StampFrame(skin, layers["lower"], "arm_lower", skin.Resolve("arm_lower", parts["arm_lower"].frame), lower)
    number = c["hand"] if c["hand"] is not None else parts["hand"].frame
    if not skin.Has("hand", number):
        Fail(f"{skin.name} has no hand frame {number}; run 'frames {skin.name} hand'")
    StampFrame(skin, layers["hand"], "hand", number, grip)
    return layers


def CleanGroundShadow(pixels, options):
    # Icons drawn on a ground shadow: keep light pixels above a row and their ink outline.
    light = ((pixels[:, :, :3].mean(axis=2) > options.get("light", 150)) & (pixels[:, :, 3] > 20)).astype(np.uint8)
    if "below_row" in options:
        light[options["below_row"]:] = 0
    ink = options.get("ink", 7)
    keep = cv2.dilate(light, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (ink, ink)))
    pixels[:, :, 3] = pixels[:, :, 3] * keep
    return pixels


def Tight(image, threshold):
    bounds = image.getchannel("A").point(lambda value: 255 if value > threshold else 0).getbbox()
    if bounds is None:
        Fail("prop image is empty")
    return image.crop(bounds)


def Prop(spec, prop, layers):
    """A drawn prop placed on the pose canvas.

    box: [x, y, w, h] stretches it to that box; or fit: [w, h] scales it to fit, with base:
    [x, y] its bottom centre (or at: [x, y] its top left). Options: threshold (alpha cut for the
    tight crop), clean_ground_shadow {light, below_row, ink}, sharpen, contact_shadow {on: layer}.
    """
    pixels = np.array(Image.open(spec["_dir"] / prop["image"]).convert("RGBA"))
    if "clean_ground_shadow" in prop:
        pixels = CleanGroundShadow(pixels, prop["clean_ground_shadow"])
    image = Tight(Image.fromarray(pixels), prop.get("threshold", 12))
    layer = Layer()
    if "box" in prop:
        x, y, w, h = prop["box"]
        image = image.resize((w, h), Image.Resampling.LANCZOS)
        position = (x, y)
    else:
        w, h = prop["fit"]
        ratio = min(w / image.width, h / image.height)
        image = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
        if "base" in prop:
            position = (prop["base"][0] - image.width // 2, prop["base"][1] - image.height)
        else:
            position = tuple(prop["at"])
    if prop.get("sharpen"):
        # Small icons lose their edge when scaled up.
        image = image.filter(ImageFilter.UnsharpMask(radius=1.5, percent=80, threshold=2))
    shadow_spec = prop.get("contact_shadow")
    if shadow_spec:
        # Soft shadow under the prop's base, kept to the surface layer it stands on.
        cx, cy = prop["base"]
        half = image.width * 0.5
        shadow = Image.new("L", SIZE)
        ImageDraw.Draw(shadow).ellipse((cx - half, cy - half * 0.28, cx + half * 0.9, cy + half * 0.14), fill=120)
        shadow = cv2.GaussianBlur(np.asarray(shadow), (0, 0), 3)
        contact = Image.new("RGBA", SIZE, tuple(shadow_spec.get("colour", (52, 40, 34))) + (0,))
        surface = Alpha(layers[shadow_spec["on"]]) if shadow_spec.get("on") else 1
        contact.putalpha(Image.fromarray((shadow * surface).astype(np.uint8)))
        layer.alpha_composite(contact)
    layer.alpha_composite(image, position)
    return layer


def Compose(spec):
    """Returns (layers in draw order, report)."""
    skin = Skin(spec["skin"])
    base, hashes = NativeFrame(spec.get("base", "player_idles.zip:idle_loop_down:0"))
    face = spec.get("face", 15)
    layers = {name: Layer() for name in BASE_LAYERS}
    for element in reversed(base.elements):
        if hashes.get(element.layer, "").lower() in HIDDEN:
            continue
        symbol = SymbolName(hashes, element)
        group = {"leg": "legs", "foot": "legs", "hair": "head", "headbase": "head", "face": "head",
                 "torso": "bodice", "torso_pelvis": "bodice", "skirt": "skirt"}.get(symbol)
        if group is None or not skin.Has(symbol):
            continue
        number = face if symbol == "face" else skin.Resolve(symbol, element.frame)
        StampFrame(skin, layers[group], symbol, number, element)
    head = spec.get("head", {})
    if head.get("tilt"):
        layers["head"] = layers["head"].rotate(head["tilt"], Image.Resampling.BICUBIC,
                                               center=tuple(head.get("pivot", (350, 612))))

    for side in ("far", "near"):
        config = spec.get("arms", {}).get(side, {})
        shoulder = ArmParts(base, hashes, side)["arm_upper_skin"]
        if config.get("source"):
            frame, frame_hashes = NativeFrame(config["source"])
            parts = ArmParts(frame, frame_hashes, side)
        else:
            parts = ArmParts(base, hashes, side)
        for part, image in PoseArm(skin, parts, config, (shoulder.tx, shoulder.ty)).items():
            layers[f"{side}-{part}"] = image

    for prop in spec.get("props", []):
        layers[prop["name"]] = Prop(spec, prop, layers)

    order = spec.get("order") or ["legs", "far-upper", "far-lower", "far-hand", "bodice", "skirt",
                                  "near-upper", "near-lower", "near-hand", "head"] + [p["name"] for p in spec.get("props", [])]
    missing = set(layers) - set(order)
    unknown = set(order) - set(layers)
    if unknown:
        Fail(f"order names unknown layers {sorted(unknown)}; layers are {sorted(layers)}")
    if missing:
        Fail(f"order leaves out layers {sorted(missing)}")
    ordered = {name: layers[name] for name in order}

    report = {"visible": {}, "joints": {}, "warnings": []}
    masks = {name: Alpha(image) for name, image in ordered.items()}
    for i, name in enumerate(order):
        cover = np.zeros(SIZE[::-1], bool)
        for later in order[i + 1:]:
            cover |= masks[later]
        total = int(masks[name].sum())
        report["visible"][name] = round(float((masks[name] & ~cover).sum()) / total, 3) if total else 0
        kind = name.split("-")[-1]
        if kind in MIN_VISIBLE and report["visible"][name] < MIN_VISIBLE[kind] and name not in spec.get("hidden_ok", ()):
            report["warnings"].append(f"{name} is only {report['visible'][name]:.0%} visible")
    joints = spec.get("joints") or [[f"{s}-upper", "bodice"] for s in ("far", "near")] + \
        [[f"{s}-{a}", f"{s}-{b}"] for s in ("far", "near") for a, b in (("upper", "lower"), ("lower", "hand"))]
    for a, b in joints:
        overlap = int((masks[a] & masks[b]).sum())
        report["joints"][f"{a}+{b}"] = overlap
        if overlap <= 10:
            report["warnings"].append(f"{a} and {b} do not touch ({overlap} px)")
    return ordered, report


def Flatten(layers):
    canvas = Layer()
    for image in layers.values():
        canvas.alpha_composite(image)
    return canvas


def Character(canvas):
    # Drops specks of fewer than 12 pixels left by the affine edges, then crops to the figure.
    pixels = np.array(canvas)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(Alpha(canvas).astype(np.uint8), connectivity=8)
    keep = np.isin(labels, [label for label in range(1, count) if stats[label, cv2.CC_STAT_AREA] >= 12])
    pixels[:, :, 3] *= cv2.dilate(keep.astype(np.uint8), np.ones((3, 3), np.uint8))
    character = Image.fromarray(pixels)
    bounds = character.getbbox()
    return character.crop(bounds), bounds


def Portrait(spec, character, bounds):
    settings = dict(PORTRAIT_DEFAULTS, **spec.get("portrait", {}))
    plate = spec["_dir"] / settings["plate"] if "plate" in settings else PLATE
    background = Image.open(plate).convert("RGBA")
    if background.size != PORTRAIT_SIZE:
        Fail(f"plate {plate} must be {PORTRAIT_SIZE[0]}x{PORTRAIT_SIZE[1]}")
    ratio = settings["scale"]
    figure = character.resize((round(character.width * ratio), round(character.height * ratio)), Image.Resampling.LANCZOS)
    if settings["align"] == "box":
        x = settings["x"] - figure.width // 2
    else:
        # The body's centre line (the anim origin) lands on column x, however far a tilted head or
        # raised arm widens one side of the figure.
        x = round(settings["x"] - (ORIGIN[0] - bounds[0]) * ratio)
    placement = (x, settings["feet"] - figure.height)
    background.alpha_composite(figure, placement)
    pixels = np.array(background)
    pixels[pixels[:, :, 3] == 0] = 0
    return Image.fromarray(pixels), placement


# ---------------------------------------------------------------------------------------------
# Texture output


def EncodeDXT5(image):
    """Premultiplied RGBA image -> DXT5 blocks (bounding-box endpoints, nearest indices)."""
    pixels = np.asarray(image, dtype=np.uint8)
    height, width = pixels.shape[:2]
    bh, bw = (height + 3) // 4, (width + 3) // 4
    padded = np.pad(pixels, ((0, bh * 4 - height), (0, bw * 4 - width), (0, 0)), mode="edge")
    blocks = padded.reshape(bh, 4, bw, 4, 4).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 4).astype(np.int32)

    alpha = blocks[:, :, 3]
    a0, a1 = alpha.max(axis=1), alpha.min(axis=1)
    table = np.stack([a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)], axis=1)
    alpha_index = np.abs(alpha[:, :, None] - table[:, None, :]).argmin(axis=2)
    alpha_index[a0 == a1] = 0
    alpha_bits = np.zeros(len(blocks), np.uint64)
    for i in range(16):
        alpha_bits |= alpha_index[:, i].astype(np.uint64) << np.uint64(3 * i)

    rgb = blocks[:, :, :3]
    high, low = rgb.max(axis=1), rgb.min(axis=1)
    inset = (high - low) // 16
    high, low = np.clip(high - inset, 0, 255), np.clip(low + inset, 0, 255)

    def To565(c):
        return ((c[:, 0] * 31 + 127) // 255 << 11) | ((c[:, 1] * 63 + 127) // 255 << 5) | ((c[:, 2] * 31 + 127) // 255)

    def From565(v):
        return np.stack([((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31], axis=1)

    # c0 > c1 selects the four-colour mode; equal endpoints mean a flat block.
    c0, c1 = np.maximum(To565(high), To565(low)), np.minimum(To565(high), To565(low))
    e0, e1 = From565(c0), From565(c1)
    palette = np.stack([e0, e1, (2 * e0 + e1) // 3, (e0 + 2 * e1) // 3], axis=1)
    distance = ((rgb[:, :, None, :] - palette[:, None, :, :]) ** 2).sum(axis=3)
    colour_index = distance.argmin(axis=2)
    colour_index[c0 == c1] = 0
    colour_bits = np.zeros(len(blocks), np.uint64)
    for i in range(16):
        colour_bits |= colour_index[:, i].astype(np.uint64) << np.uint64(2 * i)

    out = bytearray()
    for i in range(len(blocks)):
        out += struct.pack("<BB", a0[i], a1[i]) + int(alpha_bits[i]).to_bytes(6, "little")
        out += struct.pack("<HHI", c0[i], c1[i], int(colour_bits[i]))
    return bytes(out)


def EncodeTex(image):
    """512x1024 RGBA portrait -> KTEX: DXT5, premultiplied, bottom row first, full mip chain."""
    mips = [image.convert("RGBA")]
    while mips[-1].width > 1 or mips[-1].height > 1:
        current = mips[-1]
        mips.append(current.resize((max(1, current.width // 2), max(1, current.height // 2)), Image.Resampling.LANCZOS))
    flags = 0xFFFC0000 | (2 << 4) | (1 << 9) | (len(mips) << 13)
    header, bodies = struct.pack("<4sI", b"KTEX", flags), []
    for mip in mips:
        pixels = np.array(mip.transpose(Image.Transpose.FLIP_TOP_BOTTOM))
        pixels[:, :, :3] = ((pixels[:, :, :3].astype(np.uint16) * pixels[:, :, 3:4] + 127) // 255).astype(np.uint8)
        data = EncodeDXT5(Image.fromarray(pixels))
        header += struct.pack("<HHHI", mip.width, mip.height, (mip.width + 3) // 4 * 16, len(data))
        bodies.append(data)
    return header + b"".join(bodies)


def AtlasXml(name):
    uv = " ".join(f'{key}="{value}"' for key, value in OVAL_UV.items())
    return f'<Atlas><Texture filename="{name}.tex" /><Elements><Element name="{name}_oval.tex" {uv} /></Elements></Atlas>'


def Pack(name):
    png = PORTRAITS / f"{name}.png"
    if not png.exists():
        Fail(f"no {png.relative_to(ROOT)}")
    image = Image.open(png).convert("RGBA")
    if image.size != PORTRAIT_SIZE:
        Fail(f"{png.name} is {image.size}, not {PORTRAIT_SIZE}")
    texture = EncodeTex(image)
    decoded = np.asarray(dstanim.DecodeTex(texture)).astype(int)
    source = np.asarray(image).astype(int)
    premultiplied = source.copy()
    premultiplied[:, :, :3] = (source[:, :, :3] * source[:, :, 3:4] + 127) // 255
    error = float(np.abs(decoded - premultiplied).mean())
    if error > 4:
        Fail(f"DXT5 round trip error {error:.2f} is too high")
    (PORTRAITS / f"{name}.tex").write_bytes(texture)
    (PORTRAITS / f"{name}.xml").write_text(AtlasXml(name))
    return {"tex": f"bigportraits/{name}.tex", "xml": f"bigportraits/{name}.xml", "mean_error": round(error, 2)}


# ---------------------------------------------------------------------------------------------
# Registration in Lua


ASSETS = ROOT / "main/assets.lua"


def SkinFiles():
    return sorted((ROOT / "scripts/prefabs").glob("*_none.lua"))


def Skins():
    """Every CreatePrefabSkin base skin: name -> (lua file, shares portrait with)."""
    found = {}
    for path in SkinFiles():
        text = path.read_text()
        for match in re.finditer(r'CreatePrefabSkin\("([^"]+)", \{(.*?)\n\}\)\)', text, re.S):
            body = match.group(2)
            if 'type = "base"' not in body:
                continue
            share = re.search(r'share_bigportrait_name = "([^"]+)"', body)
            found[match.group(1)] = (path, share.group(1) if share else None)
        # Skins created in a loop over suffixes, like manutsawee_<v>.
        loop = re.search(r'for _, v in ipairs\(\{(.*?)\}\) do\s+table.insert\(prefabs, CreatePrefabSkin\("([a-z_]+)" \.\. v', text, re.S)
        if loop:
            for suffix in re.findall(r'"([^"]+)"', loop.group(1)):
                found[loop.group(2) + suffix] = (path, None)
    return found


def Register(name):
    skins = Skins()
    if name not in skins:
        Fail(f"{name} is not a base skin in scripts/prefabs/*_none.lua")
    for ext in ("png", "tex", "xml"):
        if not (PORTRAITS / f"{name}.{ext}").exists():
            Fail(f"bigportraits/{name}.{ext} is missing; run 'install' or 'pack' first")
    changes = []
    path, share = skins[name]
    if share:
        text = path.read_text()
        block = re.search(r'(CreatePrefabSkin\("%s", \{.*?\n\}\)\))' % re.escape(name), text, re.S).group(1)
        cleaned = re.sub(r'\n    -- No portrait of its own yet\.\n', "\n", block)
        cleaned = re.sub(r'\n    share_bigportrait_name = "[^"]+",', "", cleaned)
        path.write_text(text.replace(block, cleaned))
        changes.append(f"{path.relative_to(ROOT)}: dropped share_bigportrait_name")
    assets = ASSETS.read_text()
    line = f'    Asset("IMAGE", "bigportraits/{name}.tex"),\n    Asset("ATLAS", "bigportraits/{name}.xml"),\n'
    if f'"bigportraits/{name}.tex"' not in assets:
        # After the last bigportrait of the same character, else after the character's base one.
        prefix = name.split("_")[0]
        anchors = list(re.finditer(r'    Asset\("ATLAS", "bigportraits/%s[^"]*\.xml"\),\n' % re.escape(prefix), assets))
        if not anchors:
            Fail(f"no bigportraits/{prefix}*.xml asset in main/assets.lua to place {name} after")
        at = anchors[-1].end()
        ASSETS.write_text(assets[:at] + line + assets[at:])
        changes.append(f"main/assets.lua: added bigportraits/{name}.tex/.xml")
    return changes


# ---------------------------------------------------------------------------------------------
# Inspection helpers


TINTS = {"far": (255, 60, 60), "near": (60, 90, 255)}


def Picture(layers, box=None, tint=False, hide=(), background="#afadab", label=None, zoom=2):
    canvas = Image.new("RGBA", SIZE, background)
    for name, image in layers.items():
        if name in hide:
            continue
        side, _, part = name.partition("-")
        if tint and side in TINTS and part in ("upper", "lower"):
            pixels = np.array(image).astype(float)
            pixels[:, :, :3] = pixels[:, :, :3] * 0.5 + np.array(TINTS[side]) * 0.5
            image = Image.fromarray(pixels.astype(np.uint8))
        canvas.alpha_composite(image)
    if box is None:
        box = Flatten(layers).getbbox()
        box = (box[0] - 12, box[1] - 12, box[2] + 12, box[3] + 12)
    tile = canvas.crop(box)
    tile = tile.resize((tile.width * zoom, tile.height * zoom), Image.Resampling.LANCZOS)
    if label:
        ImageDraw.Draw(tile).text((4, 4), label[:110], fill="black")
    return tile


def Sheet(tiles, columns=None):
    columns = columns or len(tiles)
    rows = math.ceil(len(tiles) / columns)
    w, h = max(t.width for t in tiles), max(t.height for t in tiles)
    sheet = Image.new("RGBA", (columns * (w + 6), rows * (h + 6)), "white")
    for i, tile in enumerate(tiles):
        sheet.paste(tile, (i % columns * (w + 6), i // columns * (h + 6)))
    return sheet


def Box(text):
    return tuple(int(v) for v in text.split(",")) if text else None


# ---------------------------------------------------------------------------------------------
# Commands


def CommandList(args):
    rows = []
    for name, (path, share) in sorted(Skins().items()):
        has = {ext: (PORTRAITS / f"{name}.{ext}").exists() for ext in ("png", "tex", "xml")}
        registered = share is None and f'"bigportraits/{name}.tex"' in ASSETS.read_text()
        build = name[:-len("_none")] if name.endswith("_none") else name
        rows.append(dict(skin=name, export=(EXPORTED / build / "build.json").exists(), png=has["png"],
                         tex=has["tex"] and has["xml"], registered=registered, shares=share))
    print(json.dumps(rows, indent=1))


def CommandRender(args):
    spec = LoadSpec(args.spec, args.set)
    layers, report = Compose(spec)
    out = spec["_dir"]
    (out / "layers").mkdir(exist_ok=True)
    for name, image in layers.items():
        image.save(out / "layers" / f"{name}.png")
    character, bounds = Character(Flatten(layers))
    character.save(out / "character.png")
    preview = Image.new("RGBA", (character.width + 56, character.height + 56), "#afadab")
    preview.alpha_composite(character, (28, 28))
    preview.save(out / "pose-preview.png")
    portrait, placement = Portrait(spec, character, bounds)
    portrait.save(out / "portrait-preview.png")
    report.update(skin=spec["skin"], placement=placement, outputs=[str((out / n).relative_to(ROOT)) for n in
                  ("pose-preview.png", "portrait-preview.png", "character.png")])
    if args.install:
        if report["warnings"] and not args.force:
            Fail("not installing while there are warnings (pass --force to install anyway): "
                 + "; ".join(report["warnings"]))
        portrait.save(PORTRAITS / f"{spec['skin']}.png")
        report["installed"] = Pack(spec["skin"])
        if args.register:
            report["registered"] = Register(spec["skin"])
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=1))


def CommandPreview(args):
    spec = LoadSpec(args.spec, args.set)
    variants = [json.loads(v) for v in args.variant] or [{}]
    tiles = []
    for variant in variants:
        layers, report = Compose(Merge(spec, variant))
        label = json.dumps(variant) if variant else None
        tiles.append(Picture(layers, Box(args.box), args.tint, set(args.hide.split(",")) if args.hide else (),
                             label=label, zoom=args.zoom))
        if report["warnings"]:
            print(json.dumps({"variant": variant, "warnings": report["warnings"]}))
    Sheet(tiles, args.columns).save(args.out)
    print(args.out)


def CommandFrames(args):
    skin = Skin(args.skin)
    numbers = sorted(n for s, n in skin.frames if s == args.symbol)
    if not numbers:
        Fail(f"{args.skin} has no {args.symbol} frames")
    tiles = []
    for n in numbers:
        image = skin.Texture(args.symbol, n)
        image = image.crop(image.getbbox() or (0, 0, 1, 1))
        image = image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST)
        tile = Image.new("RGBA", (image.width + 8, image.height + 22), "#b0b0b0")
        tile.alpha_composite(image, (4, 18))
        ImageDraw.Draw(tile).text((4, 3), str(n), fill="black")
        tiles.append(tile)
    Sheet(tiles, args.columns).save(args.out)
    print(args.out)


def CommandNative(args):
    skin = Skin(args.skin)
    tiles = []
    for reference in args.frames:
        frame, hashes = NativeFrame(reference)
        canvas = Image.new("RGBA", SIZE, "#afadab")
        for element in reversed(Shown(frame, hashes)):
            symbol = SymbolName(hashes, element)
            if not skin.Has(symbol):
                continue
            StampFrame(skin, canvas, symbol, args.face if symbol == "face" else skin.Resolve(symbol, element.frame), element)
        tile = canvas.crop((150, 280, 550, 820))
        ImageDraw.Draw(tile).text((4, 4), reference, fill="black")
        tiles.append(tile)
    Sheet(tiles, args.columns).save(args.out)
    print(args.out)


def CommandSearch(args):
    # Ranks down-facing native frames by how close one arm's elbow and hand come to targets given
    # in anim units relative to the feet (x right, y down; the idle shoulders are near y -111).
    ex, ey, hx, hy = (float(v) for v in args.target.split(","))
    results = []
    for path in sorted(GAME_ANIM.glob("player_*.zip")):
        try:
            animations, hashes = Anim(path.name)
        except Exception:
            continue
        for anim in animations:
            if not anim.FullName().endswith("_down"):
                continue
            for index, frame in enumerate(anim.frames):
                shown = Shown(frame, hashes)
                lowers = [e for e in shown if SymbolName(hashes, e) == "arm_lower"]
                if len(lowers) != 2 or sum(SymbolName(hashes, e) == "hand" for e in shown) != 2:
                    continue
                parts = ArmParts(frame, hashes, args.side)
                lower, hand, upper = parts["arm_lower"], parts["hand"], parts["arm_upper_skin"]
                score = math.hypot(lower.tx - ex, lower.ty - ey) + 1.5 * math.hypot(hand.tx - hx, hand.ty - hy)
                score += 0.7 * math.hypot(upper.tx - (20 if args.side == "near" else -20), upper.ty + 111)
                results.append((round(score, 1), f"{path.name}:{anim.FullName()}:{index}"))
    results.sort()
    seen, best = set(), []
    for score, reference in results:
        key = reference.rsplit(":", 1)[0]
        if key not in seen:
            seen.add(key)
            best.append({"score": score, "frame": reference})
        if len(best) >= args.count:
            break
    print(json.dumps(best, indent=1))


def CommandPack(args):
    print(json.dumps(Pack(args.skin), indent=1))


def CommandRegister(args):
    print(json.dumps(Register(args.skin), indent=1))


def Main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    p = commands.add_parser("list", help="every base skin and the state of its portrait")
    p.set_defaults(run=CommandList)

    p = commands.add_parser("render", help="compose a spec; write previews, layers and report.json next to it")
    p.add_argument("spec")
    p.add_argument("--set", action="append", default=[], metavar="KEY=JSON",
                   help="override a spec value, e.g. arms.far.forearm=-120 (repeatable)")
    p.add_argument("--install", action="store_true", help="also write bigportraits/<skin>.png/.tex/.xml")
    p.add_argument("--register", action="store_true", help="with --install: wire the portrait into the Lua skin")
    p.add_argument("--force", action="store_true", help="install even with warnings")
    p.set_defaults(run=CommandRender)

    p = commands.add_parser("preview", help="zoomed renders of spec variants side by side, for checking joints")
    p.add_argument("spec")
    p.add_argument("--out", required=True)
    p.add_argument("--variant", action="append", default=[], metavar="JSON",
                   help='spec changes to try, e.g. \'{"arms": {"far": {"forearm": -110}}}\' (repeatable)')
    p.add_argument("--set", action="append", default=[], metavar="KEY=JSON")
    p.add_argument("--box", help="canvas crop x0,y0,x1,y1 (pose canvas is 700x900, feet at 350,780)")
    p.add_argument("--tint", action="store_true", help="tint far arm red and near arm blue")
    p.add_argument("--hide", help="comma-separated layers to leave out, e.g. head,tray")
    p.add_argument("--zoom", type=int, default=2)
    p.add_argument("--columns", type=int)
    p.set_defaults(run=CommandPreview)

    p = commands.add_parser("frames", help="numbered contact sheet of one symbol's frames in a skin")
    p.add_argument("skin")
    p.add_argument("symbol", help="e.g. hand, arm_lower, face, torso")
    p.add_argument("--out", required=True)
    p.add_argument("--columns", type=int, default=10)
    p.set_defaults(run=CommandFrames)

    p = commands.add_parser("native", help="render native animation frames in a skin, for pose ideas")
    p.add_argument("skin")
    p.add_argument("frames", nargs="+", help="package.zip:animation:frame")
    p.add_argument("--out", required=True)
    p.add_argument("--face", type=int, default=15)
    p.add_argument("--columns", type=int, default=6)
    p.set_defaults(run=CommandNative)

    p = commands.add_parser("search", help="find native frames whose arm reaches an elbow and hand position")
    p.add_argument("side", choices=("far", "near"))
    p.add_argument("target", help="elbow_x,elbow_y,hand_x,hand_y in anim units (feet at 0,0, y down)")
    p.add_argument("--count", type=int, default=10)
    p.set_defaults(run=CommandSearch)

    p = commands.add_parser("pack", help="bigportraits/<skin>.png -> .tex (DXT5) and .xml")
    p.add_argument("skin")
    p.set_defaults(run=CommandPack)

    p = commands.add_parser("register", help="use bigportraits/<skin> in game: drop share_bigportrait_name, add assets")
    p.add_argument("skin")
    p.set_defaults(run=CommandRegister)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    Main()
