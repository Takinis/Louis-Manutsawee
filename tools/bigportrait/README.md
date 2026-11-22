# bigportrait

Builds character-select portraits (`bigportraits/<skin>.png/.tex/.xml`) from a skin's exported
game textures, so the portrait keeps the in-game proportions. A JSON spec describes the pose.

```
P=~/.pyenv/versions/3.10.14/bin/python   # the only Python here with PIL, numpy and OpenCV
T=tools/bigportrait/bigportrait.py        # run from the mod root
```

## Workflow

1. `$P $T list` shows every base skin. A skin needs work when it has no `tex` or still `shares`
   another skin's portrait.
2. Make `workspace/bigportraits/<skin>/portrait.json` by copying the nearest existing spec.
   The skin needs `exported/<skin>/build.json` (`exported/<char>` for `<char>_none`).
3. Look for a pose:
   - `$P $T native <skin> player_idles_webber.zip:idle_webber_down:33 ... --out sheet.png`
     renders native frames in this skin.
   - `$P $T search far|near ex,ey,hx,hy` finds native frames whose arm reaches a given elbow and
     hand position (anim units, feet at 0,0, y down).
   - `$P $T frames <skin> hand --out hands.png` numbers a symbol's frames (hand, face, ...).
4. `$P $T render <spec>` writes, next to the spec:
   - `portrait-preview.png`: the final 512×1024 sheet; look at this.
   - `pose-preview.png` and `character.png`: the figure alone.
   - `layers/*.png`: each layer on the 700×900 pose canvas.
   - `report.json`: visible fraction per layer, joint overlaps and warnings.
5. Tune with `--set key=json` (e.g. `--set arms.near.forearm=150`) or
   `$P $T preview <spec> --out v.png --variant '{"arms":{"far":{"hand_turn":-120}}}' --variant ... --tint --box 200,450,500,720`
   to compare variants zoomed in on a joint.
6. `$P $T render <spec> --install --register` writes the PNG, packs the DXT5 TEX and atlas XML,
   removes `share_bigportrait_name` from the skin's `CreatePrefabSkin` and adds the
   `Asset("IMAGE"/"ATLAS", ...)` lines to `main/assets.lua`. Install is refused while the report
   has warnings; fix them, list the layer in `hidden_ok`, or pass `--force`.

For a portrait painted elsewhere, put it at `bigportraits/<skin>.png` (512×1024, same plate) and run
`$P $T pack <skin>` then `$P $T register <skin>`.

## Spec

```json
{
  "skin": "kiritzuka_maid_victorian",
  "note": "free text",
  "base": "player_idles.zip:idle_loop_down:0",
  "face": 15,
  "head": {"tilt": 6, "pivot": [350, 612]},
  "arms": {
    "far": {"source": "player_idles_webber.zip:idle_webber_down:33"},
    "near": {"upper": 30, "forearm": 168, "foreshorten": 0.95, "elbow_slide": 6, "hand": 0, "hand_turn": 180}
  },
  "props": [],
  "order": ["legs", "far-upper", "near-upper", "bodice", "skirt", "near-lower", "near-hand", "head", "far-lower", "far-hand"],
  "joints": [["far-upper", "bodice"]],
  "hidden_ok": [],
  "portrait": {"align": "body", "x": 244}
}
```

- `base`: native frame (`package.zip:animation:frame`, packages from the game's `data/anim`) that
  gives the body, legs and the default arms. Hats and the carry arm are always hidden.
- `face`: frame of the skin's `face` symbol.
- `head.tilt`: degrees clockwise on screen about `pivot` (pose-canvas pixels; neck is about 350,612).
- `arms.far` is the arm on the left of the screen, `arms.near` on the right. Each arm, in order:
  - `source`: take the whole arm from another native frame, re-anchored to the base shoulder.
  - `upper`: degrees the upper arm turns about the shoulder.
  - `elbow_slide`: move the elbow down the upper arm, so the forearm's round end caps the sleeve.
  - `foreshorten`: forearm length factor (below 1 points it at the viewer).
  - `forearm`: degrees the forearm turns about the elbow.
  - `hand`: hand frame to use (`frames <skin> hand`); `mirror` flips it (back of hand vs palm);
    `hand_turn` turns it about the wrist; `hand_scale` scales it.
  - `hand_follows_forearm`: move the hand with the foreshortened forearm instead of sitting at
    its tip.
- `props`: extra images from the spec folder, each a layer named `name`:
  - `box: [x, y, w, h]` stretches the image into that rectangle, or `fit: [w, h]` keeps its aspect
    and places it by `base: [cx, bottom]` or `at: [x, y]`.
  - `threshold`: alpha used to trim the image. `sharpen`: unsharp after upscaling a small icon.
  - `clean_ground_shadow: {light, below_row, ink}` keeps light pixels plus an ink border, dropping
    an icon's dark ground scribble below `below_row`.
  - `contact_shadow: {"on": "<layer>"}` draws a soft shadow under `base`, clipped to that layer.
- `order`: back-to-front layer list. Layers: `legs`, `bodice`, `skirt`, `head`,
  `far|near-upper|lower|hand`, and prop names.
- `joints`: layer pairs that must overlap (more than 10 px) or a warning is raised. Default: both
  shoulders, elbows and wrists.
- `hidden_ok`: arm layers allowed to be mostly covered (e.g. hands under a tray).
- `portrait`: `align` `"body"` puts the body centre line at column `x`; `"box"` centres the whole
  figure's box at `x`. `feet` (572) and `scale` (440/530) match the other portraits; `plate` swaps
  the background (default `plate.png` beside this file).

## Format notes

- TEX: KTEX, DXT5, 11 mips, premultiplied alpha, rows stored bottom-up; the packer checks a
  decode round trip.
- XML: one element `<skin>_oval.tex` with the oval UVs used by every portrait in this mod.
- A skin with `share_bigportrait_name` shows that other skin's portrait; `register` removes it.
