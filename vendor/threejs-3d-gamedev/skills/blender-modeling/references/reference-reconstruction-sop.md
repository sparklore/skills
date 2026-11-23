# Reference Image Reconstruction SOP (Universal 9-Step Pipeline)

Use this Standard Operating Procedure whenever the user provides reference images (orthographic views, blueprints, product photos, or concept turnarounds) or asks to reconstruct a real-world object to scale.

> **Core Doctrine**: Never eyeball coordinates in Python scripts from a raw image. Always follow **Step 0 (`shape_draft` -> `shape_draft_check`) -> Steps 1–8 (`img_rectify` -> `shape_sections` -> Loft/Revolve/Regions -> Feature Lines -> Panels -> Clearance & Multi-View QC)**.

---

## 1. The 9-Step Reference Reconstruction Pipeline

### Step 0 — S0 Mental Draft Assessment (`shape_draft` -> `shape_draft_check`) ★ Mandatory First Step
Before measuring exact millimeter dimensions or counting meshes, build a structured **S0 Mental Draft** (4 tables `T1–T4`) to identify what the subject is, its rough scale tier (`A–F`), how many functional units it splits into, which parts are primary vs. accessories, which surfaces are faceted vs. smooth, and where cutouts/protrusions/recesses live:

```bash
# 1. Generate the 4-table S0 draft template (T1..T4)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan shape_draft --args '{
  "subject": "armored_scout_car",
  "object_class": "vehicle"
}'

# 2. Fill in T1..T4 and run the mechanical S0 draft gate
node "$SKILL_DIR/scripts/blender-rt.mjs" plan shape_draft_check --args '{
  "record": { ...filled T1, T2, T3, T4... }
}'

# 3. Once reference images arrive, query the object-class protocol & section_path
node "$SKILL_DIR/scripts/blender-rt.mjs" plan shape_plan --args '{"object_class": "vehicle"}'
```

#### The 4 Required Tables in S0 `shape_draft`:
- **`T1` (Identification & Scale Tier)**: Subject identity, scale tier **`A–F`** (from handheld prop to architecture — no fabricated `mm` numbers!), estimated module count, and primary body vs. accessories.
- **`T2` (Production Units)**: Breakdown of parts (`id`, `role`: `main` / `sub` / `accessory`, relative proportion such as `0.3x` of main body, `confidence`, `source`, and `to_confirm` questions for subsequent views).
- **`T3` (Form & Carrier)**: Per-unit carrier (`faceted_plate` | `smooth_subd` | `revolve` | `loft` | `sweep` | `sculpt`) and candidate cross-section path.
- **`T4` (Spatial Features)**: Key topological features (`cutout` / `boss` / `recess` / `chamfer` / `array_seam`), symmetry axes, and unresolved regions (`to_confirm`).

#### The 3 Hard Rules of S0 Draft Assessment (`R1–R3`):
- **`R1` (No Fabricated Exact Dimensions in S0)**: In S0, sizes must use scale tiers (`A–F`) or relative ratios (`0.3x`). Writing raw `"450mm"` or `"12cm"` before S2 reference calibration is mechanically rejected by `shape_draft_check` (`ok=false`, `check_mm_rejected=true`). `spec.py` only receives real millimeter values after S2 calibration.
- **`R2` (No Mesh Counting in S0)**: Do not run `audit_scene`, `audit_mesh`, or `print_report` during S0 planning.
- **`R3` (No Premature Lock-In)**: Every field records `confidence` + `source` (write `unknown` when occluded or unseen), and every unit includes `to_confirm` items to resolve as images are inspected.

---

