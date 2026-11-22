# Animation Packer

Compile editable PNG exports into Don't Starve Together animation packages.
Run from the mod directory:

```sh
./tools/pack_anim ghost_kiritzuka_build --overwrite
./tools/pack_anim kiritzuka_shirt_tie --build-only --overwrite
./tools/pack_anim kiritzuka_shirt_tie --dynamic --overwrite
./tools/pack_anim exported/swap_pipewrench
./tools/pack_anim /path/to/source.zip -o /path/to/result.zip
```

Static output defaults to `anim/<build-name>.zip`. Dynamic output defaults to
`anim/dynamic/<build-name>.zip` and `anim/dynamic/<build-name>.dyn`.
`--overwrite` is required when any output exists. Existing files are backed up
in `.pack-backups/` beside the output before replacement.
The source directory or input ZIP is never modified.

In dynamic mode, the ZIP contains `build.bin` and optional `anim.bin`.
The DYN contains the KTEX atlases using the byte layout from
`dont-starve-anim-tool`. Register the ZIP as `DYNAMIC_ANIM` and the DYN as
`PKGREF`. For a static ZIP, use `ANIM`.

## Inputs

- An export directory containing `build.json`, `<symbol>/<symbol>-<frame>.png`
  and optional `anim.json`.
- A source ZIP with the same files, either at its root or inside one common
  directory. It is read directly, without filesystem extraction.
- An export name, resolved relative to the mod's `exported/` directory.

Explicit existing paths take precedence over short names. Overrides are stored
in `tools/pack_anim_sources.json`. The `ghost_kiritzuka_build` short name points
to `workspace/kiritzuka_ghost_design/build`, the approved ghost artwork, rather
than the unchanged original template.

Supported schema: build version 6, export scale 1, animation version 4.
Source PNG dimensions must match each frame's declared canvas. Empty frames
remain empty; new PNG artwork can populate a frame whose old metadata had zero
vertices. Atlas vertices and UVs are regenerated from final alpha bounds.
Frame anchors, durations, animation transforms, events and layer order are
preserved.

## Options

| Option | Purpose |
| --- | --- |
| `-o PATH` | Set the output ZIP path and the stem for companion files |
| `--dynamic` | Write a ZIP and a same-stem DYN containing the atlases |
| `--overwrite` | Back up and replace existing outputs |
| `--format dxt5` | Compressed KTEX with full mipmaps; default |
| `--format rgba` | Lossless premultiplied RGBA KTEX; larger runtime memory |
| `--build-only` | Omit anim.bin; use the game's existing animation banks |
| `--source-zip` | Also write `<name>-source.zip` with editable input files |
| `--atlas-size 1024` | Maximum atlas width/height; powers of two from 64 to 4096 |
| `--name NEW_NAME` | Change the compiled build name |
| `--literal-names` | Preserve animation names without directional suffix parsing |

By default `_down`, `_up`, `_side`, `_downside` and `_upside` animation suffixes
become native facing masks. An explicit numeric `facing` field is used verbatim.
Use `--literal-names` when a suffix belongs to a literal all-facing animation
name. The editable source ZIP retains the input metadata, including its
original build name.

Outputs also include `<name>.pack.json`: source hashes, frame/sprite counts,
atlas sizes, texture round-trip errors and the output ZIP hash. Dynamic reports
also include the DYN path and hash.

## Verification and Safety

Every build is decoded with `tools/dstanim.py` before installation. Checks cover
ZIP members, frame anchors/durations, vertices/UVs, full mip chains, texture
pixels, animation events/transforms and unchanged input files. Dynamic checks
also verify the DYN member names and compare its decoded atlas bytes to the
compiled KTEX. The renderer reads a same-stem DYN beside the build ZIP when an
atlas is absent from the ZIP. DXT5 uses the existing `tools/bigportrait` encoder;
RGBA round trips are exact.

Missing visible PNGs, duplicate symbol hashes, overlapping frame ranges,
invalid coordinates, ambiguous ZIP roots and unsafe ZIP paths fail explicitly.
The tool refuses output inside its input and output that replaces the source
ZIP. Paths under this mod's `anim/dynamic` require `--dynamic`.

Writes are staged and validated before replacement. The output directory is
locked during installation. If replacement fails, files already replaced in
that installation are restored to their previous state. Pending files are
retained for inspection after a failure.

## Runtime

The launcher uses `DST_PYTHON` when set, otherwise the existing local pyenv
Python 3.10.14 when available, then `python3`. Dependencies are Pillow and NumPy;
DXT5 additionally uses the existing portrait module, which imports OpenCV.

```sh
DST_PYTHON=/path/to/python ./tools/pack_anim --help
/Users/sydney/.pyenv/versions/3.10.14/bin/python -m unittest discover -s tests -p test_pack_anim.py -v
lua tests/kiritzuka_ghost.lua
```

Test fixtures are retained under `workspace/pack_anim_tests/` for inspection.
