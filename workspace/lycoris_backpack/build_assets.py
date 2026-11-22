"""Compile the satchel against the installed game's backpack frames and preview the result."""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

WORK = Path(__file__).resolve().parent
ROOT = WORK.parents[1]
GAME_ANIM = ROOT / "../../data/anim"
BUILD = "swap_lycoris_backpack"
SOURCE = ROOT / "exported" / BUILD
SYMBOL = "swap_body"
BACK_FRAMES = {6, 7, 8}
BACK_OFFSET_X = 3
ICON_SIZE = 64

sys.path.insert(0, str(ROOT / "tools"))
import dstanim
import pack_anim


def Export():
    native = dstanim.Build(GAME_ANIM / "swap_backpack.zip")
    frames = [
        dict(frameNum=f.num, duration=f.duration,
             x=f.bbox[0] + (BACK_OFFSET_X if f.num in BACK_FRAMES else 0), y=f.bbox[1],
             width=int(f.bbox[2]), height=int(f.bbox[3]), vertNum=f.vert_count)
        for f in native.symbols[dstanim.StringHash(SYMBOL)]
    ]
    output = SOURCE / SYMBOL
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run(["node", str(WORK / "art.cjs"), str(output)],
                   input=json.dumps(frames), text=True, check=True)
    build = {"name": BUILD, "version": native.version, "scale": 1,
             "symbols": [{"name": SYMBOL, "frames": frames}]}
    (SOURCE / "build.json").write_text(json.dumps(build, indent=2) + "\n")
    return native


def Icon():
    image = Image.open(SOURCE / SYMBOL / f"{SYMBOL}-13.png").convert("RGBA")
    crop = image.crop(image.getbbox())
    crop.thumbnail((58, 52), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE))
    icon.alpha_composite(crop, ((ICON_SIZE - crop.width) // 2, (ICON_SIZE - crop.height) // 2))
    encoded = pack_anim.EncodeTexture(icon, "rgba")
    expected = np.array(icon)
    expected[:, :, :3] = ((expected[:, :, :3].astype(np.uint16) * expected[:, :, 3:4] + 127) // 255)
    assert np.array_equal(np.asarray(dstanim.DecodeTex(encoded)), expected)
    assert dstanim.DecodeTex(encoded).size == (ICON_SIZE, ICON_SIZE)
    return icon, encoded


def Preview(native, new, icon):
    key = dstanim.StringHash(SYMBOL)
    assert new.name == BUILD and new.symbols.keys() == native.symbols.keys()
    frames = new.symbols[key]
    assert all(f.vert_count > 0 for f in frames)
    assert [(f.num, f.duration, f.bbox) for f in frames] == [
        (f.num, f.duration, (f.bbox[0] + (BACK_OFFSET_X if f.num in BACK_FRAMES else 0), *f.bbox[1:]))
        for f in native.symbols[key]
    ]
    for f in frames:
        image = Image.open(SOURCE / SYMBOL / f"{SYMBOL}-{f.num}.png").convert("RGBA")
        assert image.size == (int(f.bbox[2]), int(f.bbox[3]))
        assert image.getpixel((0, 0))[3] == image.getpixel((image.width - 1, image.height - 1))[3] == 0

    sheet = Image.new("RGBA", (960, 540), "#d6d0c3")
    draw = ImageDraw.Draw(sheet)
    player = dstanim.Build(ROOT / "anim/manutsawee_lycoris.zip")
    ground = dstanim.ReadAnim(GAME_ANIM / "backpack.zip")[0][0].frames[0]
    assert ground.elements[0].frame == 13
    cases = [("Ground", ground, {}, None), ("Inventory", None, {}, None)]
    for package, name in [("player_idles.zip", "idle_loop"), ("player_basic.zip", "run_loop")]:
        animations, hashes = dstanim.ReadAnim(GAME_ANIM / package)
        for facing in ("down", "side", "up"):
            animation = dstanim.FindAnimation(animations, f"{name}_{facing}")
            cases.append((f"{name} / {facing}", animation.frames[len(animation.frames) // 2], hashes, player))

    hidden = (dstanim.PLAYER_HIDDEN_LAYERS - {"arm_normal"}) | {"arm_carry", "swap_object", "backpack"}
    for i, (label, frame, hashes, character) in enumerate(cases):
        col, row = i % 4, i // 4
        tile = Image.new("RGBA", (240, 240))
        if frame is None:
            tile.alpha_composite(icon, ((240 - ICON_SIZE) // 2, (240 - ICON_SIZE) // 2))
        else:
            for element in reversed(frame.elements):
                if hashes.get(element.layer, "").lower() not in hidden:
                    build = new if element.symbol == key else character
                    if build is not None:
                        dstanim.DrawElement(tile, build, element, 0.72 if character else 1,
                                            (120, 216) if character else (120, 177))
        assert tile.getbbox()
        sheet.alpha_composite(tile, (col * 240, row * 270))
        draw.text((col * 240 + 12, row * 270 + 243), label, fill="#291c19")
    sheet.save(WORK / "preview.png")
    previous = WORK / "preview-before-darkening.png"
    if previous.exists():
        comparison = Image.new("RGBA", (960, 1144), "#d6d0c3")
        labels = ImageDraw.Draw(comparison)
        labels.text((12, 12), "Before", fill="#291c19")
        comparison.alpha_composite(Image.open(previous).convert("RGBA"), (0, 32))
        labels.text((12, 584), "After", fill="#291c19")
        comparison.alpha_composite(sheet, (0, 604))
        comparison.save(WORK / "comparison.png")

    comparison = Image.new("RGBA", (960, 280), "#bbb8af")
    labels = ImageDraw.Draw(comparison)
    before = WORK / "before-ground-redraw.zip"
    cases = [
        ("Backpack", dstanim.Build(GAME_ANIM / "swap_backpack.zip")),
        ("Before", dstanim.Build(before) if before.exists() else native),
        ("After", new),
        ("HUD / 64 x 64", None),
    ]
    for i, (label, build) in enumerate(cases):
        tile = Image.new("RGBA", (240, 240))
        if build is None:
            tile.alpha_composite(icon, ((240 - ICON_SIZE) // 2, (240 - ICON_SIZE) // 2))
        else:
            for element in reversed(ground.elements):
                dstanim.DrawElement(tile, build, element, 1.15, (120, 212))
        comparison.alpha_composite(tile, (240 * i, 0))
        labels.text((240 * i + 12, 253), label, fill="#291c19")
    comparison.save(WORK / "ground-preview.png")


def Main():
    native = Export()
    icon, encoded = Icon()
    output = WORK / f"{BUILD}.zip"
    report = pack_anim.Pack(SOURCE, output, codec="rgba", atlas_size=512, build_only=True, overwrite=True)
    Preview(native, dstanim.Build(output), icon)
    (ROOT / "anim" / output.name).write_bytes(output.read_bytes())
    (ROOT / "images/hud/lycoris_backpack.tex").write_bytes(encoded)
    icon.save(WORK / "inventory.png")
    print(f"{report['sprites']} sprites packed and texture round trips verified.")


if __name__ == "__main__":
    Main()
