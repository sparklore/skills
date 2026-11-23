---
name: blender-modeling
description: "End-to-end 3D modeling, sculpting, multi-agent assembly, reference reconstruction, and rendering in Blender via local bridge CLI."
license: MIT (adapted from RobLe3/cc-blender-skill and arjun988/blender-skills; see NOTICE.md)
---

# Blender Modeling & Assembly Skill (`blender-modeling`)

Choose the right geometry carrier first, follow the step-by-step pipeline, and verify every step with **both visual and numeric evidence**. Never write an entire complex model in one blind pass.

---

## 0. Bundled CLI Tooling & Channel Semantics (`scripts/blender-rt.mjs`)

This skill bundles a self-contained Blender bridge (`runtime/`, `addon/`, and `scripts/blender-rt.mjs`) that connects to a live Blender GUI (`127.0.0.1:9876`) or spawns headless `blender -b` processes with a persistent Python kernel `K`.

```bash
SKILL_DIR="${BLENDER_SKILL_DIR:-$HOME/.agents/skills/blender-modeling}"
node "$SKILL_DIR/scripts/blender-rt.mjs" <subcommand> [action] [options]
```

> Full CLI flags, environment variables (`BLENDER_RT_*`), and troubleshooting: see [`references/cli-reference.md`](references/cli-reference.md).

| Task | CLI Subcommand | Key Semantics |
|------|----------------|---------------|
| **Launch / check Blender GUI** | `viewport open` / `viewport status` | Idempotently launches Blender with `addon/blender_bridge.py` enabled and polls TCP port `9876`. |
| **Interactive modeling ("edit one step, see one frame")** | `do --code '...' --see` | Runs on the live GUI main thread (~105 ms) with `bpy`, `bmesh`, `mathutils`, `C`, `D`, `O` pre-imported; pushes an Undo step; saves a viewport PNG (`image_path` in output JSON — view with `read_file`). |
| **In-Blender parameter search / fitting (20–2,000 evals)** | `loop start/status/board/export` or `plan shape_search` | Runs at ~160 ticks/s inside Blender via `bpy.app.timers` (`K.dsh_measure`: `silhouette_iou`, `aabb_err`, `profile_err`). **GUI session only** (timers do not fire in `blender -b`). After convergence, always re-verify via an independent path (`Recipe 24`). |
| **Batch / heavy execution (Primary Path for multi-agent)** | `headless --preload ... --file ...` | Spawns a fresh `blender -b --factory-startup` process with persistent kernel `K`. Variables do NOT persist across calls; always `import bpy` and load/save `.blend` files explicitly. |
| **Long-running renders / bakes (> 2 min)** | `job start/status/list/cancel` | Asynchronous background job with progress tracking and log retention under `jobs/<id>/`. |
| **Warm headless daemon** | `worker start/exec/reset/stop` | Keeps a persistent `blender -b` worker alive on `:9878` so cold start is paid once. **Single-instance serial** — do NOT share across parallel builders. |
| **Viewport capture & animation burst** | `see` / `watch` | `see` captures a single frame (`--size 420` for iteration, `--size 900` for QC) + `frame_hash` (MD5). `watch` records burst frames across timeline ticks. |
| **Checkpoints & rollback** | `txn mark/revert/diff/list` | Snapshots the scene before risky operations (Booleans, remeshing, sculpting) and restores in one call. |
| **Assembly & mesh audit gates (Numeric Gates ①–⑩)** | `plan audit_*` | `audit_mesh`, `audit_scene`, `audit_connectivity`, `audit_gate`, `audit_interference`, `audit_overlap`, `audit_measure`, `audit_snap_floaters` (see §6). |
| **Fixed-camera QC renders & part-color maps** | `plan qc_render_views` | Auto-framed 3-point studio renders with per-view MD5 + `coverage_estimate`; supports `mode="parts_color"` and `ortho=True` reference silhouette comparison. |
| **Parametric recipe generators** | `plan generator_*` | `generator_save`, `generator_run`, `generator_list`, `generator_get`, `generator_diff` (`§3` & `references/recipes.md §0`). |
| **Declarative domain engines (28 families / 186 ops)** | `plan <op> --args '{...}'` | Run `plan catalog --args '{"verify":true}'` to inspect all 28 families (`vehicle_*`, `shape_*`, `sculpt_*`, `uv_*`, `fix_*`, `print_*`, `sweep_*`, `human_*`, `pipe_*`, etc.). |
| **Read user GUI selection & activity** | `selection latest/live/collections/activity` | Reads active/selected objects, Edit Mode vert/edge/face counts, and `AI_PAUSED` status when the user is actively editing in the GUI. |

### Write-Lease Arbitration & Independent Verification
- **Multi-agent write lease**: GUI write commands automatically carry a lease `--holder <id>`. If another agent holds the lease, the server returns `HTTP 409 leased`. For multi-agent parallel modeling, **always use `headless`** (isolated processes) rather than fighting over the single GUI viewport lease.
- **Independent verification subagent**: When delegating acceptance review to a subagent, do **not** make it load this full `SKILL.md`. Point it directly to [`references/verification-checklist.md`](references/verification-checklist.md) (~1.5k tokens).

