# Multiview Reference Calibration (`scripts/multiview_calib.py`)

When converting reference images into `spec.py`, **never fit a single global `px_per_mm` across multiple views**.

Even when every view is a true orthographic projection, each cropped image (`front.png`, `side.png`, `top.png`) is exported at its own canvas resolution, crop margin, or zoom factor. Assuming `s_front == s_side == s_top` silently corrupts every cross-view dimension.

---

## 1. Core Principles

1. **Orthographic projection != Equal pixel scale across views**:
   - Orthographic projection guarantees that **within a single view**, parallel planes at different depths share the same scale $s_v$ (`px/mm`) — or in perspective, the depth error is bounded by $\text{err} \approx \frac{\Delta z}{D + \Delta z}$.
   - It does **not** guarantee that `front.png`, `side.png`, and `top.png` share the same $s_v$. Only an unsplit CAD engineering drawing sheet with a verified 1:1 shared border can share $s_v$, and even that must be proven by measuring a shared dimension (`spread <= 1%`).

2. **Two-Stage Calibration Algorithm**:
   - **Stage 1 — Per-view least-squares fit (`fit_view`)**:
     For each view $v$ independently, collect $n \ge 3$ known dimension pairs `(px_i, mm_i)` and solve:
     $$s_v = \frac{\sum \text{px}_i \cdot \text{mm}_i}{\sum \text{mm}_i^2}$$
     (For $n = 2$, use the two-point check; $n = 1$ has zero degrees of freedom and cannot detect measurement blunders.)
     Compute the maximum relative residual:
     $$\text{resid\_pct}_v = \max_i \frac{|\text{px}_i / s_v - \text{mm}_i|}{\text{mm}_i} \times 100\%$$
   - **Stage 2 — Cross-view shared axis check in millimeters (`calibrate`)**:
     After converting each view's pixel measurements into millimeters using its own $s_v$, compare dimensions that represent the **same physical axis** across two views:
     - **Total Height $H$**: shared between **Front** (vertical) and **Side** (vertical)
     - **Total Length $L$**: shared between **Side** (horizontal) and **Top** (horizontal)
     - **Total Width $W$**: shared between **Front** (horizontal) and **Top** (vertical)

---

## 2. Hard Thresholds (Gates)

| Check | Threshold | Failure Meaning & Action |
|-------|-----------|--------------------------|
| **Per-view residual (`resid_pct`)** | `<= 2.0%` (`> 2.0%` -> **FAIL**) | Perspective foreshortening across depth layers, wrong landmark endpoints, or misread spec number inside that view. Re-pick coplanar points or switch to camera calibration. |
| **Cross-view shared dimension (`disagree_pct`)** | `<= 3.0%` (`> 3.0%` -> **FAIL**) | Front/Side/Top drawings are inconsistent with each other (common in concept art or AI-generated turnarounds), or the endpoints measured in the two views do not refer to the same physical feature. |
| **Same-sheet scale spread (`same_scale_ok`)** | `<= 1.0%` | Only if $\max(s_v)/\min(s_v) - 1 \le 1\%$ may the views be treated as sharing a single CAD sheet scale. Otherwise keep distinct `s_front`, `s_side`, `s_top`. |

---

## 3. Running `scripts/multiview_calib.py`

### Self-Test (4 Built-In Cases A / B / C / D)
```bash
SKILL_DIR="${BLENDER_SKILL_DIR:-$HOME/.agents/skills/blender-modeling}"
python3 "$SKILL_DIR/scripts/multiview_calib.py" --selftest
```
- **Case A (Anti-pattern)**: Jointly pooling Front (`0.50 px/mm`) and Side (`0.32 px/mm`) into a single fit produces a `33.2%` error (`ok=False`).
- **Case B**: In-view depth perspective error (`resid = 5.98% > 2%`) is caught inside `side` (`ok=False`).
- **Case C**: Per-view calibration with `s_front = 0.50`, `s_side = 0.32`, `s_top = 0.40` and consistent shared `H`/`L`/`W` in mm passes (`ok=True`, `same_scale_ok=False`).
- **Case D**: Each view is internally consistent (`resid = 0%`), but `side` and `top` disagree on total length $L$ by `6.45% > 3%` (`ok=False`).

### Calibrating Your Own Reference Views from JSON
Create a `calib_input.json` file:
```json
{
  "views": {
    "front": [[925, 1850], [625, 1250], [790, 1580]],
    "side":  [[1376, 4300], [832, 2600], [400, 1250]],
    "top":   [[1720, 4300], [740, 1850], [1040, 2600]]
  },
  "shared": [
    ["height_mm", {"front": 625,  "side": 400}],
    ["length_mm", {"side":  1376, "top":  1720}],
    ["width_mm",  {"front": 925,  "top":  740}]
  ]
}
```
Run:
```bash
python3 "$SKILL_DIR/scripts/multiview_calib.py" calib_input.json
```
Freeze the resulting per-view scales (`s_front`, `s_side`, `s_top`) and millimeter dimensions into `lib/spec.py` before any modeling begins.

---

## 4. Perspective & Homography Warnings

- **Cross-depth error in perspective photos**: If two measured features lie at depths $D$ and $D + \Delta z$ from the camera, perspective foreshortening introduces a relative scale error of:
  $$\text{err} \approx \frac{\Delta z}{D + \Delta z}$$
  For a telephoto/long-distance shot ($D = 10\text{ m}, \Delta z = 0.2\text{ m}$), $\text{err} \approx 2\%$. For a close-up photo ($D = 2\text{ m}, \Delta z = 0.5\text{ m}$), $\text{err} \approx 20\%$.
- **Single-plane homography (`img_rectify`)**: Rectifying a tilted photo using 4 coplanar corners only corrects measurements **on that exact plane**. Any feature protruding or recessed by $\Delta z$ off that plane will be projected with massive lateral error (e.g. $211\text{ mm}$ error at $\Delta z = 0.2\text{ m}$, $543\text{ mm}$ error at $\Delta z = 0.5\text{ m}$). Measure off-plane parts only from a view where they lie on the calibrated plane, or use full 3D camera calibration.
