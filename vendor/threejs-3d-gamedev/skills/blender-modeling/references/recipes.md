# Blender Modeling Recipes (Recipes 1–24 & Generator Contract)

This reference contains the 24 verified code and declarative recipes for `blender-modeling`. All CLI examples use `node "$SKILL_DIR/scripts/blender-rt.mjs"`.

---

## 0. Generator Contract (Parameter Block + Generator Script)

Any parametric modeling script should separate its tunable numbers into a top-level `PARAMS` dictionary and register with the `generator_*` engine so parameter sweeps, caching, and staleness tracking work automatically.

| Action | CLI / Plan Op | Key Semantics |
|--------|---------------|---------------|
| Register / Save | `plan generator_save --args '{"name":"...","code":"...","params":{...}}'` | Saves generator script + default `PARAMS` and computes source digest |
| Run & Verify | `plan generator_run --args '{"name":"...","args":{...},"expect":{...}}'` | Runs in a clean headless Blender process; returns 3-state `verdict` + `receipt` |
| Inspect / Diff | `plan generator_list` / `generator_get` / `generator_diff` | `stale=true` means source changed after the last run -> previous receipt is invalidated |

### Re-running with New Parameters
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan generator_run --args '{
  "name": "rib_array",
  "args": {"n": 12, "pitch": 0.02},
  "expect": {"min_objects": 12}
}'
```

Or inside a headless Python script via the kernel:
```python
import json
r = K.dsh_generator_api["run"](
    name="rib_array",
    args={"n": 12, "pitch": 0.02},
    expect={"min_objects": 12},
)
r = json.loads(r) if isinstance(r, str) else r
print(r["verdict"], r["receipt"]["objects"], r["ms"])
```

### Generator Script Rules
1. **Read `PARAMS` (dict)**: The runner injects `PARAMS` before executing the script. Optionally print `print("DSH_RECEIPT " + json.dumps({...}))` (`import json` in your script), or let the runner auto-scan the scene to produce `receipt{PARAMS, objects, names, tris, bbox}`.
2. **Build from scratch (`clean_scene` default)**: Generator scripts run in a fresh headless process with only `PARAMS` + `bpy`/`bmesh`/`mathutils`. **Never** look up pre-existing scene objects (`bpy.data.objects['GEO-x']`), and note that **`K` and `audit_*` are NOT preloaded** inside `generator_run` (referencing `K` raises `NameError`). For scripts that call `audit_*` (like Recipe 9), use `generator_save`/`generator_diff` for version tracking and execute via `headless --preload audit`.
3. **Three-state `verdict`**:
   - `supported`: All conditions in `expect` passed.
   - `refuted`: One or more expectations failed (listed in `why`) or script threw an exception.
   - `unresolved`: No `expect` dict was provided — proves the script ran without crashing, NOT that the geometry is correct.
   *(Note: Blender's `--python` flag still exits with code `0` when a Python exception is raised; always check `verdict` and `stderr`, never exit code alone.)*

### Standard Parameter Blocks for Key Recipes

| Recipe | Default `PARAMS` Block |
|--------|------------------------|
| **2a** Faceted hard-surface | `{"bevel_width": 0.002, "bevel_segments": 1, "angle_deg": 30}` |
| **4** Boolean cutter | `{"cutter_radius": 0.3, "cutter_depth": 3.0, "solver": "EXACT", "apply": False}` |
| **5** Mirror modifier | `{"axis": "X", "use_clip": True, "merge_threshold": 0.001}` |
| **6b** Closed pin-chord array | `{"pitch": 0.176, "m": 6, "n_straight": 6}` (total count derived as `2*(m+n_straight)`) |
| **9** Assembly audit gate | `{"scope": "COL_Geo", "envelope": [...], "pairs": [["GEO-rungear", "GEO-hull"]]}` |

---

## Recipe 1 — Add Primitive & Rename Immediately

```python
import bpy
bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 1))
obj = bpy.context.active_object
obj.name = 'GEO-base_box'
print(f"created:{obj.name} verts:{len(obj.data.vertices)}")
```

Replace `primitive_cube_add` with `_plane_`, `_uv_sphere_`, `_ico_sphere_`, `_cylinder_`, `_cone_`, `_torus_`, or `_monkey_` with appropriate parameters (`radius`, `depth`, `vertices`, `segments`, `subdivisions`). All `primitive_*_add` operators are safe in headless mode because they do not depend on an active Edit Mode 3D Viewport context.

---

## Recipe 2a — Faceted Hard-Surface (Armor Plates / Military Models / Mechanical Panels) ★ Default for Panelized Subjects

```python
import bpy
obj = bpy.data.objects['GEO-armor_plate']

