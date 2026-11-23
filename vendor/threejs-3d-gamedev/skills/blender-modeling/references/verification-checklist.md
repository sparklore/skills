# Independent Verification Checklist (Subagent Hand-Off Sheet)

> **Purpose**: Self-contained verification specification (~1.5k tokens) for an independent reviewer or verification subagent. A reviewer only needs **this file + the target `.blend` / `spec.py` + `scripts/blender-rt.mjs`** — do not trust the builder's self-reported receipts.

---

## 1. Subagent Task Prompt Template

```text
Verify the Blender deliverable at <path/to/scene.blend> against <path/to/spec.py> (and reference images at <path/to/refs/>) using ~/.agents/skills/blender-modeling/references/verification-checklist.md.
Run the numeric gates and fixed-camera visual checks via ~/.agents/skills/blender-modeling/scripts/blender-rt.mjs.
Do NOT modify the scene. Return the 4-line verdict block (verdict / evidence / failures / repro).
```

---

## 2. The 10 Authoritative Numeric Gates

Single-part handoffs must pass Gates **①–④**; full assemblies and final deliverables must pass Gates **①–⑩**. Missing a field means the gate was **not run**.

```bash
SKILL_DIR="${BLENDER_SKILL_DIR:-$HOME/.agents/skills/blender-modeling}"
```

| # | Gate | Pass Criterion | CLI Command (`node "$SKILL_DIR/scripts/blender-rt.mjs" ...`) & Fields to Inspect |
|---|------|----------------|----------------------------------------------------------------------------------|
| **①** | **Loose Geometry & Doubles** | `0` loose vertices, `0` loose edges | `plan audit_mesh --blend <f> --args '{"scope":"COL_Geo"}'` -> `totals.loose_verts == 0` AND `totals.loose_edges == 0` |
| **②** | **Manifold & Self-Intersection** | `0` non-manifold edges (except intentional open rims), `0` self-intersections | `plan audit_scene --blend <f> --args '{"summary_only":true,"top_k":10,"self_intersect":true}'` -> `state == "pass"`, `totals.nonmanifold_edges == 0`, `totals.self_intersect_faces == 0` *(Note: `self_intersect` defaults to `false`, which returns `state="degraded"` — always pass `true`!)* |
| **③** | **Watertightness (Closed Parts)** | `0` boundary edges on solid parts | `plan audit_mesh --blend <f> --args '{"scope":"COL_Geo"}'` -> `totals.boundary_edges == 0`, `objects[i].closed == true` |
| **④** | **Outward Normals (Per-Shell)** | Every independent connected shell faces outward | `plan audit_mesh --blend <f> --args '{"scope":"COL_Geo"}'` -> `objects[i].normals_state == "pass"` and `normals_shells[]` *(Never rely on total `signed_volume > 0` alone; a large positive shell + small inverted shell still sums to `> 0`. `normals_state == "unknown"` is NEVER a pass.)* |
| **⑤** | **Dimensions vs. `spec.py`** | Key bounding boxes within spec tolerance (e.g. `+/-3 mm`) | `plan audit_measure --blend <f> --args '{"neighbors":false}'` -> `items[].size_mm` vs `spec.py` |
| **⑥** | **Zero Floating Parts** | `0` unattached floating components (`span_fraction >= 1%`) | `plan audit_connectivity --blend <f> --args '{"scope":"COL_Geo"}'` -> `gate.state == "pass"` AND `floaters == []` *(Note: top-level has no `state`; read `gate.state`. Do NOT require `components == 1` for un-welded touching parts like track links.)* |
| **⑦** | **Interference / Interpenetration** | `0` unintended interpenetrations; intentional overlaps whitelisted in `spec.py` | `plan audit_interference --blend <f> --args '{"a":"GEO-a","b":"GEO-b"}'` -> `verdict` + `volume_mm3` AND `plan audit_overlap` -> `pair_count` *(Note: `verdict == "unresolved"` means undecided, NOT zero interference; flush contact produces `pair_count >= 1`.)* |
| **⑧** | **Interface Overlap Depth** | Each joint's overlap matches `spec.py` `overlap_mm` without poking through thin shells | `plan audit_measure --blend <f> --args '{"neighbors":true}'` -> `pairs[].axis_overlap_mm` + `audit_connectivity` (`floaters == []`) |
| **⑨** | **Form & Silhouette (Dual Evidence)** | Fixed-camera renders (`>= 900px`) + numeric bbox both pass | `plan qc_render_views --blend <f> --args '{"views":[...],"res":[1280,720]}'` + `audit_measure` |
| **⑩** | **Triangle Budget** | Within target triangle budget | `audit_scene` / `audit_gate` -> `tris` |
| **—** | **Evidence Digest** | Invalidated if `.blend` or script changes | Record `.blend` MD5 + `fingerprint.digest` in receipt |

---

## 3. Four Critical Metric Interpretation Traps

