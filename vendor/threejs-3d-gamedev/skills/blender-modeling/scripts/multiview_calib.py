#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Multiview orthographic calibration (front / side / top):
Per-view least-squares solve for px_per_mm + cross-view consistency check.

Usage:
    python3 multiview_calib.py calib.json      # Read calibration input and print report
    python3 multiview_calib.py --selftest      # Run synthetic self-tests (4 cases: A/B/C/D)

Key principles:
  * u_mm = known physical length (mm) of a feature along this view's horizontal image axis
  * px   = pixel length of the same feature in the reference image
  * Model: px = cx + s * u (s = px_per_mm, cx = pixel column where u=0 falls)
  * Any 2 points are trivially fit by a line (residual = 0); require >=3 points per view
    to test whether the view is truly orthographic.
  * Orthographic projection only guarantees linearity *within* each view (in-view residual ~0).
    It does NOT imply that all 3 views share the same px_per_mm (views may have different crops,
    resolutions, or export scales while still being strictly orthographic).
  * Therefore, cross-view validation must convert pixel measurements to millimeters using each
    view's own `s` before comparing (see shared_check), rather than comparing `s` directly.
"""
import json
import sys

RESID_TOL_PCT = 2.0       # In-view residual limit: >2% -> non-linear within view (perspective or bad points)
SHARED_TOL_PCT = 3.0      # Cross-view shared dimension disagreement limit (in mm): >3% -> incompatible views
SAME_SCALE_TOL_PCT = 1.0  # Spread of px_per_mm across views <=1% required to treat as same export scale


def fit_view(features, image_width=None):
    """Least-squares solve px = cx + s*u. features=[{name, u_mm, px}, ...] (>=2 points)."""
    pts = [(float(f["u_mm"]), float(f["px"])) for f in features]
    n = len(pts)
    if n < 2:
        raise ValueError("At least 2 feature points are required to fit scale (got %d)" % n)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxx = sum((u - mx) ** 2 for u, _ in pts)
    if sxx <= 0:
        raise ValueError("All feature points coincide in u_mm (sxx=0); cannot solve scale")
    sxy = sum((u - mx) * (p - my) for u, p in pts)
    s = sxy / sxx
    if s <= 0:
        raise ValueError("Solved scale s<=0 (inverted u_mm/px?)")
    cx = my - s * mx
    resid = [abs(p - (cx + s * u)) for u, p in pts]
    span = max(u for u, _ in pts) - min(u for u, _ in pts)
    resid_px = max(resid)
    resid_pct = (resid_px / (s * span) * 100.0) if span > 0 else 0.0
    return {
        "n": n,
        "s": s,
        "cx": cx,
        "sxx": sxx,
        "span_mm": span,
        "resid_px": resid_px,
        "resid_pct": resid_pct,
        "pp_offset_px": (None if image_width is None else cx - float(image_width) / 2.0),
        "per_point_px": [round(r, 3) for r in resid],
    }


def same_scale(fits):
    """Check whether views share the same px_per_mm export scale (an extra hypothesis, not implied by ortho)."""
    ss = [f["s"] for f in fits.values()]
    if not ss or min(ss) <= 0:
        return None, None
    spread = (max(ss) - min(ss)) / min(ss) * 100.0
    return (spread <= SAME_SCALE_TOL_PCT), spread


def shared_check(fits, shared):
    """Cross-view check: convert shared physical dimensions to mm using each view's own `s`, then compare."""
    rows, bad = [], []
    for item in (shared or []):
        name = item.get("name") or "?"
        vals = {}
        for vname, m in (item.get("measure") or {}).items():
            if vname not in fits:
                continue
            vals[vname] = float(m["px"]) / fits[vname]["s"]
        if len(vals) < 2:
            rows.append({
                "name": name,
                "mm": vals,
                "disagree_pct": None,
                "note": "Measured in only 1 view -> cannot cross-check",
            })
            continue
        lo, hi = min(vals.values()), max(vals.values())
        d = (hi - lo) / lo * 100.0 if lo > 0 else float("inf")
        rows.append({
            "name": name,
            "mm": {k: round(v, 2) for k, v in vals.items()},
            "disagree_pct": round(d, 3),
        })
        if d > SHARED_TOL_PCT:
            bad.append(
                "Shared dimension '%s' disagrees across views by %.2f%% > %.1f%% (%s)"
                % (name, d, SHARED_TOL_PCT, "; ".join("%s=%.1fmm" % (k, v) for k, v in vals.items()))
            )
    return rows, bad