---

## 0.5 Multi-Agent Parallel Modeling Protocol (★ Mandatory for Complex Assemblies)

Before spawning builder subagents, run `node "$SKILL_DIR/scripts/blender-rt.mjs" plan catalog --args '{"handoff":true}'` and paste its ~2.5 KB output directly into each subagent's prompt so they use the built-in declarative engines (`vehicle_*`, `shape_*`, `audit_*`) instead of reinventing lofts or audits in raw Python.

### 0.5.0 S0 Mental Draft Before Freezing Specs (`shape_draft` -> `shape_draft_check`)
Before measuring exact millimeter dimensions or counting meshes, create a 4-table **S0 Mental Draft** (`T1` Identification & Scale Tier `A–F`, `T2` Production Units, `T3` Form & Carrier, `T4` Spatial Features) via `plan shape_draft` and validate it with `plan shape_draft_check`:
1. **`R1` No fabricated exact dimensions in S0**: Use scale tiers (`A–F`) or relative ratios (`0.3x`). Writing `"450mm"` before reference calibration is rejected (`check_mm_rejected=true`).
2. **`R2` No mesh counting in S0**: Do not call `audit_scene`, `audit_mesh`, or `print_report` during S0 planning.
3. **`R3` No premature lock-in**: Tag every field with `confidence` + `source` (`unknown` if unseen) and list `to_confirm` items for each unit.
*(See [`references/reference-reconstruction-sop.md`](references/reference-reconstruction-sop.md) for the complete 9-step SOP.)*

### 0.5.1 Freeze `lib/spec.py` First (Single Source of Truth)
Once S2 reference calibration is complete, the Lead agent freezes `lib/spec.py` (all builders treat `lib/spec.py` as **read-only**):

```python
# lib/spec.py — Single source of truth (read-only for builders)
TOTAL = {"length": 9.83, "width": 3.66, "height": 2.88}  # meters (state clearly: includes barrel & skirts)
WHEEL_R, WHEEL_W, WHEELBASE = 0.33, 0.20, 4.60
DECK_Z, HULL_BOTTOM_Z = 1.62, 0.42
PARTS = {
    "GEO-hull":    {"owner": "hull-dev",    "file": "lib/hull.py"},
    "GEO-turret":  {"owner": "turret-dev",  "file": "lib/turret.py"},
    "GEO-rungear": {"owner": "rungear-dev", "file": "lib/rungear.py"},
}
INTERFACES = [
    {"a": "GEO-turret_ring", "b": "GEO-hull_deck_ring", "normal": (0, 0, 1),
     "plane_z": DECK_Z, "overlap_mm": 12, "tol_mm": 2},
]
```

### 0.5.2 Write-Scope & Ownership Protocol (`lib/own.py`)
- Each builder writes **only** its assigned files (`lib/<part>.py`, `work/<part>_test.py`, `qc/<part>_*`) and places objects in its dedicated collection `COL_<agent>` with custom property `obj["dsh.owner"] = agent`.
- Only the Lead/Assembler modifies `lib/spec.py` and `lib/assemble.py`.
- Never share a single `.blend` file or `worker` daemon concurrently across parallel builders.

```python
# lib/own.py — Shared ownership helper
import bpy

def own(obj, agent):
    obj["dsh.owner"] = agent
    col = bpy.data.collections.get("COL_" + agent) or bpy.data.collections.new("COL_" + agent)
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj

def owned(agent):
    return [o.name for o in bpy.data.objects if o.get("dsh.owner") == agent]
```

### 0.5.3 Interface Table & Hidden Overlap Doctrine
- Every joint in `INTERFACES` specifies: (1) nominal mating plane + normal + local coordinate frame, (2) explicit **`overlap_mm` defined in `spec.py`** (hidden inside the larger volume without altering visible silhouettes or poking through thin shells), (3) tolerance `tol_mm`, (4) local axis orientation, and (5) feature size.
- **No universal multiplier or fixed millimeter rule**: Do not invent a generic "5–15mm" or "1–2x thickness" rule. Every joint uses the `overlap_mm` written in the project's `spec.py`, and geometry scripts only verify geometric overlap/floating/interpenetration — they do not certify mechanical structural strength.

### 0.5.4 Single-Part vs. Assembly Gates & Delivery Receipt Template
- **Single-part self-check**: Run `audit_mesh` (Gates ①–④). Note that `audit_mesh` does **not** accept a `file=` argument in `args`; pass `--blend <path>` on the CLI or open the `.blend` file first. Never run `audit_gate` on a single isolated object (it will fail connectivity because 1 isolated object has nothing to connect to).
- **Assembly check**: Run `audit_gate`, `audit_connectivity`, `audit_interference`, `audit_measure`, and `audit_scene` with `self_intersect=true` (Gates ①–⑩).