bevel = obj.modifiers.new('Bevel', type='BEVEL')
bevel.width = 0.002           # 2mm: breaks razor edges while keeping crisp creases
bevel.segments = 1            # 1 segment for faceted armor plates (use 2 for slightly softer edges)
bevel.limit_method = 'ANGLE'
bevel.angle_limit = 0.523599  # 30 deg in radians: only bevel edges sharper than this threshold

# DO NOT add SubSurf — SubSurf rounds faceted armor plates into "bars of soap"
for p in obj.data.polygons:
    p.use_smooth = False      # Flat shading so plane breaks between plates stay crisp
print(f"faceted:{obj.name} polys:{len(obj.data.polygons)}")
```

- **Criterion**: Edge highlights form a crisp thin line (from the Bevel), not a wide gradient (from SubSurf); plane breaks between adjacent plates remain clearly visible in renders. Any reference model where you can count individual plates or weld seams uses Recipe 2a.
- **Generator block (§0)**:
  ```python
  PARAMS = {"bevel_width": 0.002, "bevel_segments": 1, "angle_deg": 30}
  ```

---

## Recipe 2b — Smooth Hard-Surface (Automotive Sheet Metal / Rounded Props)

```python
import bpy
obj = bpy.data.objects['GEO-base_box']

# 1. Bevel first: round off sharp edges and provide support loops
bevel = obj.modifiers.new('Bevel', type='BEVEL')
bevel.width = 0.02            # 2cm fillet
bevel.segments = 3
bevel.limit_method = 'ANGLE'
bevel.angle_limit = 0.523599  # 30 deg in radians

# 2. Subdivision Surface MUST come AFTER Bevel
subsurf = obj.modifiers.new('SubSurf', type='SUBSURF')
subsurf.levels = 2
subsurf.render_levels = 3

# 3. Smooth shading
for p in obj.data.polygons:
    p.use_smooth = True
print(f"hardsurface:{obj.name} polys:{len(obj.data.polygons)}")
```

- **Ordering rule**: Putting `SubSurf` before `Bevel` causes pinching artifacts and shrinks the bounding box by ~15%.
- **Carrier rule**: Use Recipe 2b ONLY on continuously curved surfaces (car bodies, consumer electronics, rounded housings). Applying `SubSurf` to faceted plates (Recipe 2a) destroys their silhouette.

---

## Recipe 3 — Edit Mode: Extrude / Inset / Loop Cut (GUI Only; Use 3b for Headless)

```python
import bpy
obj = bpy.data.objects['GEO-base_box']
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode='EDIT')

bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.extrude_region_move(TRANSFORM_OT_translate={'value': (0, 0, 1.0)})
bpy.ops.mesh.inset(thickness=0.1, depth=0)
bpy.ops.mesh.loopcut_slide(
    MESH_OT_loopcut={'number_cuts': 1, 'edge_index': 0},
    TRANSFORM_OT_edge_slide={'value': 0.0},
)
bpy.ops.object.mode_set(mode='OBJECT')
print(f"edited:{obj.name} verts:{len(obj.data.vertices)}")
```

---

## Recipe 3b — Equivalent `bmesh` Implementation (★ Required for `headless` / Batch Scripts)

```python
import bmesh, bpy
obj = bpy.data.objects['GEO-base_box']
bm = bmesh.new()
bm.from_mesh(obj.data)

# 1) Select the upward-facing face by normal (no reliance on Edit Mode selection state)
up = [f for f in bm.faces if f.normal.z > 0.9]
face = up[0]

# 2) Extrude + translate (equivalent to extrude_region_move)
res = bmesh.ops.extrude_face_region(bm, geom=[face])
new_verts = [g for g in res['geom'] if isinstance(g, bmesh.types.BMVert)]
bmesh.ops.translate(bm, verts=new_verts, vec=(0.0, 0.0, 1.0))

# 3) Inset (equivalent to mesh.inset)
top = [f for f in bm.faces if f.normal.z > 0.9 and f.calc_center_median().z > 1.0]
bmesh.ops.inset_individual(bm, faces=top, thickness=0.1, depth=0.0)

bm.to_mesh(obj.data)
bm.free()
obj.data.update()
print(f"bmesh-edited:{obj.name} verts:{len(obj.data.vertices)}")
```

**Why `bmesh` is preferred**: `bpy.ops.mesh.*` requires an active object in Edit Mode, valid selection state, and a `VIEW_3D` region context — which is frequently absent in `blender -b`, failing with `Operator ... poll() failed, context is incorrect`. `bmesh` manipulates mesh data directly with zero context dependencies.

---

## Recipe 4 — Boolean Difference Cutter (Surgical Use)

```python
import bpy
target = bpy.data.objects['GEO-base_box']
cutter = bpy.data.objects.get('GEO-cutter')
if cutter is None:
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=3.0, location=(0, 0, 1))
    cutter = bpy.context.active_object
    cutter.name = 'GEO-cutter'