def combine(fits):
    """Inverse-variance (sxx) weighted joint px_per_mm when views are confirmed same-scale."""
    wsum = sum(f["sxx"] for f in fits.values())
    if wsum <= 0:
        raise ValueError("Combined weight is 0")
    return sum(f["s"] * f["sxx"] for f in fits.values()) / wsum


def report(data):
    views = data.get("views") or {}
    if not views:
        raise ValueError("Input contains no 'views'")
    fits, bad = {}, []
    for name, v in views.items():
        f = fit_view(v.get("features") or [], v.get("image_width"))
        fits[name] = f
        if f["resid_pct"] > RESID_TOL_PCT:
            bad.append(
                "%s in-view residual %.2f%% > %.1f%% (non-linear within view: perspective distortion or bad feature points)"
                % (name, f["resid_pct"], RESID_TOL_PCT)
            )

    rows, shared_bad = shared_check(fits, data.get("shared"))
    bad += shared_bad

    is_same, spread = same_scale(fits)
    asserted = data.get("same_scale_asserted")

    L = [
        "=== Per-View Least Squares (px = cx + s*u) ===",
        "view     n  px_per_mm   mm_per_px   pp_offset   resid_px  resid_%   span_mm",
    ]
    for name in sorted(fits):
        f = fits[name]
        pp = "-" if f["pp_offset_px"] is None else ("%+.1f" % f["pp_offset_px"])
        L.append(
            "%-8s %d  %9.6f  %9.4f  %10s  %7.3f  %6.3f%%  %8.1f"
            % (name, f["n"], f["s"], 1.0 / f["s"], pp, f["resid_px"], f["resid_pct"], f["span_mm"])
        )
    L.append("")
    L.append("=== Cross-View px_per_mm Spread (extra hypothesis, NOT implied by orthographic projection) ===")
    L.append("  per-view px_per_mm: " + ", ".join("%s=%.6f" % (k, v["s"]) for k, v in sorted(fits.items())))
    L.append("  spread = %s" % ("-" if spread is None else "%.2f%%" % spread))
    if is_same:
        L.append(
            "  -> px_per_mm spread <= %.1f%%: CAN be treated as a single shared export scale."
            % SAME_SCALE_TOL_PCT
        )
    else:
        L.append(
            "  -> px_per_mm spread > %.1f%%: Views do NOT share a single export scale. This is NOT perspective —"
            % SAME_SCALE_TOL_PCT
        )
        L.append("     views can have different resolutions/crops/ortho_scale while still being strictly orthographic.")
        L.append("     Action: calibrate per-view independently and validate via shared mm dimensions below.")
    L.append("")
    if rows:
        L.append("=== Cross-View Shared Dimension Check (converted to mm per view) ===")
        for r in rows:
            mm = r["mm"]
            L.append(
                "  %-10s %s   disagree %s"
                % (
                    r["name"],
                    ", ".join("%s=%.1fmm" % (k, v) for k, v in sorted(mm.items())),
                    "-" if r["disagree_pct"] is None else "%.2f%%" % r["disagree_pct"],
                )
            )
    else:
        L.append("=== Cross-View Shared Dimension Check: no 'shared' provided ===")
        L.append("  Without at least one shared dimension across >=2 views, cross-view compatibility is unresolved.")
    L.append("")

    if bad:
        L.append("=== VERDICT: FAIL (do not combine views) ===")
        for b in bad:
            L.append("  x " + b)
        L.append("  Fallback: use per-view calibration only for features at the same depth and axis as the view's ruler.")
        L.append("  For cross-depth features, upper-bound perspective error with err ≈ Δz / (D + Δz); if D or Δz is unknown, mark unresolved.")
    elif not asserted and not is_same:
        L.append("=== VERDICT: PER-VIEW ORTHOGRAPHIC OK (do not merge into a single joint px_per_mm) ===")
        L.append("  Each view is internally linear and shared dimensions agree in mm, but views have different export scales.")
        L.append("  Convert measurements per-view using each view's own px_per_mm.")
    else:
        s = combine(fits)
        L.append("=== VERDICT: JOINT ORTHOGRAPHIC PASS (views can be combined) ===")
        L.append("  joint px_per_mm = %.6f (1 px = %.4f mm), sxx-weighted" % (s, 1.0 / s))
    return "\n".join(L)


