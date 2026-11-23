# CLI Reference (`scripts/blender-rt.mjs`)

`scripts/blender-rt.mjs` is the unified command-line interface for the `blender-modeling` skill. It communicates with the bundled local HTTP bridge (`runtime/server.mjs`, default `127.0.0.1:9877`), which in turn connects over TCP (`127.0.0.1:9876`) to the Blender GUI addon (`addon/blender_bridge.py`) and manages headless `blender -b` workers (`runtime/*.py`).

When invoked, `blender-rt.mjs` automatically starts `runtime/server.mjs` in the background if it is not already running.

---

## 1. General Invocation & Flags

```bash
SKILL_DIR="${BLENDER_SKILL_DIR:-$HOME/.agents/skills/blender-modeling}"
node "$SKILL_DIR/scripts/blender-rt.mjs" <subcommand> [action] [options]
```

### Global Options
- `--args '<json>'` / `--json '<json>'`: Merge raw JSON parameters into the payload.
- `--stdin`: Read JSON payload from `stdin`.
- `--holder <id>`: Override write-lease holder ID (default: `BLENDER_RT_HOLDER` or `agent-<username>`).
- `--out <file.png>` / `--out-dir <dir>`: Save returned viewport/watch PNG images to a specific file or directory (defaults to `/tmp/blender-rt-frames`).

All commands print structured JSON to `stdout` and exit `0` on success or `1` on error. Whenever a command returns one or more viewport images (`see`, `do --see`, `watch`), `blender-rt.mjs` writes each image to disk and replaces base64 blobs with `"image_path": "/abs/path/to/frame.png"` so you can inspect the image directly with `read_file`.

---

## 2. Subcommand Reference (16 Commands)

### 2.1 `viewport` — Manage Blender GUI & Bridge Status
```bash
# Check HTTP server, Blender TCP addon connection, and active write lease
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport status

# Launch Blender GUI on the local display and install/enable the bridge addon
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport open
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport open --blend /abs/path/scene.blend

# Acquire / renew / release write lease (multi-agent arbitration)
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport lease --holder builder-1 --ttl-ms 120000
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport release --holder builder-1

# Stop the background runtime/server.mjs HTTP daemon
node "$SKILL_DIR/scripts/blender-rt.mjs" viewport stop
```

### 2.2 `see` — Capture Viewport & Scene Graph (`get_scene`)
Captures an offscreen OpenGL viewport image and returns the scene object list (`name`, `type`, `loc`, `rot_deg`, `scale`, `dims`, `verts`, `faces`, `visible`, `selected`), active camera info, and a `frame_hash` (MD5) for change detection.

```bash
# Fast 420px overview (default)
node "$SKILL_DIR/scripts/blender-rt.mjs" see

# High-resolution 900px inspection from a canonical angle
node "$SKILL_DIR/scripts/blender-rt.mjs" see --view front --shading SOLID --size 900

# Orbit yaw/pitch around a target object or world point with custom distance
node "$SKILL_DIR/scripts/blender-rt.mjs" see --yaw 35 --pitch 25 --distance 3.5 --target "GEO-hull" --size 900

# Scene graph JSON only (skip image rendering)
node "$SKILL_DIR/scripts/blender-rt.mjs" see --no-image
```