### Step 1 — Perspective Rectification (`img_rectify`)
If the reference is a perspective photograph rather than an orthographic drawing, rectify the primary reference plane first (`Recipe 20`):
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan img_rectify --args '{
  "path": "/path/to/photo.jpg",
  "quad": [[x1,y1],[x2,y2],[x3,y3],[x4,y4]],
  "out_w": 1600, "out_h": 600, "known_w_mm": 4300,
  "out": "/tmp/side_rect.png"
}'
```
*(Remember: a 4-point homography only rectifies the plane of those 4 points; off-plane depth features must be measured from an orthogonal view.)*

---

### Step 2 — Extract Multi-View Station Table (`shape_sections` / `vehicle_sections`)
Extract quantitative 2D station profiles (`x_mm`, `z_top_mm`, `z_bottom_mm`, `half_w_mm`) and front cross-section shape (`section_shape`) directly from the calibrated views:
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan shape_sections --args '{
  "side": "/tmp/side_rect.png",
  "top": "/path/to/top.png",
  "front": "/path/to/front.png",
  "mm_per_px": 3.2,
  "stations": 41
}'
```

---

### Step 3 — Choose the Cross-Section Representation (5 Paths)

| Cross-Section Geometry | Which Parameter / Op to Use | Why |
|------------------------|-----------------------------|-----|
| **1. Axisymmetric / Rotational** (bottles, vases, barrels, wheel rims, gun barrels, lathe parts) | `plan shape_revolve --args '{"profile":[[r_mm,z_mm],...],"segments":48}'` | Exact $360^\circ$ revolution from a 2D radius-height curve; zero loft distortion. |
| **2. Left-Right Symmetric Shell** (car bodies, helmets, hulls, mice, fuselages) | `shape_loft` / `vehicle_loft` with `section_shape: [{z_frac, hw_frac}, ...]` | Uses normalized half-width profile modulated by each station's `z_top`, `z_bottom`, and `half_w`. |
| **3. Cambered / Asymmetric Upper & Lower Surfaces** (aircraft wings, hydrofoils, propeller blades, spoilers) | `shape_loft` with `section_outline: [[u_frac, v_frac], ...]` (full closed loop around upper + lower camber) | `section_shape` assumes symmetric left/right half-widths and flattens airfoil camber; `section_outline` preserves distinct suction/pressure surfaces. |
| **4. Arbitrary Explicit Cross-Section Polygon** (chiseled stealth hulls, hexagonal receivers, extruded rails) | `shape_loft` with per-station `section_pts: [[y_mm, z_mm], ...]` | Gives exact vertex-by-vertex control over hard-edged polygonal stations. |
| **5. Multi-Volume / Stepped Enclosures** (trucks with cab + bed, tanks with hull + turret, multi-tier buildings) | `plan shape_regions` / `vehicle_regions` | Splits the station table into distinct `regions: [{name, x0_mm, x1_mm}]` so step discontinuities aren't smoothed over by a single loft. |

---

### Step 4 — Build Primary Volume (`shape_loft` / `shape_revolve` / `shape_regions`)
Run the selected builder from Step 3 (or chain Steps 2–7 via `pipe_run` using `@artifact` references as in `Recipe 23`).

---

### Step 5 — Apply Parametric Feature Lines (`crease_lines` & `inset_lines`)
Embed character lines, beltlines, chine edges, and recessed channels directly in the loft (`Recipe 22`):
- Use `frac` (`0.0..1.0`) for beltlines that follow the local height of each station ring.
- Add `radius_mm` + `segments` for true circular-arc fillets, or `weight` (`0.0..1.0`) with `subsurf >= 1` for sharp SubD creases.

---

### Step 6 — Cut Physical Panel Seams (`shape_panels` / `vehicle_panels`)
Slice continuous shells into separate physical panels (`cuts_mm`, `gap_mm`) so panel seams cast real shadows under studio lighting.

---

### Step 7 — Mount Secondary Parts via Landmarks (`*_M_*` / `<name>_joints`)
Attach wheels, optics, handles, triggers, or armor modules onto the Empty markers generated by the base builder rather than guessing world coordinates.

---

### Step 8 — Dual-Evidence Verification (`clear_check` + `audit_gate` + Multi-View Ortho `qc_render_views` / `img_diff`)
1. Run `clear_check` on all moving/adjacent pairs and `audit_gate` on the collection.
2. Render orthographic views (`right`, `front`, `top`) via `qc_render_views(..., ortho=True)` and compare against the reference images via `img_diff`.
3. Inspect 900px renders (`see --size 900`) under 45° key light to verify internal feature lines and seams (which silhouette IoU cannot see).

---