def _synth(
    base_s=0.15,
    cx=960.0,
    width=1920,
    us=(0.0, 4600.0, 9830.0),
    view_k=None,
    in_view_drift=0.0,
    drift_view="front",
    shared_mm=2000.0,
    shared_px_override=None,
):
    view_k = view_k or {}
    out = {"views": {}, "shared": []}
    for name in ("front", "side", "top"):
        k = float(view_k.get(name, 1.0))
        feats = []
        for i, u in enumerate(us):
            drift = 1.0 + (in_view_drift * (u / float(us[-1])) if name == drift_view else 0.0)
            feats.append({"name": "f%d" % i, "u_mm": u, "px": round(cx + base_s * k * drift * u)})
        out["views"][name] = {"image_width": width, "features": feats}
    meas = {}
    for name in ("front", "side"):
        k = float(view_k.get(name, 1.0))
        px = base_s * k * shared_mm
        if shared_px_override and name in shared_px_override:
            px = shared_px_override[name]
        meas[name] = {"px": round(px, 3)}
    out["shared"] = [{"name": "shared_height", "measure": meas}]
    return out


def _selftest():
    cases = [
        ("A: Same-scale views (should pass and combine)", _synth(view_k={"side": 1.004, "top": 0.997})),
        ("B: In-view perspective drift (15% drift in front -> in-view residual fail)", _synth(in_view_drift=0.15)),
        ("C: Different export scales (side 0.5x, top 0.75x) but strictly ortho -> PER-VIEW ORTHOGRAPHIC OK", _synth(view_k={"side": 0.5, "top": 0.75})),
        (
            "D: Different export scales + 6% shared-dimension mismatch -> cross-view fail",
            _synth(view_k={"side": 0.5, "top": 0.75}, shared_px_override={"side": 0.5 * 0.15 * 2000.0 * 1.06}),
        ),
    ]
    got = {}
    for title, data in cases:
        r = report(data)
        print("######## " + title + " ########")
        print(r)
        print()
        got[title[0]] = r
    ok_a = "joint px_per_mm" in got["A"]
    ok_b = ("in-view residual" in got["B"]) and ("VERDICT: FAIL" in got["B"])
    ok_c = ("PER-VIEW ORTHOGRAPHIC OK" in got["C"]) and ("VERDICT: FAIL" not in got["C"])
    ok_d = ("disagrees across views" in got["D"]) and ("VERDICT: FAIL" in got["D"])
    good = ok_a and ok_b and ok_c and ok_d
    print(
        "SELFTEST %s  (A joint / B in-view fail / C per-view ok / D cross-view fail)  A=%s B=%s C=%s D=%s"
        % ("PASS" if good else "FAIL", ok_a, ok_b, ok_c, ok_d)
    )
    return 0 if good else 1


def main(argv):
    if "--selftest" in argv:
        return _selftest()
    if len(argv) < 2:
        print(__doc__)
        return 2
    with open(argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
    print(report(data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