**Options**:
- `--view <front|side|top|iso|cam|current>`: Standard camera angle (`front` looks from `-Y` to `+Y`, `side` from `+X` to `-X`, `top` from `+Z` to `-Z`, `iso` is `(1,-1,0.8)`, `cam` uses active scene camera, `current` uses user's live 3D viewport).
- `--yaw <deg>` / `--pitch <deg>`: Spherical orbit angles in degrees (`yaw=0` is `-Y`, `yaw=90` is `+X`; `pitch=0` is horizontal, `pitch=90` is top-down). Overrides `--view`.
- `--distance <m>`: Camera distance in meters from target (auto-fit to scene bounding box if omitted).
- `--target <objName>` or `--target '[x,y,z]'`: Look-at target.
- `--shading <SOLID|MATERIAL|RENDERED|WIREFRAME>`: Viewport shading mode (default `SOLID`).
- `--size <128..1920>`: Output image size in pixels (default `420`; use `900` for geometry verification).
- `--no-image`: Omit viewport PNG capture and return scene metadata only.
- `--out <path>`: Write the PNG to `<path>`.

### 2.3 `do` — Execute Python on Blender GUI Main Thread (`exec`)
Runs Python inside the live GUI Blender instance with `bpy`, `bmesh`, `mathutils`, and `C = bpy.context`, `D = bpy.data`, `O = bpy.ops` pre-imported. Every call automatically pushes an Undo step (`"BlenderRT exec"`), so `Ctrl+Z` works in the GUI.

```bash
# Inline Python execution + automatic post-execution screenshot
node "$SKILL_DIR/scripts/blender-rt.mjs" do \
  --code 'bpy.ops.mesh.primitive_cube_add(size=1.0); bpy.context.active_object.name = "GEO-box"' \
  --see --view iso --size 420

# Execute a Python script file without taking a screenshot
node "$SKILL_DIR/scripts/blender-rt.mjs" do --file /tmp/build_step.py --no-see
```

**Options**:
- `--code '<python>'` or `--file <script.py>`: Python code to run on the GUI main thread.
- `--see` / `--no-see`: Capture (`--see`, default) or skip (`--no-see`) a viewport snapshot after execution.
- `--view <...>`, `--shading <...>`, `--size <px>`: Post-execution screenshot settings.

> **Important**: `do` runs on the GUI main thread with a 10-second socket timeout (`main-thread-busy` if exceeded). Never run `bpy.ops.render.render()`, high-poly remeshing (`voxel_size < 0.01`), heavy fluid/cloth baking, or brute-force loops inside `do`. Use `headless`, `worker`, `loop`, or `job` instead.

### 2.4 `watch` — Real-Time Animation & Physics Burst Capture
Steps through a frame range (or captures live modal timer ticks) and writes deduplicated viewport frames to disk.

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" watch \
  --frames 24 --step-frames 2 --fps 12 --view iso --shading SOLID --size 384
```

**Options**:
- `--frames <1..120>`: Maximum frames to capture (default `16`).
- `--fps <1..30>`: Capture rate (default `8`).
- `--step-frames <0..250>`: Timeline frames to advance per tick (`1` = step timeline/physics; `0` = observe live viewport without advancing timeline).
- `--start-frame <int>`: Jump to start frame before recording.
- `--view`, `--shading`, `--size`, `--out-dir`: Viewport and output settings.

### 2.5 `loop` — Non-Blocking Main-Thread Parameter Search (`bpy.app.timers`)
Runs a time-sliced search state machine inside the live GUI Blender (`dsh_loop.py` + `dsh_measure.py`). Each timer slice runs for `<=budget_ms` (default 20 ms) so the user's viewport stays responsive and updates live whenever a better candidate is found.

```bash
# Start a search (or pass full config via --args / --stdin)
node "$SKILL_DIR/scripts/blender-rt.mjs" loop start --args '{
  "name": "hull_fit",
  "target": "GEO-hull",
  "space": {"len": [3.8, 4.6, 0.2], "wid": [1.6, 2.0, 0.1]},
  "strategy": "coord",
  "budget_ms": 20,
  "max_evals": 60,
  "build_code": "import bpy, bmesh\n...",
  "eval_spec": {
    "metrics": [
      {"type": "aabb_err", "target_dims": [4.2, 1.8, 1.4], "weight": 1.0}
    ]
  }
}'

# Poll status / leaderboard / pause / resume / stop / export best script
node "$SKILL_DIR/scripts/blender-rt.mjs" loop status
node "$SKILL_DIR/scripts/blender-rt.mjs" loop board --top-k 5
node "$SKILL_DIR/scripts/blender-rt.mjs" loop pause
node "$SKILL_DIR/scripts/blender-rt.mjs" loop resume
node "$SKILL_DIR/scripts/blender-rt.mjs" loop stop
node "$SKILL_DIR/scripts/blender-rt.mjs" loop export --out-py /tmp/best_hull.py
```

### 2.6 `cmd` & `commands` — Registered Fast Addon Commands
Invokes one of the 17 built-in fast commands on the live GUI addon without writing boilerplate Python.

```bash
# List all registered commands and their parameter schemas
node "$SKILL_DIR/scripts/blender-rt.mjs" commands

# Execute a fast command
node "$SKILL_DIR/scripts/blender-rt.mjs" cmd add_primitive \
  --args '{"kind":"cylinder","name":"GEO-shaft","size":0.5,"location":[0,0,0.5]}'