## 2. Ten Object-Class Protocols

| # | Object Class | Primary Carrier | Key Parameters & Pitfalls |
|---|--------------|-----------------|---------------------------|
| 1 | **Bottles / Cups / Vessels** | `shape_revolve` + `Solidify` (or inner wall profile) + `sweep_build` (handle) | Model outer profile first; add wall thickness inward; join handle via Boolean UNION or spec overlap. |
| 2 | **Blades / Knives / Hand Tools** | `shape_loft` (`section_pts` diamond/wedge cross-section) | Honor Long/Wide/Thin axis semantics (Pitfall 1); taper tip by collapsing to centerline + `remove_doubles` (Pitfall 3). |
| 3 | **Chairs / Tables / Furniture** | Modular plates/extrusions + `sweep_build` (tubular frames) + `Mirror` | Enforce floor contact (`z_min = 0` for all 4 legs) via `audit_connectivity`. |
| 4 | **Footwear / Helmets / Ergonomic Shells** | `shape_sections` -> `shape_loft` + `section_shape` + `inset_lines` | Asymmetric left/right soles require `section_outline`; visor cutouts use `Boolean(EXACT)`. |
| 5 | **Automotive / Ground Vehicles** | `vehicle_package` -> `vehicle_sections` -> `vehicle_loft` -> `vehicle_panels` | Pass proportion gate first; Boolean wheel arches; dense stations at wheel rims (`Recipes 17–19`). |
| 6 | **Aircraft / Drones / Winged Bodies** | Fuselage via `shape_loft(section_shape)`; wings via `shape_loft(section_outline)` | Airfoil wings MUST use `section_outline` (upper != lower camber) with root-to-tip taper and dihedral angle. |
| 7 | **Ships / Submarines / Hulls** | `shape_sections` -> `shape_loft` + `crease_lines` (chine lines) | Bow/stern keel closure requires station density at `x_min`/`x_max` and centerline `Mirror(use_clip=True)`. |
| 8 | **Consumer Electronics / Enclosures** | Hard-surface `Recipe 2b` (`Bevel` -> `SubSurf`) + `Boolean(EXACT)` ports | Keep port cutters live until export; verify physical gap clearances (`clear_check`). |
| 9 | **Humanoid Characters / Mechs / Armor** | `human_base` (`<name>_joints`) + `human_head` (`*_M_*`) + `Recipe 2a` plates | Mount armor plates to joint markers; cover high-detail facial features with helmets/visors (`Recipes 15–16`). |
| 10 | **Firearms / Tracked Military / Multi-Part Assemblies** | Freeze `lib/spec.py` + `Recipe 2a` faceted plates + `Recipe 6b` tracks | Zero SubSurf on faceted plates; pin-chord pitch `p = 2R*sin(theta/2)` on tracks; full 10-gate assembly receipt. |

---

## 3. Fidelity Progression Levels (`S0` -> `S5`)

| Stage | Name | Definition & Exit Gate |
|-------|------|------------------------|
| **S0** | **Calibrated Draft** | `multiview_calib.py` passed (`resid <= 2%`, `disagree <= 3%`) + `shape_draft_check` passed (`R1–R3`). |
| **S1** | **Package & Blockout** | Primary volumes placed with `GEO-` names; overall bounding box within `+/-2%` of `T1_global`; `viewport` 3/4 check passed. |
| **S2** | **Primary Shell / Loft** | `shape_loft` / `shape_revolve` / `shape_regions` complete; multi-view orthographic silhouette `IoU >= 0.85` on all available views. |
| **S3** | **Feature Lines & Panel Seams** | `crease_lines`, `inset_lines`, and `shape_panels` applied; 45° key-light 900px render clearly shows all major plane breaks. |
| **S4** | **Secondary Parts & Clearances** | All child parts mounted; `clear_check` and `audit_connectivity` (`floaters=[]`, `gate.state=pass`) green. |
| **S5** | **Verified Delivery Receipt** | All 10 numeric gates in `SKILL.md §6` pass (`audit_scene(self_intersect=True)` -> `state=pass, clean=true`) with `.blend` MD5 and `fingerprint.digest` archived. |