```text
[DELIVERY RECEIPT] <part_name / agent_id>   <ISO_timestamp>
audit_mesh   objects=[...]  state=pass  verdict=pass  clean=true
  totals: boundary_edges=0  nonmanifold_edges=0  degenerate_faces=0
          loose_verts=0  loose_edges=0  self_intersections=0  normals_inverted=0  normals_unknown=0
  objects[i]: closed=true  normals_state=pass  normals_outward=true
              normals_shells=[{shell:0, faces:..., state:pass, signed_volume:<val>, nested:false}]
audit_scene  state=pass  self_intersections_analyzed=true     # MUST run with {"self_intersect": true}
audit_gate   scope=COL_<agent>  state=pass  ship_ok=true
audit_interference  a=... b=...  verdict=refuted  volume_mm3=0
audit_measure  items[].size_mm within spec tolerance (e.g. <= +/-3mm)
               pairs[<a>|<b>].axis_overlap_mm.<normal_axis> = <measured> >= <spec overlap_mm>
               audit_connectivity floaters=[] confirmed: <yes>
.blend md5=<md5>
fingerprint.digest=<12-char-digest>
```

---

## 0.6 Reference-Driven Reconstruction & Viewport Reading Discipline

### 0.6.1 Multiview Calibration (`scripts/multiview_calib.py`)
1. **Orthographic projection does NOT mean Front/Side/Top share the same `px_per_mm`**: Fit each view independently using `>= 3` known features (`resid_pct <= 2%`), then convert shared physical axes (`H`, `L`, `W`) into **millimeters** to cross-check across views (`disagree_pct <= 3%`). Only pool scales if `same_scale_ok` (`spread <= 1%`) holds. Run `python3 "$SKILL_DIR/scripts/multiview_calib.py" --selftest` or pass your measurement JSON (see [`references/multiview-calibration.md`](references/multiview-calibration.md)).
2. **Cross-depth perspective error**: In a perspective view at camera distance $D$, a feature displaced in depth by $\Delta z$ from the reference plane has scale error $\text{err} \approx \frac{\Delta z}{D + \Delta z}$. If $D$ or $\Delta z$ is unknown, mark the dimension `unresolved`.
3. **Single-plane homography (`img_rectify`)**: Rectifies **only** the plane containing the 4 calibration corners. Off-plane features ($\Delta z > 0$) suffer severe lateral projection error ($211\text{ mm}$ at $0.2\text{ m}$, $543\text{ mm}$ at $0.5\text{ m}$).

### 0.6.2 Dual-Evidence Acceptance & Silhouette IoU Blind Spots
Always combine **numeric bbox/clearance (`audit_measure`, `clear_check`)** with **fixed-camera orthographic & studio renders (`qc_render_views`)**.
- **Silhouette IoU (`qc_render_views(ortho=True)` / `img_diff`) is necessary but NOT sufficient**: A 2D foreground mask cannot see **depth/taper**, **internal features/panel seams**, **surface tension (crisp bevels vs. soap-bar SubSurf)**, **other views**, or **inverted normals**. Always evaluate `right`, `front`, and `top` separately and pair with `clear_check` + 45° hard-shadow 900px renders.

### 0.6.3 Viewport Reading Discipline (`420px` vs. `900px` & `frame_hash`)
1. **Three-part visual reading**: Separate every image observation into **[Observed fact]**, **[Inferred]**, and **[Cannot determine from this view]**.
2. **Two image sizes**:
   - **Iterative modeling (`see --size 420`)**: Fast, compact (~17–79 KB) for step-by-step checks.
   - **Acceptance QC (`see --size 900` or `qc_render_views`)**: High resolution from fixed `spec.py` camera coordinates to resolve 1–2 mm panel seams.
3. **Hash deduplication**: Every `see` response returns `frame_hash`. If `frame_hash` equals the previous frame's hash, the image is byte-for-byte identical — **do not re-read the image**.

---

## 0.7 Modeling Class Routing Table (12 Classes)

Query live via `node "$SKILL_DIR/scripts/blender-rt.mjs" plan catalog --args '{"classes":true}'`:

