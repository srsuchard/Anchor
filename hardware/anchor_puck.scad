// Anchor puck — parametric two-piece snap-fit enclosure
//
// STATUS: starting template, not a reproduction of any printed part.
// Every dimension below is a reasonable default, not a measured one. Reconcile
// these with a puck you have actually printed and fitted before treating them
// as correct. See README.md in this folder.
//
// Print: ~0.2 mm layers, 20% infill, no supports. Base prints as-is; the lid is
// laid out upside down by the "print" layout so its top face is on the bed.
//
// Drop the tag in after printing. Do not print over it — NFC needs a clear path
// to the phone, and a hot nozzle over a tag risks damaging it.

/* [Enclosure] */
puck_d        = 40;    // outer diameter
base_h        = 8;     // height of the base cup
lid_plate_t   = 1.6;   // thickness of the lid's top face
wall          = 2.4;   // side wall thickness
floor_t       = 2.4;   // base floor thickness, tag pocket included

/* [Tag] */
tag_d         = 25.4;  // 25 mm disc tags measure a little over
tag_t         = 1.0;   // sticker + backing
tag_slop      = 0.4;   // pocket oversize, diametral
tag_pocket_t  = 1.2;   // recess depth into the floor

/* [Snap fit] */
fit_clearance = 0.25;  // skirt-to-cavity gap; the number to tune first
skirt_h       = 4.0;   // how far the lid reaches into the base
skirt_wall    = 1.4;
bead_r        = 0.5;   // snap bead radius; smaller = easier to open

/* [Output] */
// "base", "lid", or "print" for both laid out for the bed
part          = "print";
part_gap      = 6;

$fn = 128;

// ---- Derived ---------------------------------------------------------------

cavity_d = puck_d - 2 * wall;
skirt_od = cavity_d - 2 * fit_clearance;
skirt_id = skirt_od - 2 * skirt_wall;

// Bead sits near the free end of the skirt so it clears the groove on the way
// in and catches on the way out.
bead_z   = base_h - skirt_h + bead_r + 0.5;

// ---- Parts -----------------------------------------------------------------

module snap_ring(radius, z) {
    translate([0, 0, z])
        rotate_extrude()
            translate([radius, 0])
                circle(r = bead_r);
}

module base() {
    difference() {
        cylinder(d = puck_d, h = base_h);

        // Interior cavity, open at the top.
        translate([0, 0, floor_t])
            cylinder(d = cavity_d, h = base_h);

        // Shallow recess that locates the tag and keeps it off the walls.
        translate([0, 0, floor_t - tag_pocket_t])
            cylinder(d = tag_d + tag_slop, h = tag_pocket_t + 0.01);

        // Groove the lid's bead snaps into.
        snap_ring(cavity_d / 2, bead_z);
    }
}

module lid() {
    union() {
        cylinder(d = puck_d, h = lid_plate_t);

        // Skirt hangs below the plate and into the base cavity.
        translate([0, 0, -skirt_h])
            difference() {
                cylinder(d = skirt_od, h = skirt_h);
                translate([0, 0, -0.01])
                    cylinder(d = skirt_id, h = skirt_h + 0.02);
            }

        snap_ring(skirt_od / 2, bead_z - base_h);
    }
}

// ---- Layout ----------------------------------------------------------------

if (part == "base") {
    base();
} else if (part == "lid") {
    lid();
} else {
    base();
    // Flip the lid so its flat top face lands on the bed.
    translate([puck_d + part_gap, 0, 0])
        rotate([180, 0, 0])
            translate([0, 0, -lid_plate_t])
                lid();
}