node "$SKILL_DIR/scripts/blender-rt.mjs" cmd set_material \
  --args '{"name":"GEO-shaft","color":[0.2,0.22,0.25],"metallic":0.85,"roughness":0.3}'
```

Registered commands include: `ping`, `get_scene`, `capture_viewport`, `exec`, `watch_burst`, `list_commands`, `get_perf`, `select`, `transform`, `add_primitive`, `delete_objects`, `set_material`, `add_light`, `set_camera`, `Duplicate`, `set_visibility`, `frame_jump`, `apply_modifier`, `shade_smooth`.

### 2.7 `perf` — Scene Performance & Diagnostics
```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" perf
```
Returns Blender version, GPU renderer string, process RSS memory, object/mesh/light/material counts, total vertices/faces/tris, and top 5 heaviest meshes.

### 2.8 `opt` — Declarative SciPy / Grid Optimizer
Runs a black-box optimizer (`nelder-mead`, `powell`, or `grid`) on the live GUI scene where each step sets parameters and evaluates a scalar cost expression.

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" opt --args '{
  "method": "nelder-mead",
  "max_iter": 40,
  "tol": 1e-4,
  "params": [
    {"name": "z_pos", "init": 1.2, "min": 0.0, "max": 3.0, "setter": "D.objects[\"GEO-cap\"].location.z = val"}
  ],
  "cost_expr": "(D.objects[\"GEO-cap\"].location.z - 0.85)**2"
}'
```

### 2.9 `headless` — Background `blender -b` Execution (Persistent Kernel `K`)
Runs a standalone `blender -b --factory-startup` process (up to 5 minutes) with the persistent runtime kernel `K` (`runtime/kernel.py`) and optional preloaded domain modules (`runtime/dsh_*.py`). Never blocks or touches the user's GUI Blender.

```bash
# Run inline Python or a script file in headless Blender with preloaded modules
node "$SKILL_DIR/scripts/blender-rt.mjs" headless \
  --preload vehicle,audit,qc \
  --file /tmp/build_and_audit.py \
  --save-blend /tmp/vehicle_out.blend
```

**Options**:
- `--code '<python>'` or `--file <script.py>`: Script to execute. Inside the script, `K` is pre-injected as a global (`K.dsh_vehicle`, `K.dsh_audit`, etc.) and preloaded symbols (`audit_gate`, `vehicle_base`, etc.) are available directly in globals.
- `--blend <in.blend>`: Open an existing `.blend` file before running (omit for `--factory-startup` clean scene).
- `--save-blend <out.blend>`: Save the resulting `.blend` after execution.
- `--preload <mod1,mod2>` or `--preload '["audit","qc"]'`: Preload runtime modules into globals (`kit`, `audit`, `fix`, `uv`, `print`, `sculpt`, `sweep`, `human`, `vehicle`, `qc`, `img`, `pipe`, `measure`, `loop`, `search`, `gen`, `gate`).
- `--render-out <out.png>`, `--engine <BLENDER_EEVEE|CYCLES>`, `--samples <n>`, `--res-x <px>`, `--res-y <px>`, `--frame <n>`: Render after script execution.
- `--timeout-ms <ms>`: Execution timeout (default `120000`, max `300000`).

### 2.10 `plan` — Declarative Domain Engines (28 Families / 186 Ops)
Runs a declarative operation from the 28 domain families (`audit_*`, `fix_*`, `uv_*`, `print_*`, `sculpt_*`, `sweep_*`, `human_*`, `vehicle_*`, `shape_*`, `section_*`, `crease_*`, `inset_*`, `clear_*`, `qc_*`, `img_*`, `pipe_*`, `generator_*`, `gate_*`, etc.) inside headless Blender and returns `PLAN_JSON:` as structured JSON.

```bash
# Inspect full catalog (28 families, 186 ops) and verify runtime module wiring
node "$SKILL_DIR/scripts/blender-rt.mjs" plan catalog --args '{"verify":true}'

# Inspect parameter schema for a single family
node "$SKILL_DIR/scripts/blender-rt.mjs" plan catalog --args '{"family":"audit"}'

# Run assembly gate on a saved .blend file
node "$SKILL_DIR/scripts/blender-rt.mjs" plan audit_gate --blend /tmp/scene.blend --args '{
  "targets": ["GEO-body", "GEO-lid"],
  "expected_dims": {"GEO-body": [100, 80, 50]},
  "unit_scale": 1000.0
}'
```