| Modeling Class | First Step | Operator Chain | Do NOT Reinvent | Acceptance Gate |
|----------------|------------|----------------|-----------------|-----------------|
| **1. Reference Reconstruction** | `plan shape_draft` (S0 tables `T1–T4`, no mm/mesh counts) -> `shape_plan` | `shape_draft -> shape_draft_check -> img_rectify -> shape_sections -> shape_loft -> crease_lines/inset_lines -> shape_panels -> qc_render_views` | Do not hand-code lofts or station tables from raw pixels | S0 `shape_draft_check` ok + per-view IoU + panel/feature count > 0 |
| **2. Faceted Hard-Surface (Armor / Military / Panels)** | **Recipe 2a** | Primitives/plates + Boolean -> `Bevel(1–2 seg, 1–3mm, 30°)` + flat shading -> `audit_mesh` | **Never add SubSurf** (turns armor plates into soap bars) | Crisp bevel highlights + visible seams + `floaters=[]` |
| **3. Smooth Hard-Surface (Sheet Metal / Props)** | **Recipe 2b** | Base mesh -> `Bevel(3 seg)` -> `SubSurf(2)` or `crease_lines(radius_mm=...)` -> `audit_mesh` | Never put SubSurf before Bevel; never fake fillets with smooth shading alone | 0 pinching/self-intersections + feature lines > 0 |
| **4. Organic / Characters / Creatures** | `plan sculpt_scan` (**Recipe 11**) | `sculpt_setup(VOXEL) -> sculpt_apply(strokes) -> sculpt_mask -> audit_connectivity` | Never use `bpy.ops.sculpt.brush_stroke` in Python (RNA rejects stroke dicts in Blender 5.x) | Connected + envelope + outward normals |
| **5. Closed-Path / Pitch Arrays (Tracks / Chains)** | **Recipe 6b** or `plan generator_save` | Pin-chord solver (`p = 2R*sin(theta/2)`) or `generator_run` -> `audit_interference` | Never use `Array(FIT_CURVE)` for rigid closed chains; never use arc-length pitch on arcs | `max|chord - p| <= 0.001mm` + closure + object count `N` |
| **6. Boolean Cutouts (Wheel Wells / Vents / Bores)** | **Recipe 4** (`EXACT` solver) | `Boolean(EXACT)` -> `fix_repair` -> `audit_interference` | Never Boolean across unverified non-manifold shells | 0 unintended interpenetration + 0 degenerate faces |
| **7. Humanoid Base & Head** | `plan human_base` / `human_head` (**Recipes 15–16**) | `human_base -> <name>_joints` + `human_head -> *_M_*` -> mount armor/visor | Never eyeball joint positions; cover high-detail faces with helmets/visors when asset-free | `heads` & `shoulder_over_head` ratios + joint attachment |
| **8. Pipes / Cables / Rails / Sweeps** | `plan sweep_analyze` (**Recipe 14**) | `sweep_analyze -> sweep_build` (rotation-minimizing frame) -> `audit_connectivity` | Never extrude Frenet-twisted corners without checking bend radius vs. half-width | `min_radius > required_min_radius` |
| **9. Rotational Bodies (Bottles / Rims / Barrels)** | `plan shape_plan --args '{"object_class":"rotational"}'` | `shape_revolve(profile=...) -> print_report -> preset material` | Never loft axisymmetric parts | Radial symmetry + wall thickness |
| **10. Airfoils / Cambered Wings / Hulls** | `plan shape_plan --args '{"object_class":"aircraft"}'` | `shape_sections -> section_outline -> shape_loft` | Never use left-right symmetric `section_shape` for cambered wings (must use `section_outline`) | Camber profile error + multi-view IoU |
| **11. Mechanisms / Articulated Assemblies** | `plan gate_plan --args '{"preset":"assembly"}'` | `mate_check -> motion_joints -> motion_measure -> gate_run` | Never hand-roll assembly verdicts | 3-state `gate_run` (`degraded != pass`) |
| **12. 3D Printability & Export Delivery** | `plan print_report` (**Recipes 12–13**) | `fix_repair -> uv_* -> print_report -> deliver_export -> deliver_verify` | Never trust `min_mm` when `< resolution_mm`; never deliver `.blend` without manifest MD5 | `print_report` + `uv_stats` (0 zero-area UV faces) |

---

## 1. The 6-Step Modeling Pipeline

```text
0 Freeze Spec     -> lib/spec.py (dimensions + interfaces + naming; after S0 draft & S2 calibration)
1 Scene Setup     -> Collection hierarchy (COL_Reference / COL_Blockout / COL_Geo), unit scale, GEO- naming
2 Blockout        -> Place low-poly primitives to lock overall proportions (keep separate from final geo)
3 Primary Form    -> Refine silhouettes via bmesh / loft / revolve / Boolean wheel wells
4 Modifier Stack  -> Add non-destructive detail ordered by objective (Mirror -> Solidify -> Bevel -> SubSurf -> Boolean)
5 Mesh Cleanup    -> Merge doubles, recalculate outward normals per shell, remove loose verts/edges
6 Handoff & Gate  -> Run the 10 Numeric Gates (§6) + fixed-camera 900px QC renders and archive the receipt
```

---

## 2. Geometry Carrier Decision Tree

