// =====================================================
// ANCHOR — Tap-to-Lock Focus Puck
// Parametric two-piece snap-fit enclosure
// Print in PLA or PETG, no supports needed
// =====================================================

// ---------- PARAMETERS (edit these to tune the fit) ----------

// Overall puck size
puck_diameter   = 50;      // outer diameter, mm
wall_thickness  = 2;       // outer wall thickness, mm
base_height     = 6;       // base tray height, mm
lid_height      = 3.5;     // lid height, mm

// NFC tag pocket (sized for a 25mm "coin" NFC tag ~1mm thick,
// e.g. NTAG213/215 hard tag — adjust if using a thin adhesive sticker)
nfc_diameter    = 25.5;    // pocket diameter, mm (0.5mm clearance over 25mm tag)
nfc_depth       = 1.3;     // pocket depth, mm (tag thickness + 0.3mm clearance)
nfc_floor       = 1.6;     // plastic remaining above tag for a clean top surface, mm

// Magnet pocket (10mm x 2mm N35 disc magnet), offset from center
// so it doesn't sit directly behind the NFC tag and kill read range
magnet_diameter = 10.3;    // pocket diameter, mm (0.3mm clearance)
magnet_depth    = 2.2;     // pocket depth, mm
magnet_offset   = 17;      // distance from puck center to magnet pocket center, mm
include_magnet  = true;    // set false to skip the magnet pocket entirely

// Snap-fit lip
lip_height      = 1.5;     // height of the snap bump, mm
lip_protrusion  = 0.6;     // how far the bump sticks out, mm
fit_clearance   = 0.25;    // radial clearance between base wall and lid wall, mm

// Rendering
$fn = 100;                 // smoothness of circles

// ---------- DERIVED VALUES ----------

outer_r   = puck_diameter / 2;
inner_r   = outer_r - wall_thickness;         // inner cavity radius of base
lid_wall_r_outer = inner_r - fit_clearance;   // lid's skirt sits just inside base wall
lid_wall_r_inner = lid_wall_r_outer - wall_thickness*0.7;

// =====================================================
// BASE TRAY (bottom half — holds the NFC tag + magnet)
// =====================================================
module base_tray() {
    difference() {
        union() {
            // outer shell
            cylinder(h = base_height, r = outer_r);

            // snap-fit bump ring near the top of the outer wall
            translate([0, 0, base_height - lip_height])
                difference() {
                    cylinder(h = lip_height, r = outer_r - wall_thickness/2 + lip_protrusion);
                    cylinder(h = lip_height, r = outer_r - wall_thickness/2);
                }
        }

        // hollow out the interior cavity
        translate([0, 0, wall_thickness])
            cylinder(h = base_height, r = inner_r);

        // NFC tag pocket, centered, recessed from the top face
        translate([0, 0, base_height - nfc_floor - nfc_depth])
            cylinder(h = nfc_depth + 1, r = nfc_diameter / 2);

        // magnet pocket, offset to the side, recessed from the bottom
        if (include_magnet) {
            translate([magnet_offset, 0, -1])
                cylinder(h = magnet_depth + 1, r = magnet_diameter / 2);
        }
    }
}

// =====================================================
// LID (top half — snaps onto the base)
// =====================================================
module lid() {
    difference() {
        union() {
            // top disc
            cylinder(h = wall_thickness, r = outer_r);

            // skirt that slides inside the base wall and snaps past the lip
            translate([0, 0, -(lid_height - wall_thickness)])
                difference() {
                    cylinder(h = lid_height, r = lid_wall_r_outer);
                    cylinder(h = lid_height, r = lid_wall_r_inner);
                }
        }

        // groove cut into the inside of the skirt so it clicks over the base's bump
        translate([0, 0, -(lid_height - wall_thickness) + 1])
            difference() {
                cylinder(h = lip_height + 0.4, r = lid_wall_r_outer + 0.4);
                cylinder(h = lip_height + 0.4, r = lid_wall_r_outer - lip_protrusion - 0.2);
            }
    }
}

// =====================================================
// LAYOUT — printable orientation, both parts flat on the bed
// =====================================================
base_tray();

translate([puck_diameter + 10, 0, lid_height - wall_thickness])
    rotate([180, 0, 0])
        lid();

// To preview the assembled puck instead, comment out the two lines above
// and uncomment the block below:
//
// base_tray();
// translate([0, 0, base_height - lip_height + 0.2]) lid();