mod = target.modifiers.new('Boolean', type='BOOLEAN')
mod.operation = 'DIFFERENCE'
mod.object = cutter
mod.solver = 'EXACT'

bpy.context.view_layer.objects.active = target
# Keep live (do not apply) until export if non-destructive workflow is desired:
bpy.ops.object.modifier_apply(modifier=mod.name)
cutter.hide_viewport = True
cutter.hide_render = True
print(f"booleaned:{target.name}")
```

- **Surgical rule**: Use Booleans only for true cutouts (muzzle bores, turret ring undercuts, bolt holes). Build primary forms by assembling distinct plate parts rather than carving everything out of one block.
- **Generator block (§0)**: `PARAMS = {"cutter_radius": 0.3, "cutter_depth": 3.0, "solver": "EXACT", "apply": False}`.

---

## Recipe 5 — Mirror Modifier (Model Half, Mirror Across Centerline)

```python
import bpy
obj = bpy.data.objects['GEO-character_half']
mod = obj.modifiers.new('Mirror', type='MIRROR')
mod.use_axis[0] = True     # Mirror across X
mod.use_clip = True        # Clamp centerline vertices
mod.use_mirror_merge = True
mod.merge_threshold = 0.001
print(f"mirrored:{obj.name}")
```

- **Ordering**: Put `Mirror` at the **very top** of the modifier stack (before `Bevel` / `SubSurf`) so the centerline seam is welded before edges are beveled or subdivided.
- **Evaluation caveat**: `audit_mesh` inspects unevaluated `ob.data` (so an unapplied half-mesh reports `boundary_edges > 0` along the open centerline). Apply `Mirror` before asserting `boundary_edges == 0` in `audit_mesh`. By contrast, assembly-level `audit_connectivity`, `audit_gate`, `audit_measure`, and `audit_interference` inspect the **evaluated** mesh (`evaluated_get(depsgraph)`).

---

## Recipe 6 — Array + Curve Modifier (Decorative Repeats Only)

```python
import bpy
bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0, 0, 0))
unit = bpy.context.active_object
unit.name = 'GEO-bead'

path = bpy.data.objects.get('GEO-path')
if path is None:
    bpy.ops.curve.primitive_bezier_curve_add()
    path = bpy.context.active_object
    path.name = 'GEO-path'

arr = unit.modifiers.new('Array', type='ARRAY')
arr.fit_type = 'FIT_CURVE'
arr.curve = path
arr.relative_offset_displace = (1.0, 0, 0)

crv = unit.modifiers.new('Curve', type='CURVE')
crv.object = path
crv.deform_axis = 'POS_X'
print(f"arrayed:{unit.name}")
```

> **Carrier limitation**: `FIT_CURVE` + `Curve` deforms each element and cannot guarantee exact rigid pin-to-pin chord pitch or seamless loop closure. Use Recipe 6 only for decorative beads, fences, or rivets; for tank tracks, chains, or gear rings, use **Recipe 6b**.

---

## Recipe 6b — Parametric Closed-Path Pin-Chord-Pitch Array (★ Tank Tracks / Chains / Ring Gears)

### Arc-Length Pitch vs. Pin-Chord Pitch
Mechanical links are rigid bodies whose pin centers are separated by a fixed **straight-line chord distance** $p$, not arc length:

| Pitch Definition | Formula | On Straight Segments | On Circular Arcs (radius $R$) |
|------------------|---------|----------------------|-------------------------------|
| **Arc-length pitch** | Divide total curve length into $N$ equal arcs | $\text{chord} = \text{arc} = p$ | $\text{chord} < p$ (chords are always shorter than arcs; cumulative error of $-11.75\text{ mm}$ over two semicircles at $p=176\text{ mm}, M=6$) |
| **Pin-chord pitch (Mechanical truth)** | Straight-line distance between adjacent pins is identically $p$ | $= p$ | $p = 2R\sin(\theta/2)$, so $R = \frac{p}{2\sin(\pi / (2M))}$ and arc length $R\theta > p$ (measured error $\le 3.3\times 10^{-6}\text{ mm}$) |

```python
import bpy, bmesh, math
from mathutils import Vector

# ── Parameter Block (pin-chord pitch + integer link counts per semicircle M and straight N_STR)
PITCH    = 0.176     # m, pin-to-pin straight-line chord pitch
M        = 6         # integer number of links on each semicircle
N_STR    = 6         # integer number of links on each straight run
#   => Total links N = 2*(M + N_STR); radius R and straight length A are solved from PITCH:
#      R = PITCH / (2*sin(pi/(2*M)))      A = N_STR * PITCH
TEMPLATE = "GEO-track_link"
BODY_W, THICK = 0.12, 0.02

