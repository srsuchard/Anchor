# Hardware

A passive NFC tag in a two-piece snap-fit housing.

## Files

| File | Status |
| --- | --- |
| `anchor_puck.scad` | Parametric source. **Unverified — see below.** |

## Status, honestly

`anchor_puck.scad` is a starting template. It has not been rendered, sliced, or
printed, and it is **not** a reproduction of any existing printed puck — its
dimensions are sensible defaults, not measured ones.

Treat it as a parametric skeleton to reconcile against a part you have actually
fitted, not as a known-good design. If you have working geometry already, its
numbers should replace the defaults here.

No `.3mf` or `.stl` is committed yet, because meshes should be exported from
geometry that has been verified to print.

## Rendering

With [OpenSCAD](https://openscad.org):

```
openscad -o anchor_puck.stl anchor_puck.scad
```

Set `part` to `"base"`, `"lid"`, or `"print"` (both, laid out for the bed).

## Tuning

`fit_clearance` is the parameter to adjust first — it controls how tightly the
lid enters the base, and it's the one most sensitive to your printer. Start at
0.25 mm; increase if the lid won't seat, decrease if it rattles.

`bead_r` controls how hard the snap is to open. Larger holds tighter. A puck
that's genuinely annoying to open is on-thesis, but a bead you can't release
without a tool means a broken lid eventually.

## Assembly

Print, drop the tag into the floor recess, press the lid on.

Do not print over the tag. NFC needs a clear path to the phone, and running a hot
nozzle across a tag risks damaging it. The recess exists so the tag goes in after
printing.

Avoid metal anywhere in the stack — metallic filaments included. It detunes the
antenna and the phone won't read it.
