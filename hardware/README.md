# Hardware

A passive NFC tag in a two-piece printed housing.

## Files

| File | What it is |
| --- | --- |
| `anchor_puck.scad` | Parametric source. Edit this. |
| `anchor_puck.stl` | Both parts, laid out for the bed. |
| `anchor_puck.3mf` | Same, for slicers that prefer it. |

Meshes were exported from the `.scad` with OpenSCAD 2021.01 and should be
regenerated after any parameter change:

```
openscad -o anchor_puck.stl anchor_puck.scad
openscad -o anchor_puck.3mf anchor_puck.scad
```

## Measured dimensions

Taken from the rendered mesh, not from the parameter list:

| | |
| --- | --- |
| Diameter | 50.0 mm |
| Assembled height | 8.0 mm with the lid seated on the rim |
| Base tray volume | 4963 mm³ |

Note that `base_height + lid_height` is 9.5 mm, but that double-counts the lid
skirt, which nests *inside* the base. The assembled part is 8.0 mm.

## What actually holds the lid on

The lid is retained by friction against the base's inner wall, set by
`fit_clearance` (0.25 mm radial). That is the only parameter controlling how
firmly it holds.

The `lip_height` / `lip_protrusion` snap bump does not currently contribute —
see "Known issues" below. Anyone re-printing on a different printer has friction
and nothing else to fall back on, so expect to tune `fit_clearance` per machine.

## Known issues

These are verified against rendered geometry, not guesses. All three are in the
`.scad` and none of them change how an already-printed puck behaves — the part
works, just not for the reason its comments claim.

**1. The snap-fit bump is buried in the wall and does nothing.**
The bump ring spans radius 24.0–24.6 mm, but the base wall already occupies
23–25 mm, so the union adds no material. Rendering with `lip_protrusion=0`
produces an identical volume (4963.455 mm³ either way). To make it real, the
bump has to protrude *inward*, to a radius below `inner_r`.

**2. The NFC tag pocket removes nothing.**
The pocket is cut at z 3.1–5.4 mm, inside the cavity that was already hollowed
out at z 2–6 mm. Rendering with `nfc_diameter` near zero gives the same volume.
There is no recess locating the tag; it sits loose in the cavity. The
`nfc_floor` comment describes plastic above the tag that isn't there.

**3. The magnet pocket is a through-hole.**
The cut spans z −1 to 2.2 mm through a 2 mm floor, so it opens into the cavity.
It removes 166.5 mm³ — exactly π·5.15²·2.0, the full floor thickness — where a
blind 2.2 mm pocket would remove 183.3 mm³. The magnet can push through from
either side. Either shorten the cut or thicken the floor.

**4. The commented-out assembly preview overlaps.**
It places the lid at `base_height - lip_height + 0.2` = 4.7 mm, which drives the
full-diameter top disc 1.3 mm into the base's outer wall. For a seated preview
the offset should be `base_height`.

## Tuning

`fit_clearance` first — it's the only thing holding the lid on, and it's the
parameter most sensitive to your printer. Increase if the lid won't seat,
decrease if it rattles.

## Assembly

Print, drop the tag in, press the lid on.

Do not print over the tag. NFC needs a clear path to the phone, and running a hot
nozzle across a tag risks damaging it. Avoid metallic filament anywhere in the
stack — it detunes the antenna and the phone won't read it.

If you fit the optional magnet, keep it offset from center as the design does.
A magnet sitting directly behind the tag will kill read range.