def build_link_template(name, pitch, body_w, thick):
    """Build a single track link from scratch honoring the 5 Template Contracts:
      1. Origin = start pin axis center (NOT the geometric center of the plate) so ob.location lands on path pins.
      2. Local +X = points toward the next pin axis (aligned via to_track_quat('X', 'Z')).
      3. Next pin axis = local (+pitch, 0, 0) so pin-to-pin length equals PITCH.
      4. Pin axis direction = local +Z (up-axis of to_track_quat('X', 'Z')), thickness centered on Z.
      5. Template X/Y location is ignored; only template Z is preserved as the track plane Z.
    """
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = (v.co.x + 0.5) * float(pitch)  # x in [0, pitch]: 0 is start pin axis
        v.co.y *= float(body_w)                 # y in [-body_w/2, +body_w/2]
        v.co.z *= float(thick)                  # z in [-thick/2, +thick/2]
    bm.to_mesh(me); bm.free(); me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def stadium_pins(p, m, n):
    """Closed stadium path: top straight (+X) -> right semicircle -> bottom straight (-X) -> left semicircle."""
    R = p / (2.0 * math.sin(math.pi / (2.0 * m)))
    A = n * p
    hx, th = A / 2.0, math.pi / m
    pts = []
    for i in range(n):                                        # Top straight
        pts.append((-hx + i * p, R))
    for i in range(m):                                        # Right semicircle 90 deg -> -90 deg
        a = math.pi / 2 - i * th
        pts.append((hx + R * math.cos(a), R * math.sin(a)))
    for i in range(n):                                        # Bottom straight
        pts.append((hx - i * p, -R))
    for i in range(m):                                        # Left semicircle -90 deg -> -270 deg
        a = -math.pi / 2 - i * th
        pts.append((-hx + R * math.cos(a), R * math.sin(a)))
    return pts

pts = stadium_pins(PITCH, M, N_STR)
N = len(pts)                                                  # = 2*(M + N_STR)

tpl = build_link_template(TEMPLATE, PITCH, BODY_W, THICK)
tpl.location = (0.0, 0.0, 0.0)
for i, (x, y) in enumerate(pts):
    ob = tpl.copy()
    bpy.context.collection.objects.link(ob)
    ob.location = (x, y, tpl.location.z)
    d = Vector((pts[(i + 1) % N][0] - x, pts[(i + 1) % N][1] - y, 0.0))
    ob.rotation_euler = d.to_track_quat('X', 'Z').to_euler()
    ob.name = "%s_%03d" % (TEMPLATE, i)
bpy.data.objects.remove(tpl, do_unlink=True)                  # Remove template so object count is exactly N

# ── Numeric Verification (never rely on visual inspection alone)
made = [bpy.data.objects["%s_%03d" % (TEMPLATE, i)] for i in range(N)]
ch = [(made[i].location - made[(i + 1) % N].location).length for i in range(N)]
xs = [o.location.x for o in made]
R = PITCH / (2.0 * math.sin(math.pi / (2.0 * M))); A = N_STR * PITCH
print("N=%d  max|chord-p|=%.6fmm  closure=%.6fmm" %
      (N, max(abs(c - PITCH) for c in ch) * 1000, ch[-1] * 1000))
print("bbox_x=%.6f (expected A+2R=%.6f)  perimeter=2A+2*pi*R=%.6f  N*p=%.6f" %
      (max(xs) - min(xs), A + 2 * R, 2 * A + 2 * math.pi * R, N * PITCH))
```

### Mandatory Verification & Audit Interpretation for Recipe 6b
1. **Chord pitch accuracy**: `max|chord - PITCH| <= 0.001 mm` (measured `3.3e-6 mm`).
2. **Loop closure**: Last-to-first pin chord equals `PITCH` (`175.999998 mm`).
3. **Object count**: Exactly `N = 2*(M + N_STR)` objects (`tpl` MUST be removed).
4. **Bounding box vs. Perimeter (do not confuse the two)**:
   - Pin-center X span (`bbox_x` of pin origins): `A + 2R` (`1.736012 m` at `PITCH=0.176, M=N_STR=6`).
   - Path arc perimeter: `2A + 2*pi*R` (`4.248320 m`).
   - Total chord polygon perimeter: `N * PITCH` (`4.224000 m`, shorter than arc perimeter by `24.32 mm`).
5. **How to read assembly audit tools on touching track links**:
   - `audit_mesh(objects=24 links, self_intersect=true)` -> `state=pass, clean=true, closed=true, normals_state=pass`.
   - `audit_connectivity` -> `floaters=[], gate.state=pass`, while `components=14` (2 straight runs + 12 arc links). **Check `floaters` and `gate.state`, NOT `components == 1`**, because un-welded touching rigid bodies naturally form multiple mesh components.
   - `audit_overlap(a=link_0, b=link_1)` -> `pair_count = 1` (the shared `120 mm` end-face edge). Flush face/edge contact produces `pair_count >= 1`; do not misread it as interpenetration.
   - `audit_interference(a=link_0, b=link_1)` -> `verdict="unresolved", volume_mm3=0.0` (0 of 200k Monte Carlo points fall inside both links; statistical upper bound `6.33 mm³ > 1.0 mm³` floor). Whitelist intentional flush pin joints in your spec interface table.

---

## Recipe 7 — Blockout Staging

```python
import bpy
bpy.ops.mesh.primitive_plane_add(size=10)
bpy.context.active_object.name = 'GEO-floor'
bpy.ops.mesh.primitive_cube_add(size=1.5, location=(0, 0, 0.75))
bpy.context.active_object.name = 'GEO-subject'
bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=2, location=(2, 1.5, 1))
bpy.context.active_object.name = 'GEO-prop_pillar'
print('blockout:done')
```

---

## Recipe 8 — Post-Curve / Post-Boolean Mesh Cleanup

```python
import bpy, bmesh
obj = bpy.data.objects['GEO-target']
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # Prerequisite for all interference checks
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
for p in obj.data.polygons:
    p.use_smooth = True