### 2.11 `worker` — Persistent Background `blender -b` Pool (`:9878`)
Eliminates the ~1.2s cold-start penalty of spawning `blender -b` on every `headless` or `plan` call by keeping a persistent background `blender -b` daemon alive on TCP port `9878`.

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" worker start
node "$SKILL_DIR/scripts/blender-rt.mjs" worker status
node "$SKILL_DIR/scripts/blender-rt.mjs" worker exec --code 'result = [o.name for o in D.objects]' --preload audit
node "$SKILL_DIR/scripts/blender-rt.mjs" worker reset
node "$SKILL_DIR/scripts/blender-rt.mjs" worker stop
```

### 2.12 `txn` — Named Checkpoints & Rollback (`mark` / `revert` / `diff`)
Snapshots the live GUI scene to a disk `.blend` checkpoint before risky operations (such as Booleans, remeshing, or multi-part assembly) and restores or diffs against it in one command.

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" txn mark --tag pre-boolean
node "$SKILL_DIR/scripts/blender-rt.mjs" txn list
node "$SKILL_DIR/scripts/blender-rt.mjs" txn diff --tag pre-boolean
node "$SKILL_DIR/scripts/blender-rt.mjs" txn revert --tag pre-boolean
```

### 2.13 `preset` — Lighting, Floor, Camera & Material Presets
```bash
# List available studio lighting setups, cameras, and PBR material presets
node "$SKILL_DIR/scripts/blender-rt.mjs" preset list

# Apply 3-point studio lighting + shadow-catcher ground + camera framing
node "$SKILL_DIR/scripts/blender-rt.mjs" preset studio \
  --args '{"lighting":"studio_3pt","floor":true,"camera":"hero_iso"}'

# Apply a named PBR material preset (steel, brushed_aluminum, gold, matte_plastic, glass, ceramic, skin, car_paint, ...)
node "$SKILL_DIR/scripts/blender-rt.mjs" preset material \
  --args '{"target":"GEO-chassis","preset":"brushed_aluminum"}'
```

### 2.14 `job` — Asynchronous Long-Running Jobs (Cycles Renders, Bakes, Batch Jobs)
Starts a background `blender -b` job without blocking the CLI, tracks progress (`FRA:x` / `Sample x/y`), and retains logs and output paths.

```bash
node "$SKILL_DIR/scripts/blender-rt.mjs" job start \
  --blend /tmp/scene.blend --render-out /tmp/final_render.png \
  --engine CYCLES --samples 128 --res-x 1920 --res-y 1080

node "$SKILL_DIR/scripts/blender-rt.mjs" job list
node "$SKILL_DIR/scripts/blender-rt.mjs" job status --job-id job_1
node "$SKILL_DIR/scripts/blender-rt.mjs" job cancel --job-id job_1
```

### 2.15 `selection` — Live GUI Selection & User Activity Readback
Queries what the human user has selected or modified in the Blender GUI viewport.

```bash
# Latest cached selection event pushed by the GUI addon
node "$SKILL_DIR/scripts/blender-rt.mjs" selection latest

# Live poll of active/selected objects + Edit Mode selected vert/edge/face counts
node "$SKILL_DIR/scripts/blender-rt.mjs" selection live

# Full Collection hierarchy tree
node "$SKILL_DIR/scripts/blender-rt.mjs" selection collections

# Detect whether the user is actively interacting in the GUI (returns AI_PAUSED if busy)
node "$SKILL_DIR/scripts/blender-rt.mjs" selection activity --pause-window-ms 5000
```

---

## 3. Persistent Kernel (`K`) & Offline Escape Hatch

### 3.1 Accessing `K` Inside `do`, `headless`, or `worker`
When running inside `headless` or `worker`, the kernel `K` (`runtime/kernel.py`) is already injected. Inside a GUI `do` script, or inside any custom Python module, you can bootstrap `K` in two lines:

```python
import sys
K = sys.modules.get("dsh_rt_kernel")
if K is None:
    sys.path.insert(0, "/Users/kam/.agents/skills/blender-modeling/runtime")
    import kernel as K
    K.bootstrap()

# Lazy-load any domain module via K.dsh_kit.kapi()
audit = K.dsh_kit.kapi("dsh_audit")
res = audit.audit_gate(targets=["GEO-hull"], unit_scale=1000.0)
```

### 3.2 Offline Command-Line Escape Hatch (`offline_bootstrap.py`)
If the HTTP bridge is down or you want to invoke `blender -b` directly from a shell script, use `runtime/offline_bootstrap.py`:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
  --python "$SKILL_DIR/runtime/offline_bootstrap.py" -- \
  vehicle audit qc --run /tmp/my_script.py
```

---

## 4. Configuration & Environment Variables

Configuration is resolved in the following priority order (highest to lowest):
1. Explicit CLI flags (`--holder`, etc.)
2. `BLENDER_RT_*` environment variables (with fallback to legacy `DSH_BLENDER_*` variables)
3. JSON config file (`BLENDER_RT_CONFIG` -> `./blender-bridge.config.json` -> `~/.blender-bridge.config.json` -> `~/.dsh/dsh-blender.config.json`)
4. Auto-detected OS defaults (`/Applications/Blender.app/Contents/MacOS/Blender` on macOS, `blender` on Linux, `C:\Program Files\Blender Foundation\Blender *\blender.exe` on Windows).

| Variable | Config JSON Key | Default | Description |
|----------|----------------|---------|-------------|
| `BLENDER_RT_EXE` | `blenderExe` | Auto-detected | Path to Blender executable |
| `BLENDER_RT_ADDON_HOST` | `addonHost` | `127.0.0.1` | Blender GUI TCP bridge host |
| `BLENDER_RT_ADDON_PORT` | `addonPort` | `9876` | Blender GUI TCP bridge port |
| `BLENDER_RT_HTTP_PORT` | `httpPort` | `9877` | Local Node HTTP runtime server port |
| `BLENDER_RT_WORKER_PORT` | `workerPort` | `9878` | Persistent headless worker TCP port |
| `BLENDER_RT_HOLDER` | `holder` | `agent-<user>` | Default write-lease holder ID |
| `BLENDER_RT_LEASE_TTL_MS` | `leaseTtlMs` | `60000` | Write-lease TTL in milliseconds |
| `BLENDER_RT_WORKDIR` | `workdir` | `/tmp/dsh-blender-rt` | Scratch directory for checkpoints, jobs, and temp files |

---

## 5. Troubleshooting Table

| Symptom / Error Code | Root Cause | Fix |
|----------------------|------------|-----|
| `blender-unreachable` (`ECONNREFUSED 127.0.0.1:9876`) | Blender GUI is not running or the bridge addon is not enabled on `:9876`. | Run `node "$SKILL_DIR/scripts/blender-rt.mjs" viewport open` to launch Blender with the addon, or use `headless` / `plan` if GUI is not required. |
| `main-thread-busy` (socket timeout > 10s on `do`) | A heavy operation (`bpy.ops.render.render()`, fine Voxel Remesh, heavy Boolean loop) blocked Blender's GUI main thread. | Move heavy computation to `headless`, `worker`, `job`, or time-sliced `loop`. Never render or remesh `< 0.01m` inside `do`. |
| `HTTP 409 {"error":"leased","holder":"..."}` | Another agent holds the write lease on the GUI viewport. | Wait for their lease to expire, coordinate via unique `--holder <id>`, or explicitly release the stale lease with `viewport release --holder <other-id>`. |
| `AI_PAUSED` | User is actively clicking/editing in the Blender GUI within `pause_window_ms`. | Wait a few seconds and re-check `selection activity` + `selection live` before writing to the scene so you don't overwrite the user's manual edits. |
| `Operator bpy.ops.mesh.*.poll() failed, context is incorrect` | Edit Mode `bpy.ops.mesh.*` operator called inside `headless` (`blender -b` has no 3D View area). | Rewrite the operation using `bmesh` (`Recipe 3b` in `references/recipes.md`). |
| `audit_mesh` reports `boundary_edges > 0` on a mirrored mesh | `audit_mesh` inspects raw `ob.data` (unevaluated mesh before modifiers). | Either check before adding Mirror, or apply the Mirror modifier on a temporary copy before running `audit_mesh(watertight=True)`. |
