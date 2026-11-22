---
name: dst-bigportrait
description: Use when making, posing, fixing or installing a character-select portrait (bigportrait) for a skin in the Louis Manutsawee DST mod, or when a skin shares another skin's portrait (share_bigportrait_name) and needs its own. Drives tools/bigportrait/bigportrait.py.
---

# Bigportraits

Portraits are posed from the skin's exported game textures with `tools/bigportrait/bigportrait.py`,
never painted from scratch, so they keep the game proportions. Read
`tools/bigportrait/README.md` for the full spec format before writing a spec.

Run from the mod root with the pyenv Python (system Python lacks PIL/numpy/OpenCV):

```
P=~/.pyenv/versions/3.10.14/bin/python; T=tools/bigportrait/bigportrait.py
```

## Steps

1. `$P $T list`: find skins without `tex`, or with `shares` set.
2. Write `workspace/bigportraits/<skin>/portrait.json`. Start from an existing spec in
   `workspace/bigportraits/` with a similar pose:
   - `kiritzuka_maid`: tray held on both palms (props).
   - `kiritzuka_maid_classic`: tilted head, fist by the chin, other hand holding the cuff.
   - `kiritzuka_maid_kimono`: hands clasped at the chest (both arms from Webber's idle).
   - `kiritzuka_maid_victorian`: hand on heart.
   - `kiritzuka_maid_highcollar`: hand to the mouth (Wendy's idle).
3. Prefer whole native arms (`source`) over hand-built rotations; use `native` and `search`
   to find them. Then `render` and look at `portrait-preview.png` with the Read tool.
4. Read `report.json`. Fix every warning: a vanished limb (low `visible`) usually needs a
   different `order`; a joint gap needs `elbow_slide`, `foreshorten` or a different angle.
   Use `preview --variant ... --tint --box ...` to compare a few values side by side.
5. Show the user the preview and iterate on their feedback before installing.
6. `$P $T render <spec> --install --register`, then check `git diff` of the skin's prefab file
   and `main/assets.lua`.

## Rules

- Keep the skin's own textures; only arms, hands, head tilt and props change.
- New props (trays, cups...) come from images the user provides, saved in the spec folder.
- Don't use `--force` to hide a real problem; add a layer to `hidden_ok` only when it is meant to
  be covered.
- Not testable here: tell the user to check the portrait in the game's character select.