print(f"cleanup:{obj.name} verts:{len(obj.data.vertices)}")
```

---

## Recipe 9 — Assembly Audit Gate

Run all numeric gates before handoff or export:

```bash
# 1. Collection connectivity + bounding envelope gate
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_gate \
  --blend /tmp/scene.blend --args '{"scope":"COL_Geo"}'

# 2. Pairwise Monte Carlo + BVH interference check
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_interference \
  --blend /tmp/scene.blend --args '{"a":"GEO-rungear","b":"GEO-hull"}'

# 3. Bounding boxes + neighbor clearance / overlap table
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_measure \
  --blend /tmp/scene.blend --args '{"neighbors":true}'
```

Or inside `headless --preload audit`:
```python
K.dsh_audit_api("mesh", {"objects": ["GEO-hull"]})
K.dsh_audit_api("connectivity", {"scope": "COL_Geo"})
K.dsh_audit_api("gate", {"scope": "COL_Geo", "envelope": ENVELOPE})
```

> **Generator + Headless pattern (§0)**: Register the audit script with `plan generator_save` and check `plan generator_diff` (`changed=true` invalidates old receipts), then execute it via `headless --preload audit --file <generator_path>` because `generator_run` does not preload `K` or `audit_*`.

---

## Recipe 10 — Dual-Evidence Form Verification (Fixed-Camera Views + Numeric BBox)

```bash
# 1. Numeric evidence: compare measured bounding boxes against spec.py tolerances (e.g. +/-3mm)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_measure \
  --blend /tmp/scene.blend --args '{"objects":["GEO-turret"],"neighbors":false}'

# 2. Visual evidence: render from the exact reference camera viewpoints with 3-point lighting
node "$SKILL_DIR/scripts/blender-rt.mjs" plan qc_render_views \
  --blend /tmp/scene.blend --args '{
    "views": [{"name":"front","from":[0,-12,1.6],"look_at":[0,0,1.6],"lens":50}],
    "res": [1280, 720], "samples": 64, "outdir": "/tmp/qc_views"
  }'
```

Neither check is sufficient on its own: numeric bbox catches a 6° pitch error on a fender, while fixed-camera renders reveal bad seam proportions.

---

## Recipe 11 — Procedural Sculpting (Voxel Remesh -> Displacement Brushes -> Mask -> Filter)

Supports 6 headless-compatible NumPy displacement brushes (`draw`, `inflate`, `pinch`, `flatten`, `smooth`, `crease`), topology setup (`VOXEL`, `MULTIRES`, `SUBDIV`, `DYNTOPO`), `.sculpt_mask` sphere/box masking, and GUI mesh filters.

```bash
# 1. Scan & voxel remesh ("auto" solves voxel_size from a 40M cell safety budget)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sculpt_scan --blend /tmp/head.blend --args '{"objects":["GEO-head"]}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sculpt_setup --blend /tmp/head.blend --args '{
  "object": "GEO-head", "mode": "VOXEL", "voxel_size": "auto", "symmetry": ["x"]
}'

# 2. Apply displacement strokes (each symmetry axis mirrors as an independent stroke)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sculpt_apply --blend /tmp/head.blend --args '{
  "object": "GEO-head",
  "strokes": [
    {"brush":"draw",   "points":[[0,0,1.0],[0.12,0,1.06]], "radius":0.45, "strength":0.7},
    {"brush":"crease", "points":[[0.7,0,0.7]], "radius":0.15, "strength":0.9, "symmetry":["x"]},
    {"brush":"smooth", "points":[[0,0,1.1]], "radius":0.30, "strength":0.5}
  ]
}'