1. **Three-State Verdict (`pass` / `fail` / `degraded`)**:
   - `audit_mesh` and `audit_scene` return `state` (`pass` | `fail` | `degraded`) and `clean` (`true` only when `state == "pass"`).
   - `clean == false` has two completely different causes: **`state == "fail"`** (actual geometry defects exist -> fix geometry) vs. **`state == "degraded"`** (check was skipped or inconclusive, e.g. `self_intersect=false`, `normals_state="unknown"`, or face count exceeded shell limit -> re-run with full flags/higher limits). **Never treat `degraded`, `unresolved`, `ok=false`, or `analyzed=false` as a pass.**
2. **`axis_overlap_mm` is an Axis-Aligned Bounding Box (AABB) metric, NOT triangle-level depth**:
   - Only read the axis parallel to the joint normal when the joint is aligned with a world axis (`X`, `Y`, or `Z`). For a $3\text{ mm}$ plate lapping over a $180\times 200\text{ mm}$ hull along $Z$, `{x: 180, y: 200, z: 1.5}` means $1.5\text{ mm}$ overlap in $Z$ — `180` and `200` are the plate's width and length!
   - For rotated/angled joints, measure along the joint's local coordinate frame or use `audit_interference` (`volume_mm3`).
   - A small part floating completely inside a larger part's AABB also reports `overlap_bbox = true` — always pair Gate ⑧ with Gate ⑥ (`audit_connectivity`).
3. **Unevaluated `audit_mesh` vs. Evaluated Assembly Audits**:
   - `audit_mesh` reads raw `ob.data` (unapplied `Mirror` or `Boolean` modifiers are NOT evaluated). Apply modifiers on a copy if you need `audit_mesh` to verify post-modifier watertightness.
   - `audit_connectivity`, `audit_gate`, `audit_measure`, and `audit_interference` read the **evaluated** dependency-graph mesh (`evaluated_get(depsgraph)`).
4. **One-Click `gate_run` Caveats**:
   - `plan gate_run` aggregates multiple checks, but any sub-check marked `skipped` or `degraded` means that gate is incomplete and must be run explicitly.

---

## 4. Anti-Goodhart Rule: Switch Verification Paths

When a builder optimizes a metric inside an inner loop, that metric ceases to be a sufficient acceptance gate:

| If the Builder Used... | The Reviewer MUST Verify With... |
|------------------------|----------------------------------|
| `shape_fit` / `vehicle_fit` (2D station contour IoU) | 3D `qc_render_views` (`ortho=True`) across **all** views (`right`, `front`, `top`) + `clear_check` + 45° key-light 900px render |
| `loop` / `shape_search` (in-Blender parameter search) | Independent `audit_measure` against `spec.py` + `qc_render_views` from a camera angle *not* used in the search objective |
| `generator_run` (`expect={"min_objects": N}`) | Full `audit_scene(self_intersect=True)` + `audit_connectivity` + `audit_interference` on the generated scene |

---

## 5. Subjective Visual Gate & Silhouette IoU Blind Spots

Always inspect at least two `900px` renders (`see --size 900` or `qc_render_views`) under **neutral gray material (`Base Color ~ 0.18, Roughness ~ 0.6`) + 45° hard key sun light (`angle 1–3°`)**: one **hero angle** and one **45° inspection angle**.

| What Silhouette IoU CANNOT See | How the Reviewer Must Check It |
|--------------------------------|--------------------------------|
| **Depth / Plan Taper** (a flat extruded slab has the same side IoU as a sculpted car body) | Check orthos in all 3 axes (`right`, `front`, `top`) + `audit_measure` 3D bounding box. |
| **Internal Features & Panel Seams** (recessed vents, weld seams, panel gaps inside the outer silhouette) | Inspect 900px 45° hard-shadow render + `clear_check` on split panels. |
| **Surface Tension (Faceted vs. Soap-Bar SubSurf)** (armor plates rounded into soap bars still score `IoU > 0.92`) | Inspect edge highlights in 900px render: crisp thin bevel line (`Recipe 2a`) vs. mushy gradient (`SubSurf`). |
| **Floating / Interpenetrating Parts** (parts buried inside each other or hovering by 2mm) | Run `audit_connectivity` (`floaters=[]`) + `audit_interference`. |
| **Inverted Normals** (silhouette mask is identical whether normals face inward or outward) | Run `audit_mesh` -> `normals_state == "pass"`. |

---

## 6. Mandatory 4-Line Reviewer Output Format

Report your findings in exactly these 4 structured sections:

1. **`verdict`**: `PASS` | `FAIL` | `DEGRADED (needs re-check)`
2. **`evidence`**: `.blend` path + MD5, `fingerprint.digest`, summary of Gates ①–⑩ (`state`, `tris`, `floaters`, `max_dim_err_mm`, per-view `IoU`), and paths to the 900px QC renders inspected.
3. **`failures`**: Numbered list of specific gate or visual failures with exact object names, measured numbers vs. `spec.py` targets, and offending coordinates.
4. **`repro`**: Exact `node "$SKILL_DIR/scripts/blender-rt.mjs" ...` command lines that reproduce each failure.