```text
What geometry are you building?
├── Hard-surface · Faceted armor / military models / angular mechanical plates (visible plane breaks & seams)
│   → Flat plates + small Bevel (1–3mm, 1–2 segments, ANGLE 30°) + FLAT shading → Recipe 2a
│   ✗ DO NOT add SubSurf (rounds crisp armor plates into plastic soap bars)
├── Hard-surface · Smooth curved surfaces (automotive sheet metal / consumer electronics / rounded housings)
│   → Base mesh + Bevel (3 seg) + SubSurf (levels 2) + smooth shading → Recipe 2b
│   → Or multi-view station loft + parametric crease_lines / inset_lines → Recipes 17–22
├── Organic (characters / creatures / foliage)
│   → Base mannequin: human_base / human_head → Recipes 15–16
│   → Sculpted form: Voxel Remesh + NumPy displacement brushes (draw/inflate/pinch/flatten/smooth/crease) → Recipe 11
│   ✗ Never call bpy.ops.sculpt.brush_stroke from Python (broken in Blender 5.x RNA)
├── Decorative repeats (fences, beads, tiles along a curve where pitch need not close)
│   → Mesh + Array + Curve modifier → Recipe 6
├── Rigid closed-loop pitch arrays (tank tracks, roller chains, ring gears)
│   → Parametric pin-chord-pitch solver (p = 2R*sin(theta/2), N = 2*(M + N_STR)) → Recipe 6b
├── Tubular / routed paths (pipes, hoses, cables, handrails)
│   → sweep_analyze (bend radius check) → sweep_build (rotation-minimizing frame) → Recipe 14
├── Rotational / lathe parts (bottles, cups, barrels, wheel rims, nozzles)
│   → shape_revolve → Reference Reconstruction SOP Step 3
└── Surgical cutouts / bores in existing solids
    → Boolean DIFFERENCE (solver='EXACT', keep live until export) → Recipe 4
```

---

## 3. The 24 Parametric Recipes (Quick Index)

All 24 copy-pasteable recipes and the `§0 Generator Contract` (`generator_save/run/diff`) live in [`references/recipes.md`](references/recipes.md):

- **Core Primitives, Hard-Surface & `bmesh` (`Recipes 1–5`)**:
  - `Recipe 1`: Add primitive & rename (`GEO-` prefix)
  - `Recipe 2a`: Faceted hard-surface (1–2 seg Bevel, flat shading, NO SubSurf)
  - `Recipe 2b`: Smooth hard-surface (Bevel before SubSurf + smooth shading)
  - `Recipe 3` & `Recipe 3b`: Edit Mode ops (GUI) vs. context-free `bmesh` (required for `headless`)
  - `Recipe 4`: Surgical Boolean cutter (`EXACT` solver)
  - `Recipe 5`: Mirror modifier (`use_clip=True`, top of stack)
- **Arrays, Cleanup & Audit Gates (`Recipes 6–10`)**:
  - `Recipe 6`: Decorative Array + Curve
  - `Recipe 6b`: Closed-path pin-chord-pitch array (`build_link_template`, `stadium_pins`, and 4-row assembly audit interpretation table)
  - `Recipe 7`: Blockout staging
  - `Recipe 8`: Post-curve / post-Boolean `bmesh` cleanup (`remove_doubles` + `recalc_face_normals`)
  - `Recipe 9`: Assembly audit gate (`audit_gate`, `audit_interference`, `audit_measure`)
  - `Recipe 10`: Dual-evidence form verification (`qc_render_views` + `audit_measure`)
- **Sculpting, Repair, UV, Print, Sweep & Humanoids (`Recipes 11–16`)**:
  - `Recipe 11`: Procedural sculpting (`sculpt_scan -> sculpt_setup -> sculpt_apply -> sculpt_mask`)
  - `Recipe 12`: Mesh repair & UV pipeline (`audit_mesh -> fix_repair -> uv_smart_project/unwrap/pack/stats`)
  - `Recipe 13`: 3D printability wall-thickness & overhang report (`print_report`, `resolution_mm` check)
  - `Recipe 14`: Path sweep (`sweep_analyze -> sweep_build`)
  - `Recipe 15`: Parametric humanoid base mesh & 19 joint markers (`human_spec -> human_base -> human_measure`)
  - `Recipe 16`: Parametric head, 6 facial landmarks & mask/visor strategy (`human_head`, `face_ratios`)
- **Reference Reconstruction, Vehicles, Pipelines & Search (`Recipes 17–24`)**:
  - `Recipe 17`: Vehicle package proportion gate & Boolean wheel-well base (`vehicle_package -> vehicle_base -> clear_check`)
  - `Recipe 18`: 3-view station extraction, parametric loft & physical panel seams (`vehicle_sections -> vehicle_loft -> vehicle_panels`)
  - `Recipe 19`: Front `section_shape`, 2D `vehicle_fit` loop, and multi-volume `vehicle_regions`
  - `Recipe 20`: 4-point perspective photo rectification (`img_rectify` + single-plane depth warning)
  - `Recipe 21`: Polyline family K-sweep (`vehicle_fit` with `family="polyline"`, `control_points=[6,10,16]`)
  - `Recipe 22`: Parametric feature lines (`crease_lines` with `frac` or true-fillet `radius_mm` + `segments`, `inset_lines`)
  - `Recipe 23`: Chained multi-step pipeline execution (`pipe_run` with `@artifact` references)
  - `Recipe 24`: In-Blender main-thread parameter search (`loop` & declarative `plan shape_search`)

---

## 4. Six Critical Pitfalls & Pre-Code Checklist