# 3. Mask a region (subsequent sculpt_apply calls honor use_mask=true by default)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sculpt_mask --blend /tmp/head.blend --args '{
  "objects": ["GEO-head"], "mode": "sphere", "center": [0,0,1], "radius": 0.6
}'
```

> **Checkpoint first**: Always run `txn mark --tag pre-sculpt` before sculpting.

---

## Recipe 12 — Mesh Repair & UV Pipeline (`audit_mesh` Diagnoses, `fix_*` & `uv_*` Treat)

```bash
# 1. Read-only diagnosis
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_mesh --blend /tmp/part.blend --args '{"objects":["GEO-part"]}'

# 2. Safe repair (merge doubles, dissolve degenerate, delete loose verts/edges, recalc normals)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan fix_repair --blend /tmp/part.blend --args '{
  "objects": ["GEO-part"],
  "actions": ["merge_doubles", "dissolve_degenerate", "delete_loose", "recalc_normals"]
}'

# 3. Optional decimation
node "$SKILL_DIR/scripts/blender-rt.mjs" plan fix_decimate --blend /tmp/part.blend --args '{
  "objects": ["GEO-part"], "target_tris": 2000
}'

# 4. UV unwrapping, packing, and zero-area UV verification
node "$SKILL_DIR/scripts/blender-rt.mjs" plan uv_smart_project --blend /tmp/part.blend --args '{"objects":["GEO-part"],"angle_limit":66}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan uv_unwrap        --blend /tmp/part.blend --args '{"objects":["GEO-part"],"method":"SLIM"}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan uv_pack          --blend /tmp/part.blend --args '{"objects":["GEO-part"],"margin":0.002}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan uv_stats         --blend /tmp/part.blend --args '{"objects":["GEO-part"]}'
```

---

## Recipe 13 — Printability Check: Wall Thickness & Overhang Angle

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan print_report --blend /tmp/part.blend --args '{
  "objects": ["GEO-part"], "min_mm": 1.2, "max_angle_deg": 45
}'
```

- Casts rays inward (`-normal`) from sampled face centers to measure local wall thickness (`min`, `p05`, `median`, `max`) and computes overhang area fraction (`angle <= max_angle_deg`).
- **Resolution caveat**: Check `resolution_mm` (local face size) in the receipt. If `min_mm < resolution_mm`, the receipt warns that the mesh is too coarse to resolve that wall thickness — subdivide or remesh finer first.

---

## Recipe 14 — Path Sweep: Pipes, Cables, Hose Routing (`sweep_analyze` -> `sweep_build`)

```bash
# 1. Check minimum bend radius against profile half-width to prevent self-intersection
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sweep_analyze --args '{
  "path": [[0,0,0], [0.6,0,0], [0.6,0,0.6]],
  "profile": {"type": "circle", "radius": 0.05}
}'

# 2. Build sweep using a rotation-minimizing frame (no twisting at corners)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan sweep_build --args '{
  "name": "GEO-hose",
  "path": [[0,0,0], [0.6,0,0], [0.6,0,0.6], [1.2,0,0.6]],
  "profile": {"type": "circle", "radius": 0.05, "segments": 12},
  "cap": true
}'
```

---

## Recipe 15 — Parametric Humanoid Base Mesh (Zero External Assets)

```bash
# 1. Optional: extract pixel proportions from a front reference image
node "$SKILL_DIR/scripts/blender-rt.mjs" plan human_spec --args '{"image":"/path/to/front.png"}'

# 2. Build mannequin base mesh + 19 joint Empty markers in <name>_joints collection
node "$SKILL_DIR/scripts/blender-rt.mjs" plan human_base --args '{
  "height_mm": 1750, "heads": 7.5, "pose": "A", "name": "GEO-human"
}'

# 3. Verify measured head-to-body and shoulder-to-head ratios
node "$SKILL_DIR/scripts/blender-rt.mjs" plan human_measure --args '{"name":"GEO-human"}'
```

**Hard rules**:
1. `human_base` produces a clean proportion mannequin (`Skin` + `SubSurf`), not an anatomical sculpt.
2. Always attach armor plates or props to the 19 `<name>_joints` markers (`pelvis`, `chest`, `shoulder_l`, ..., `foot_r`), never by eye.

---

## Recipe 16 — Parametric Head, Facial Landmarks & the "Mask/Visor" Strategy

```bash
# 1. Generate parametric head + 6 facial Empty markers (crown, chin, eye_l, eye_r, nose_base, mouth)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan human_head --args '{
  "head_mm": 233, "name": "GEO-head",
  "landmarks": {
    "top": [0,0], "chin": [0,400], "face_l": [-150,200], "face_r": [150,200],
    "eye_l": [-70,200], "eye_r": [70,200], "nose_base": [0,290]
  }
}'

# 2. Check landmark ratios against classical or custom spec tolerances
node "$SKILL_DIR/scripts/blender-rt.mjs" plan face_ratios --args '{"landmarks":{...}}'
```

