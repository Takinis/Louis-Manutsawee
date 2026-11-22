# Lycoris Satchel

## References

- [Good Smile Company: PLAMATEA Takina Inoue](https://www.goodsmile.com/en/product/34688/PLAMATEA%2BTakina%2BInoue):
  worn size, brown leather palette, handle and shoulder straps.
- [HOBBY Watch: TOMYTEC Little Armory LALR01/LALR02](https://hobby.watch.impress.co.jp/docs/review/1561995.html):
  close-ups of the flap, twin buckles, circular badge and side panel.
- [Ichijinsha: Lycoris Recoil Heroine Archive](https://data.ichijinsha.co.jp/detail/75801795):
  official reference book with character and art settings.

The sprites use original artwork based on the uniform satchel. The licensed
product photos are not included in the mod.

## Build

Run from the mod directory with the same Python environment as `tools/pack_anim`.
`sharp` must resolve from Node's module path; set `NODE_PATH` to the existing
runtime's `node_modules` if needed.

```sh
python3 workspace/lycoris_backpack/build_assets.py
```

`painted-master.png` contains the refined worn views and the original ground view.
`ground-master.png` contains the redrawn ground pose, based on the vanilla
backpack, ice pack and piggyback ground sprites. `painted.cjs` fits the worn views
and the replacement ground sprite to their template bounds.
`art.cjs` defines the frame layouts and shoulder straps. The build uses the installed game's
`swap_backpack.zip` frame indices, durations and anchors, without modifying it.
It writes editable sprites to `exported/swap_lycoris_backpack`, installs the
static build and inventory texture, and renders `preview.png` from the packed
frames using the existing uniform build and vanilla animations.

The deep brown leather, darker straps, fine ink hatching, seams and aged brass
replace the original flat artwork. Rear-facing body frames 6, 7 and 8 have an
x offset of +3 build units. Other anchors and gameplay are unchanged.

The redrawn ground sprite is frame 13 only. The HUD icon uses a 64 x 64 canvas,
with matching global `ATLAS_BUILD` size and transparent padding.