| Pitfall | Machine-Checkable? | Where It Is Enforced |
|---------|--------------------|----------------------|
| **Pitfall 1: Long / Wide / Thin axis semantics** | No (semantic) | **Pre-Code Checklist #1** |
| **Pitfall 2: Visual seams vs. hidden overlap (`overlap_mm`) & floating parts** | Yes | **Gates ⑥, ⑦, ⑧** (`audit_connectivity`, `audit_interference`, `audit_measure`) |
| **Pitfall 3: Tapering to a sharp point** | No (topological intent) | **Pre-Code Checklist #2** |
| **Pitfall 4: `bpy.ops` context failures in `headless`** | No (runtime crash risk) | **Pre-Code Checklist #3** (`Recipe 3b` `bmesh`) |
| **Pitfall 5: Inverted normals flip all interference verdicts** | Yes | **Gate ④** (`audit_mesh` per-shell `normals_state` + `normals_shells[]`) |
| **Pitfall 6: "White-on-white" preview lighting hides panel seams** | Semi (`coverage_estimate`) | **Studio Preset / Gate ⑨** (neutral gray `0.18` + 45° hard sun light) |

### Pre-Code Checklist (Recite Before Writing Any Script)
1. **Long / Wide / Thin Axes (Pitfall 1)**: For any elongated or flat part (blade, plank, armor skirt, wing), write a comment at the top of your script stating `(Long, Wide, Thin) = (local ?, local ?, local ?)` and orient the **Wide** face toward the hero camera so a sword doesn't render as a thin stick.
2. **Tapering Tips (Pitfall 3)**: Never taper a tip by scaling top vertices to `0.01` (leaves a blunt chisel tip or degenerate faces). Collapse top vertices to the centerline (`v.co.x = 0; v.co.y = 0`) and run `bmesh.ops.remove_doubles(bm, verts=top_verts, dist=0.001)`.
3. **Headless Context Safety (Pitfall 4)**: Confirm your headless script contains zero `bpy.ops.object.mode_set`, `bpy.ops.mesh.*`, `bpy.ops.transform.*`, or `bpy.ops.object.shade_smooth` calls. Use `bmesh` (`Recipe 3b` / `Recipe 8`) and `for p in obj.data.polygons: p.use_smooth = ...`.

---

## 5. Modifier Ordering by Objective & Removing Buried Interior Faces

### 5.1 Modifier Stack Ordering (By Objective, Never Memorized Blindly)
Swapping two modifiers changes both vertex count and bounding box dimensions by up to 15% (`Bevel -> SubSurf` produces `866 verts, bbox 0.990m` vs. `SubSurf -> Bevel` `98 verts, bbox 0.839m`). Order modifiers by what each stage needs as input:

| Objective | Relative Order | Rationale |
|-----------|----------------|-----------|
| Seamless centerline across mirrored halves | **`Mirror` first**, before `Bevel` / `SubSurf` | Welds centerline vertices before beveling or subdividing; otherwise the seam is beveled as an open border. |
| Individual beveled units repeated in an array | **`Bevel` first**, `Array` second | Array duplicates the already-beveled unit. |
| Sheet-metal shell with rounded edges | **`Solidify` first**, `Bevel` second | Gives the surface thickness before beveling edges (`Bevel -> Solidify` loses the bevels: 54 faces -> 6 faces). |
| Smooth curved surface with crisp feature edges | **`Bevel` first**, `SubSurf` second (`Recipe 2b`) | Bevel creates support loops that hold the crease under Catmull-Clark subdivision. |
| Faceted armor / military plates | **`Bevel` only — NO `SubSurf`** (`Recipe 2a`) | SubSurf rounds flat armor facets into soap bars. |
| Surgical cutouts | **`Boolean` last** (keep live until export) | Preserves non-destructive editing and prevents Boolean n-gons from polluting upstream modifiers. |

### 5.2 Removing Buried Interior Faces (Why `Delete Loose` Does NOT Work)
- **Myth**: "Use `Clean Up -> Delete Loose` or `select_interior_faces()` to remove faces buried inside joined overlapping solids."
- **Measured reality (Blender 5.2)**: `delete_loose` only deletes isolated vertices and edges that belong to **zero faces** — it deletes `0 faces`. When two overlapping cubes are joined (`Ctrl+J`), `select_interior_faces()` also selects `0 faces`.
- **Correct fix**:
  1. To merge overlapping solid shells into a single watertight volume, use **Boolean `UNION` (`solver='EXACT'`)**, NOT `Join` + delete faces (deleting buried faces without splitting intersecting walls leaves open boundary holes).
  2. To detect buried faces programmatically, cast a ray from each face center along its outward normal against a `BVHTree` of the mesh:
     ```python
     import bmesh
     from mathutils.bvhtree import BVHTree

     def buried_faces(obj, eps=1e-5):
         bm = bmesh.new(); bm.from_mesh(obj.data)
         bvh = BVHTree.FromBMesh(bm)
         out = [f for f in bm.faces if bvh.ray_cast(f.calc_center_median() + f.normal * eps, f.normal, 1e6)[2] is not None]
         bm.free()
         return out
     ```

---

## 6. Authoritative Numeric Gates (Gates ①–⑩)