**Hard rule**: Procedural recipes with zero external scan assets cannot fabricate realistic pores, eyelids, or wrinkles. When building characters from scratch without external head scans, cover high-detail facial regions with **helmets, visors, or masks** and mount facial hardware directly onto the `*_M_*` landmark empties.

---

## Recipe 17 — Vehicle Shell: Package Proportion Gate -> Loft -> Ortho IoU Loop

```bash
# 1. Proportion gate first (do not build shell until package ratios pass)
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_package --args '{
  "spec": {
    "type": "sports", "length_mm": 4300, "width_mm": 1850, "height_mm": 1250,
    "wheelbase_mm": 2600, "front_axle_from_front_mm": 900,
    "wheel_r_mm": 340, "wheel_w_mm": 245, "track_mm": 1580
  }
}'

# 2. Build shell with Boolean-cut wheel arches and dense stations around wheel rims
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_base --args '{"spec":{...}, "name":"GEO-car"}'

# 3. Dual verification: wheel-to-arch clearance + orthographic silhouette IoU
node "$SKILL_DIR/scripts/blender-rt.mjs" plan clear_check --args '{
  "pairs": [{"id":"wheel_fl", "a":["GEO-car_wheel_fl"], "b":["GEO-car"], "min_mm":8}]
}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan qc_render_views --args '{
  "views": ["right"], "ortho": true, "ref_path": "/path/to/side.png"
}'
```

---

## Recipe 18 — Complex Shell from 3-Views: Stations -> Parametric Loft -> Panel Gaps -> Multi-View IoU

Applies to any object with a clear orthographic silhouette (vehicles, hulls, aircraft fuselages, helmets, footwear, appliances, weapon receivers, robot shells).

```bash
# 1. Extract station table from side + top + front views
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_sections --args '{
  "side": "/path/to/side.png", "top": "/path/to/top.png", "front": "/path/to/front.png",
  "mm_per_px": 3.2, "stations": 41, "wheel_r_px": 106
}'

# 2. Loft shell from stations + cross-section character parameters
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_loft --args '{
  "stations": [...], "name": "GEO-shell",
  "n_top": 5, "n_bot": 3, "tumblehome_mm": 120, "beltline_frac": 0.55,
  "shoulder_inset_mm": 25, "sill_tuck_mm": 60, "flare_mm": 30,
  "subsurf": 1, "crease_shoulder": 0.7
}'

# 3. Cut physical panel gaps and verify clearance
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_panels --args '{
  "object_name": "GEO-shell", "cuts_mm": [1500, 3000], "gap_mm": 4
}'
node "$SKILL_DIR/scripts/blender-rt.mjs" plan clear_check --args '{
  "pairs": [{"id":"hood_door", "a":["GEO-shell"], "b":["GEO-shell.001"], "min_mm":0}]
}'
```

**Hard rules**:
1. Without a top view, `half_w_mm` plan taper is unknown (a car body will default too narrow unless top view or front max width is supplied).
2. Edge creases in Blender 4+/5.x use the `crease_edge` attribute (`e.crease_weight` was removed).
3. Silhouette IoU is necessary but not sufficient — always pair per-view IoU (`right`, `front`, `top` separately) with `clear_check`, `audit_measure`, and feature-line checks.

---

## Recipe 19 — Shell Reconstruction Trio: Front `section_shape` / `vehicle_fit` / `vehicle_regions`

- **Exact loft from 3 views**: `vehicle_sections` extracts `stations[]` plus the normalized front cross-section `section_shape[{z_frac, hw_frac}]`; pass both directly into `vehicle_loft`.
- **Reusable parametric spec via 2D IoU fitting**: `plan vehicle_fit --args '{"stations":[...],"iterations":240,"target_iou":0.9}'` fits a 15-parameter vehicle spec in pure 2D without rendering.
- **Multi-volume segmentation (trucks / armor / sci-fi rigs)**: `plan vehicle_regions --args '{"stations":[...],"name":"GEO-truck","regions":[{"name":"cab","x0_mm":0,"x1_mm":2200},{"name":"bed","x0_mm":2250,"x1_mm":6000}]}'`.

---

