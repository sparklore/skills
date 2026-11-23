# `blender-modeling` — Portable Blender Modeling, Assembly & Verification Skill

`blender-modeling` is a self-contained agent skill for 3D modeling, reference-image reconstruction, multi-agent assembly, and automated geometric verification in Blender 4.x / 5.x.

It bundles:
- **`scripts/blender-rt.mjs`**: Unified Node.js CLI launcher exposing all 16 real-time GUI and headless Blender operations (`viewport`, `see`, `do`, `watch`, `loop`, `cmd`, `commands`, `perf`, `opt`, `headless`, `plan`, `worker`, `txn`, `preset`, `job`, `selection`). Automatically starts the local HTTP bridge (`runtime/server.mjs` on `:9877`) on demand and saves viewport screenshots to disk for agent visual inspection.
- **`runtime/`**: Local HTTP bridge (`server.mjs`, `engine.mjs`, `config.mjs`, `launch.mjs`) + 28 declarative Blender Python domain engines (`audit`, `fix`, `uv`, `print`, `sculpt`, `sweep`, `human`, `vehicle`, `shape`, `qc`, `img`, `pipe`, `measure`, `loop`, `search`, `gen`, `gate`, etc. — 186 operations).
- **`addon/blender_bridge.py`**: Non-blocking TCP socket bridge addon (`127.0.0.1:9876`) for live Blender GUI sessions.
- **`scripts/multiview_calib.py`**: Zero-dependency Python script for two-stage multiview orthographic reference calibration (`--selftest` included).
- **`SKILL.md` & `references/`**: Complete methodology, 24 parametric recipes, 9-step reference reconstruction SOP, multiview calibration guide, and a standalone 10-gate verification checklist for reviewer subagents.

---

## Directory Structure

```text
blender-modeling/
├── SKILL.md                                  # Main skill instructions & workflow
├── README.md                                 # Setup & quickstart guide
├── package.json                              # ESM package manifest (zero external npm dependencies)
├── blender-bridge.config.example.json        # Example configuration file
├── LICENSE                                   # MIT License
├── NOTICE.md                                 # Upstream attributions
├── addon/
│   └── blender_bridge.py                     # Blender GUI TCP addon (:9876)
├── runtime/
│   ├── server.mjs                            # Local HTTP bridge daemon (:9877)
│   ├── engine.mjs                            # GUI & headless execution engine
│   ├── config.mjs                            # BLENDER_RT_* & JSON config loader
│   ├── launch.mjs                            # Blender GUI auto-launcher
│   ├── kernel.py                             # Persistent Python kernel (K)
│   ├── offline_bootstrap.py                  # Direct blender -b CLI bootstrap
│   └── dsh_*.py                              # 28 declarative domain modules (186 ops)
├── scripts/
│   ├── blender-rt.mjs                        # Unified CLI entry point
│   └── multiview_calib.py                    # Two-stage multiview reference calibration
└── references/
    ├── cli-reference.md                      # Full CLI & config reference
    ├── recipes.md                            # Generator contract + Recipes 1–24
    ├── reference-reconstruction-sop.md       # 9-step reference reconstruction SOP
    ├── multiview-calibration.md              # Multiview calibration rules & math
    ├── verification-checklist.md             # Standalone 10-gate reviewer checklist
    └── modeling-overview.md                  # Deep-dive bpy.ops.mesh vs bmesh guide
```

---

## Quickstart

### 1. Verify Calibration & Declarative Plan Catalog (Headless)
```bash
SKILL_DIR="$HOME/.agents/skills/blender-modeling"

# Run multiview calibration self-test
python3 "$SKILL_DIR/scripts/multiview_calib.py" --selftest

# Verify all 28 declarative families (186 ops) in headless Blender
node "$SKILL_DIR/scripts/blender-rt.mjs" plan catalog --args '{"verify":true}'
```

### 2. Launch Blender GUI & Run Interactive Steps
```bash
# Launch Blender GUI with the bridge addon enabled
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport open

# Check bridge status
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport status

# Execute Python on the GUI main thread and capture a 420px viewport PNG
node "$SKILL_DIR/scripts/blender-rt.mjs" do \
  --code 'bpy.ops.mesh.primitive_cube_add(size=1.0); bpy.context.active_object.name = "GEO-hull"' \
  --see --view iso --size 420
```

### 3. Run Headless Batch Scripts & Audit Gates
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_scene \
  --blend /path/to/scene.blend \
  --args '{"summary_only":true,"top_k":10,"self_intersect":true}'
```

---

## Configuration

`runtime/config.mjs` auto-detects Blender on macOS (`/Applications/Blender.app/Contents/MacOS/Blender`), Linux (`blender`), and Windows (`C:\Program Files\Blender Foundation\Blender *\blender.exe`).

To customize paths or ports, copy `blender-bridge.config.example.json` to `~/.blender-bridge.config.json` or set `BLENDER_RT_EXE`, `BLENDER_RT_ADDON_PORT` (`9876`), and `BLENDER_RT_HTTP_PORT` (`9877`). See [`references/cli-reference.md`](references/cli-reference.md) for the full configuration table.