See [`references/verification-checklist.md`](references/verification-checklist.md) for the standalone reviewer guide. Every part handoff runs Gates **①–④**; every assembly handoff runs Gates **①–⑩**.

| # | Gate | Criterion | Command & Inspected Fields |
|---|------|-----------|----------------------------|
| **①** | **Loose Geometry** | `0` loose verts, `0` loose edges | `plan audit_mesh` -> `totals.loose_verts == 0` and `totals.loose_edges == 0` |
| **②** | **Manifold & Self-Intersect** | `0` non-manifold edges, `0` self-intersections | `plan audit_scene --args '{"self_intersect":true}'` -> `state == "pass"`, `totals.nonmanifold_edges == 0` *(omitting `self_intersect=true` returns `state="degraded"`)* |
| **③** | **Watertightness** | `0` boundary edges on solid parts | `plan audit_mesh` -> `totals.boundary_edges == 0`, `objects[i].closed == true` |
| **④** | **Per-Shell Outward Normals** | All non-nested shells face outward | `plan audit_mesh` -> `objects[i].normals_state == "pass"` and `normals_shells[]` (`unknown` is never a pass) |
| **⑤** | **Dimensions vs. `spec.py`** | BBox within spec tolerance (`+/-3 mm`) | `plan audit_measure` -> `items[].size_mm` |
| **⑥** | **Zero Floating Parts** | `0` unattached floaters | `plan audit_connectivity` -> `gate.state == "pass"` and `floaters == []` |
| **⑦** | **Interference** | `0` unintended interpenetrations | `plan audit_interference` -> `verdict` + `volume_mm3` and `plan audit_overlap` -> `pair_count` |
| **⑧** | **Spec Interface Overlap** | Matches explicit `overlap_mm` in `spec.py` | `plan audit_measure` -> `pairs[].axis_overlap_mm` (world-axis joints only; use local frame for angled joints) + `floaters == []` |
| **⑨** | **Form (Dual Evidence)** | Fixed-camera 900px renders + bbox | `plan qc_render_views` + `audit_measure` |
| **⑩** | **Triangle Budget** | Within target triangle count | `audit_scene` / `audit_gate` -> `tris` |

---

## 6.5 Camera Framing, Exploded Views, Long Renders & Blender 5.2 API Changes

### 6.5.1 Camera Framing: Solve & Verify in Projected NDC Space (`fit_view`), Never by AABB Heuristic
Estimating camera distance from axis-aligned `dx/dy/dz` clips 3/4 views, and reading `matrix_world` after mutating `obj.location` without calling `bpy.context.view_layer.update()` reads stale pre-explosion bounds. Always solve camera distance and look-at center by projecting sampled vertices into Normalized Device Coordinates (`NDC`) and verifying `worst_ndc <= 1.0`:

```python
from mathutils import Vector

def cam_basis(direction):  # direction = vector from target to camera; fwd = -d
    d = Vector(direction).normalized(); fwd = -d
    up = Vector((0, 0, 1))
    if abs(fwd.dot(up)) > 0.995:
        up = Vector((0, 1, 0))
    Z = -fwd
    Y = (up - Z * up.dot(Z)).normalized()
    X = Y.cross(Z).normalized()
    return d, fwd, X, Y, Z

def fit_view(bb, direction, lens=70, res=(1920, 1080), margin=1.18, points=None, iters=40):
    d, fwd, X, Y, Z = cam_basis(direction)
    tan_h = (36.0 / 2.0) / lens
    tan_v = tan_h * (res[1] / float(res[0]))
    pts = points or [Vector((x, y, z)) for x in (bb[0], bb[1]) for y in (bb[2], bb[3]) for z in (bb[4], bb[5])]
    look = Vector(((bb[0] + bb[1]) / 2.0, (bb[2] + bb[3]) / 2.0, (bb[4] + bb[5]) / 2.0))
    dist = max(bb[1] - bb[0], bb[3] - bb[2], bb[5] - bb[4]) * 1.8 + 1.0
    target = 1.0 / margin
    for _ in range(iters):
        C = look + d * dist
        k, nx, ny, behind = 0.0, [], [], False
        for P in pts:
            V = P - C; dep = V.dot(fwd)
            if dep <= 1e-6:
                behind = True; break
            ax = V.dot(X) / (dep * tan_h); ay = V.dot(Y) / (dep * tan_v)
            nx.append(ax); ny.append(ay); k = max(k, abs(ax), abs(ay))
        if behind:
            dist *= 1.8; continue
        dist *= (k / target) ** 0.85
        cxm = (min(nx) + max(nx)) / 2.0; cym = (min(ny) + max(ny)) / 2.0
        look = look + X * (cxm * dist * tan_h) + Y * (cym * dist * tan_v)  # PLUS, not minus
        if k <= target * 1.002 and abs(cxm) < 0.004 and abs(cym) < 0.004:
            break
    return dist, (look.x, look.y, look.z)
```