## Recipe 20 — Perspective Photo Rectification (`img_rectify`)

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan img_rectify --args '{
  "path": "/path/to/photo.jpg",
  "quad": [[x1,y1], [x2,y2], [x3,y3], [x4,y4]],
  "out_w": 1600, "out_h": 600, "known_w_mm": 4300,
  "out": "/tmp/rectified_side.png"
}'
```

**Hard rule (Single-Plane Limitation)**: A 4-point homography only rectifies the **exact plane containing those 4 points**. Features at depth $\Delta z$ off that plane suffer perspective projection error ($\approx 52\text{ mm}$ at $\Delta z = 0.05\text{ m}$, $211\text{ mm}$ at $0.2\text{ m}$, and $543\text{ mm}$ at $0.5\text{ m}$ under a typical $1\text{ m} \approx 190\text{ px}$ camera). Never trust off-plane measurements (such as flared fenders or recessed cabins) from a single-plane homography.

---

## Recipe 21 — Polyline Family K-Sweep (`vehicle_fit` with `family="polyline"`)

When a boxy truck, pickup, or armored hull stalls around `IoU ~ 0.67` with the 15-parameter sports/sedan family, switch to the `polyline` family and sweep control point counts `K`:

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan vehicle_fit --args '{
  "stations": [...],
  "family": "polyline",
  "control_points": [6, 10, 16],
  "iterations": 200
}'
```

Measured progression on boxy hulls: `cargen` family `0.667` -> polyline `K=6` `0.754` -> `K=10` `0.781` -> `K=16` `0.821`.

---

## Recipe 22 — Parametric Feature Lines (`crease_lines` & `inset_lines`)

Pass `crease_lines` and `inset_lines` directly to `vehicle_loft` (or `shape_loft`):

```json
{
  "crease_lines": [
    {"frac": 0.55, "weight": 0.8},
    {"frac": 0.55, "radius_mm": 6.0, "segments": 3},
    {"z_mm": 560, "x_mm": [400, 3900], "weight": 0.85},
    {"x_mm": 1500, "radius_mm": 4.0, "segments": 2}
  ],
  "inset_lines": [
    {"z_mm": 470, "band_mm": 60, "inset_mm": 12, "x_mm": [500, 3800]}
  ]
}
```

- Use `frac` (fraction of each station ring's local height) rather than fixed `z_mm` for sweeping beltlines.
- Omit `radius_mm` for sharp SubD creases (requires `subsurf >= 1`); provide `radius_mm` + `segments` (`1..8`) to generate true circular-arc Bevel fillets via edge bevel weights.

---

## Recipe 23 — Multi-Step Pipeline Execution (`pipe_run` + `@artifact` References)

Chain multiple domain operations in a single call without copying huge JSON arrays (like 41-station tables) back and forth through the LLM context window:

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan pipe_run --args '{
  "steps": [
    {"api":"vehicle", "op":"sections", "args":{"side":"/tmp/side.png","front":"/tmp/front.png","mm_per_px":10.0}, "out":"@sec"},
    {"api":"vehicle", "op":"loft",     "args":{"stations":"@sec.stations","section_shape":"@sec.section_shape","name":"GEO-shell"}, "out":"@shell"},
    {"api":"vehicle", "op":"panels",   "args":{"object_name":"@shell.object","cuts_mm":[1500,3000],"gap_mm":4}, "out":"@panels"},
    {"api":"clearance","op":"check",   "args":{"pairs":[{"id":"seam","a":["@panels.parts.0"],"b":["@panels.parts.1"],"min_mm":0}]}}
  ]
}'
```

Manage session artifacts manually with `pipe_put`, `pipe_list`, `pipe_get`, and `pipe_clear`.

---

## Recipe 24 — In-Blender Parameter Search (`loop` & Declarative `plan shape_search`)

Use when: (1) the objective is a single scalar (`silhouette_iou`, `aabb_err`, `profile_err`), (2) you need 20–2,000 evaluations, and (3) **a live GUI Blender session is connected** (`bpy.app.timers` does not fire in headless `blender -b`; for headless 2D contour fitting use `vehicle_fit` / `shape_fit`).

### Declarative `shape_search` (Recommended)
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan shape_search --args '{
  "objective": "silhouette_iou",
  "ref": "/tmp/side_ref.png",
  "view": {"from": [0,-6,1.0], "look_at": [0,0,0.5], "lens": 50},
  "apply": "ob.location.y = p[\"dy_mm\"]/1000.0\n    bpy.context.view_layer.update()",
  "params": {
    "dy_mm": {"min": -30, "max": 30, "step": 5},
    "dz_mm": {"min": -20, "max": 20, "step": 5}
  },
  "iterations": 300, "budget_ms": 60000, "top_k": 10,
  "export": "/tmp/best_fit.py"
}'
```

### Mandatory Search Discipline
1. **Always call `bpy.context.view_layer.update()`** inside `apply(p)` after mutating transforms, otherwise dependency-graph queries read stale geometry from the previous iteration.
2. **Apply `BEST` after search**: Raw `loop` stops on the *last* evaluated candidate, not `best`; use `loop export` (or `shape_search`, which automatically restores `best`).
3. **Cross-path verification**: Never treat the internal search score as final acceptance. Re-verify the winning parameters via `qc_render_views` + `audit_measure` + `see --size 900`.