- **Per-frame NDC self-check**: After `sc.frame_set(f)`, call `bpy.context.view_layer.update()`, project every 14th vertex (`[o.data.vertices[i] for i in range(0, len(o.data.vertices), 14)]`) into camera NDC, and `assert worst <= 1.0`.
- **Unit consistency**: `kit.bounds_all()` returns **millimeters** whereas `o.matrix_world @ v.co` is in **meters** — never mix them without `* 1000.0`.

### 6.5.2 Exploded Views & Disassembly Animations
1. Call `bpy.context.view_layer.update()` immediately after setting exploded `obj.location` values.
2. Keep total exploded span around **`1.4x–1.6x` the unexploded assembly length** (at `2.2x`, small pins and springs shrink into unreadable dots).
3. Hide the studio floor (`floor.hide_render = True`) on exploded/cutaway shots so downward-exploding parts aren't swallowed by the ground plane.
4. Keep one anchor part stationary (e.g. `upper_receiver`), order specific part prefixes (`bolt_carrier`, `bolt_catch`) before generic substrings (`bolt`), and assert `UNMATCHED == []`.

### 6.5.3 Resumable Long Jobs (> 2 min) & Optical Flow Frame Interpolation
1. **Resumable frame loops**: Write frames as `seq_%04d.png` into a dedicated final directory (separate from draft renders) and skip existing frames (`if os.path.exists(p) and not FORCE: continue`).
2. **Benchmark 3 frames before scheduling**: In Cycles + OptiX denoising, ~60% of per-frame time is fixed scene/BVH/denoiser overhead (`64 -> 320` samples only changes frame time from `1.78s` to `2.45s` at 1080p). Frame count (`duration * fps`) and resolution are the real levers.
3. **Optical-flow frame interpolation (`minterpolate`)**: Safe when maximum per-part screen motion is `< 30 px/frame` (`> 80 px/frame` tears):
   $$\text{px\_per\_frame} = \frac{\text{part\_travel\_mm} / (\text{duration\_s} \times \text{render\_fps})}{\text{frame\_width\_mm} / \text{frame\_width\_px}}$$
   ```bash
   ffmpeg -start_number 1 -framerate 10 -i seq_%04d.png \
     -vf "minterpolate=fps=30:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1:scd=none" \
     -fps_mode cfr -frames:v 900 -c:v libx264 -preset slow -crf 15 -pix_fmt yuv420p out.mp4
   ```

### 6.5.4 Blender 5.2 Python API Breaking Changes

| Error / Symptom | Root Cause in Blender 5.2 | Required Fix |
|-----------------|---------------------------|--------------|
| `'Action' object has no attribute 'fcurves'` | Blender 5.2 uses layered/slotted Actions | Do not iterate `action.fcurves`; sample easing curves (`1 - (1 - u)**2.4`) directly when inserting keyframes |
| `bpy_prop_collection[slice]: slice steps not supported` | `o.data.vertices[::14]` is disallowed | Use `[o.data.vertices[i] for i in range(0, len(o.data.vertices), 14)]` |
| `CyclesRenderSettings has no attribute 'use_persistent_data'` | Moved from `scene.cycles` to `scene.render` | Set `scene.render.use_persistent_data = True` and `assert scene.render.use_persistent_data is True` |
| `Scene.frame_set()` expected `int`, not `float` | Strict integer frame argument | Pass `int(1 + round(t * fps))` |
| `Mesh` has no attribute `use_auto_smooth` | Removed in Blender 4.1+/5.x | Set per-polygon `p.use_smooth` or use Edge Split / Smooth by Angle modifier |
| `Edge` has no attribute `crease_weight` | Replaced by `crease_edge` attribute | Read/write the `crease_edge` float attribute on `mesh.attributes` |

---

## 7. Reference Documents & Scripts Index

- **[`references/cli-reference.md`](references/cli-reference.md)**: All 16 subcommands of `scripts/blender-rt.mjs`, environment variables (`BLENDER_RT_*`), persistent kernel `K` usage, offline bootstrap, and troubleshooting table.
- **[`references/recipes.md`](references/recipes.md)**: Generator contract (`§0`) + all 24 parametric modeling, sculpting, UV, vehicle/shell lofting, pipeline, and parameter-search recipes (`Recipes 1–24`).
- **[`references/reference-reconstruction-sop.md`](references/reference-reconstruction-sop.md)**: Universal 9-step reference image reconstruction SOP (`S0 shape_draft` -> `S5` delivery), 5 cross-section paths, and 10 object-class protocols.
- **[`references/multiview-calibration.md`](references/multiview-calibration.md)**: Two-stage per-view least-squares & cross-view millimeter calibration guide + [`scripts/multiview_calib.py`](scripts/multiview_calib.py).
- **[`references/verification-checklist.md`](references/verification-checklist.md)**: Standalone (~1.5k tokens) 10-gate verification checklist for independent reviewer subagents.
- **[`references/modeling-overview.md`](references/modeling-overview.md)**: Deep-dive reference on `bpy.ops.mesh` vs. `bmesh` precision APIs, primitive selection, bevel weights, and modifier internals.
