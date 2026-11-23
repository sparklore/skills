#!/usr/bin/env node
/**
 * blender-rt.mjs — Portable CLI launcher for the blender-modeling skill.
 *
 * Bridges any AI coding agent (Antigravity, Claude Code, Codex, Cursor, OpenCode)
 * to a live GUI Blender (via the bundled Blender Bridge addon on 127.0.0.1:9876)
 * and headless Blender processes (via the bundled Node/Python runtime on 127.0.0.1:9877).
 *
 * Subcommands (accepts both short names and full blender_rt_* names):
 *   viewport  status | doctor | who | lease | release | start | stop | restart | launch
 *   see       Capture viewport or custom off-screen camera angle to a PNG file
 *   do        Execute Python code or a .py file in Blender's main thread (persistent kernel K)
 *   watch     Sample viewport frames over a time window (up to 6 saved PNGs + frame hashes)
 *   loop      Run high-speed parameter search in Blender's main thread (160 ticks/s)
 *   cmd       Invoke any of the 39 addon commands directly (e.g. get_scene_info, get_selection)
 *   commands  List available addon commands and asset integration statuses
 *   perf      Cycles render performance diagnostics and optimization presets
 *   opt       Lossless object decimation / safe mesh group joining
 *   headless  Run an isolated `blender -b` process (with kernel K, preload, shots, auto-job)
 *   plan      28-family / 186-op contract, audit, planner, sculpt, sweep, vehicle, human, QC layer
 *   worker    Hot headless `blender -b` session (reuses one process + persistent K)
 *   txn       Two-level transactions: file-level snapshot/restore + object-level mark/revert
 *   preset    Dot-path parameter preset library (save/list/get/apply/delete/export/import)
 *   job       Long-running background job manager (start/status/collect/wait/kill/list)
 *   selection Read native Blender selection / collection / activity state
 */

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { probeHttp, waitHttp } from '../runtime/backend_probe.mjs';
import { CFG } from '../runtime/config.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SKILL_ROOT = path.resolve(HERE, '..');
const SERVER_PATH = process.env.BLENDER_RT_SERVER || process.env.DSH_BLENDER_SERVER || path.join(SKILL_ROOT, 'runtime', 'server.mjs');
const BUNDLED_ADDON = path.join(SKILL_ROOT, 'addon', 'blender_bridge.py');
const HOSTNAME = '127.0.0.1';
const VERSION = '2.5.0';

function resolveHttpPort(explicitPort) {
  const n = Number(explicitPort || process.env.BLENDER_RT_HTTP_PORT || process.env.DSH_BLENDER_HTTP_PORT || CFG.httpPort);
  return Number.isFinite(n) && n > 0 ? n : 9877;
}

function defaultHolder() {
  if (process.env.BLENDER_RT_HOLDER) return process.env.BLENDER_RT_HOLDER;
  if (process.env.DSH_BLENDER_HOLDER) return process.env.DSH_BLENDER_HOLDER;
  try {
    return `agent-${os.userInfo().username}`;
  } catch {
    return 'agent-cli';
  }
}

function base(port) {
  return `http://${HOSTNAME}:${port}`;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function framesDir() {
  const dir = path.join(CFG.workDirWsl, 'frames');
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function cacheFilePath() {
  return path.join(framesDir(), '.frame_cache.json');
}

function frameDedupe(key, hash, force = false) {
  const k = String(key || 'default');
  const h = String(hash || '');
  const p = cacheFilePath();
  let store = {};
  try {
    store = JSON.parse(fs.readFileSync(p, 'utf8')) || {};
  } catch {
    store = {};
  }
  const cur = store[k];
  if (!force && cur && h && cur.hash === h) {
    cur.repeats = (Number(cur.repeats) || 0) + 1;
    try { fs.writeFileSync(p, JSON.stringify(store, null, 2)); } catch {}
    return { dup: true, repeats: cur.repeats, firstAt: cur.firstAt, path: cur.path || null };
  }
  const entry = { hash: h, firstAt: Date.now(), repeats: 0, path: null };
  store[k] = entry;
  try { fs.writeFileSync(p, JSON.stringify(store, null, 2)); } catch {}
  return { dup: false, repeats: 0, firstAt: entry.firstAt, path: null };
}

function recordFramePath(key, filePath) {
  const p = cacheFilePath();
  try {
    const store = JSON.parse(fs.readFileSync(p, 'utf8')) || {};
    if (store[key]) {
      store[key].path = filePath;
      fs.writeFileSync(p, JSON.stringify(store, null, 2));
    }
  } catch {}
}

function spawnBackend(port) {
  const child = spawn(process.execPath, [SERVER_PATH, '--port', String(port)], {
    stdio: 'ignore',
    detached: true,
  });
  child.unref();
  return `spawned pid=${child.pid}`;
}

async function ensureBackend(port) {
  const url = `${base(port)}/health`;
  if (await probeHttp(url, 1200)) return true;
  try {
    spawnBackend(port);
  } catch {}
  return await waitHttp(url, 15000, 300);
}

function killBackendByCmd(port, signal = 'SIGTERM') {
  const killed = [];
  const wantPort = String(port);
  const rows = [];
  let listed = false;
  try {
    for (const d of fs.readdirSync('/proc')) {
      if (!/^[0-9]+$/.test(d) || Number(d) === process.pid) continue;
      try {
        const toks = fs.readFileSync(`/proc/${d}/cmdline`, 'utf8').split('\u0000').filter(Boolean);
        rows.push({ pid: Number(d), toks });
      } catch {}
    }
    listed = true;
  } catch {}
  if (!listed) {
    try {
      for (const line of execFileSync('ps', ['-ax', '-o', 'pid=,command='], { encoding: 'utf8', timeout: 5000 }).split('\n')) {
        const m = /^\s*(\d+)\s+(.*)$/.exec(line);
        if (!m) continue;
        const pid = Number(m[1]);
        if (pid === process.pid) continue;
        rows.push({ pid, toks: m[2].trim().split(/\s+/) });
      }
    } catch {}
  }
  for (const r of rows) {
    let isServer = false;
    let portOk = false;
    let isShell = false;
    for (let i = 0; i < r.toks.length; i++) {
      if (i === 0 && /(^|\/)(bash|sh|zsh|dash|fish|bwrap)$/.test(r.toks[i])) isShell = true;
      if (i >= 1 && /(^|\/)server\.mjs$/.test(r.toks[i])) isServer = true;
      if (r.toks[i] === '--port' && r.toks[i + 1] === wantPort) portOk = true;
    }
    if (isServer && portOk && !isShell) {
      try {
        process.kill(r.pid, signal);
        killed.push(String(r.pid));
      } catch {}
    }
  }
  return killed;
}

function parseBackendBody(text) {
  const t = String(text == null ? '' : text);
  try {
    const o = JSON.parse(t);
    if (o && typeof o === 'object') return o;
  } catch {}
  const lines = t.split('\n').map((s) => s.trim()).filter(Boolean);
  let last = null;
  let beats = 0;
  for (let i = lines.length - 1; i >= 0; i--) {
    try {
      const o = JSON.parse(lines[i]);
      if (!o || typeof o !== 'object' || o.heartbeat === true) continue;
      last = o;
      break;
    } catch {}
  }
  for (let i = 0; i < lines.length; i++) {
    try {
      const o = JSON.parse(lines[i]);
      if (o && o.heartbeat === true) beats++;
    } catch {}
  }
  if (last) {
    last.__heartbeats = beats;
    last.__streamLines = lines.length;
    return last;
  }
  return { ok: false, raw: t.slice(-500), streamLines: lines.length, parseError: 'no JSON line found' };
}

async function withTimeout(url, init, timeoutMs) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);
  try {
    return await fetch(url, { ...(init || {}), signal: ac.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function backendJson(port, urlPath, timeoutMs = 20000, init) {
  const r = await withTimeout(`${base(port)}${urlPath}`, init, timeoutMs);
  const text = await r.text();
  try {
    return JSON.parse(text);
  } catch {
    return { ok: false, raw: text.slice(0, 500) };
  }
}

async function backendPost(port, urlPath, body, timeoutMs = 60000, holder = defaultHolder()) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const r = await fetch(`${base(port)}${urlPath}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ holder, ...(body || {}) }),
      signal: ac.signal,
    });
    const text = await r.text();
    const j = parseBackendBody(text);
    j.__status = r.status;
    return j;
  } finally {
    clearTimeout(timer);
  }
}

async function fetchFrame(port, size, full = false, area = 0) {
  const t0 = Date.now();
  const url = `${base(port)}/frame.png?${full ? `full=1&area=${area}` : `size=${size}`}`;
  const r = await withTimeout(url, {}, 60000);
  if (!r.ok) throw new Error(`frame http ${r.status}`);
  const buf = Buffer.from(await r.arrayBuffer());
  return {
    png: buf,
    ms: Date.now() - t0,
    hash: createHash('md5').update(buf).digest('hex').slice(0, 8),
  };
}

async function fetchView(port, spec, timeoutMs = 180000) {
  const t0 = Date.now();
  const r = await withTimeout(
    `${base(port)}/view`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(spec || {}),
    },
    timeoutMs
  );
  if (!r.ok) {
    const text = await r.text();
    let j = null;
    try { j = JSON.parse(text); } catch {}
    throw new Error(`view http ${r.status} · ${(j && j.error) || text.slice(0, 300)}`);
  }
  let meta = null;
  try {
    const rawHdr = String(r.headers.get('x-dsh-view') || 'null');
    const txt = rawHdr.startsWith('%7B') ? decodeURIComponent(rawHdr) : rawHdr;
    meta = JSON.parse(txt);
  } catch {}
  const buf = Buffer.from(await r.arrayBuffer());
  return {
    png: buf,
    ms: Date.now() - t0,
    meta,
    hash: createHash('md5').update(buf).digest('hex').slice(0, 8),
  };
}

function numTriple(v) {
  if (v === undefined || v === null || v === '') return undefined;
  if (Array.isArray(v)) return v.map((x) => Number(x));
  return String(v).split(/[,\s]+/).filter(Boolean).map((x) => Number(x));
}

function jsonPayload(v) {
  if (v === undefined || v === null || v === '') return {};
  if (typeof v === 'string') {
    try {
      const p = JSON.parse(v);
      return p && typeof p === 'object' && !Array.isArray(p) ? p : {};
    } catch {
      throw new Error(`Invalid JSON object: ${v.slice(0, 200)}`);
    }
  }
  if (typeof v === 'object' && !Array.isArray(v)) return { ...v };
  return {};
}

function splitArgs(s) {
  if (Array.isArray(s)) return s.map((x) => String(x));
  const str = String(s == null ? '' : s);
  const out = [];
  let cur = '';
  let q = null;
  for (let i = 0; i < str.length; i++) {
    const c = str[i];
    if (q) {
      if (c === q) q = null;
      else cur += c;
      continue;
    }
    if (c === '"' || c === "'") {
      q = c;
      continue;
    }
    if (/\s/.test(c)) {
      if (cur) {
        out.push(cur);
        cur = '';
      }
      continue;
    }
    cur += c;
  }
  if (cur) out.push(cur);
  return out;
}

function parseCliArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) {
      positional.push(a);
      continue;
    }
    const eqIdx = a.indexOf('=');
    if (eqIdx !== -1) {
      const k = a.slice(2, eqIdx).replace(/-/g, '_');
      flags[k] = parseScalar(a.slice(eqIdx + 1));
      continue;
    }
    const rawKey = a.slice(2);
    if (rawKey.startsWith('no-')) {
      flags[rawKey.slice(3).replace(/-/g, '_')] = false;
      continue;
    }
    const k = rawKey.replace(/-/g, '_');
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) {
      flags[k] = true;
    } else {
      flags[k] = parseScalar(next);
      i++;
    }
  }
  return { positional, flags };
}

function parseScalar(v) {
  if (v === 'true') return true;
  if (v === 'false') return false;
  if (v === 'null') return null;
  return v;
}

function mergeInputArgs(positional, flags) {
  let baseObj = {};
  if (flags.stdin) {
    const raw = fs.readFileSync(0, 'utf8').trim();
    if (raw) baseObj = JSON.parse(raw);
  } else if (flags.json) {
    baseObj = typeof flags.json === 'string' ? JSON.parse(flags.json) : flags.json;
  }
  const merged = { ...baseObj };
  for (const [k, v] of Object.entries(flags)) {
    if (k === 'json' || k === 'stdin') continue;
    merged[k] = v;
  }
  return { args: merged, positional };
}

function normalizeCmdName(raw) {
  const s = String(raw || '').trim().toLowerCase().replace(/-/g, '_');
  const map = {
    viewport: 'viewport',
    blender_viewport: 'viewport',
    see: 'see',
    rt_see: 'see',
    blender_rt_see: 'see',
    do: 'do',
    act: 'do',
    rt_do: 'do',
    blender_rt_do: 'do',
    watch: 'watch',
    rt_watch: 'watch',
    blender_rt_watch: 'watch',
    loop: 'loop',
    rt_loop: 'loop',
    blender_rt_loop: 'loop',
    cmd: 'cmd',
    rt_cmd: 'cmd',
    blender_rt_cmd: 'cmd',
    commands: 'commands',
    rt_commands: 'commands',
    blender_rt_commands: 'commands',
    perf: 'perf',
    rt_perf: 'perf',
    blender_rt_perf: 'perf',
    opt: 'opt',
    rt_opt: 'opt',
    blender_rt_opt: 'opt',
    headless: 'headless',
    rt_headless: 'headless',
    blender_rt_headless: 'headless',
    plan: 'plan',
    rt_plan: 'plan',
    blender_rt_plan: 'plan',
    worker: 'worker',
    rt_worker: 'worker',
    blender_rt_worker: 'worker',
    txn: 'txn',
    rt_txn: 'txn',
    blender_rt_txn: 'txn',
    preset: 'preset',
    rt_preset: 'preset',
    blender_rt_preset: 'preset',
    job: 'job',
    rt_job: 'job',
    blender_rt_job: 'job',
    selection: 'selection',
    help: 'help',
    '--help': 'help',
    '-h': 'help',
  };
  return map[s] || null;
}

function saveFramePng(buf, prefix, hash, explicitOut) {
  const target = explicitOut
    ? path.resolve(String(explicitOut))
    : path.join(framesDir(), `${prefix}-${Date.now()}-${hash}.png`);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, buf);
  return target;
}

function printOutput(obj) {
  process.stdout.write(JSON.stringify(obj, null, 2) + '\n');
}

function printHelp() {
  const helpText = `blender-rt v${VERSION} — Portable CLI for Blender Modeling & Real-Time Bridge

Usage:
  node scripts/blender-rt.mjs <subcommand> [op/name] [--flag value ...]
  node scripts/blender-rt.mjs <subcommand> --json '{"key":"value"}'

Subcommands:
  viewport <op>     Channel & lifecycle ops:
                    status | doctor | who | lease | release | start | stop | restart | launch
                    Examples:
                      node scripts/blender-rt.mjs viewport doctor
                      node scripts/blender-rt.mjs viewport launch
                      node scripts/blender-rt.mjs viewport lease --holder hull-dev

  see               Capture 3D viewport or custom off-screen camera view (saves PNG to disk):
                    [--max-size 560] [--from "9,-9,6"] [--look-at "0,0,1"] [--lens 50]
                    [--ortho] [--ortho-scale 10] [--view-size "1280x720"]
                    [--shading WIREFRAME|SOLID|MATERIAL|RENDERED] [--overlays]
                    [--view-mode viewport|render] [--full] [--area 0] [--force] [--out /path/to/frame.png]

  do                Execute Python in Blender's main thread (persistent kernel K):
                    [--code "import bpy; ..."] [--file path/to/script.py]
                    [--see | --no-see] [--max-size 560] [--force] [--out /path/to/frame.png]

  watch             Sample viewport over a time window (saves up to 6 PNGs + frame hashes):
                    [--code "..."] [--seconds 2] [--fps 4] [--max-size 420] [--out-dir /path/to/dir]

  loop <op>         In-Blender main-thread parameter search (160 ticks/s, GUI only):
                    start | status | stop | board | export | help | bench
                    [--spec '{...}'] [--limit 10] [--path /tmp/best_fit.py]

  cmd <name>        Invoke any addon command directly (39 commands):
                    [--params '{"name":"Cube"}'] [--timeout-ms 120000]
                    Example: node scripts/blender-rt.mjs cmd get_scene_info

  commands          List all 39 addon commands and 5 asset integration statuses

  perf <op>         Cycles render performance profiler & presets:
                    status | analyze | apply | revert | help [--args '{...}']

  opt <op>          Lossless object decimation / safe mesh joining:
                    analyze | join | help [--args '{"dry_run":true}']

  headless          Run isolated 'blender -b' process (first choice for heavy/batch work):
                    [--script "..."] [--script-file path.py] [--file scene.blend]
                    [--outdir dir] [--preload "audit,qc"] [--engine eevee|cycles|keep|none]
                    [--shots '[...]'] [--as-job] [--wait-s 10] [--timeout-ms 180000]

  plan <op>         28-family / 186-op contract, audit, planner, sculpt, sweep, vehicle, QC layer:
                    [--args '{...}'] [--path report.md]
                    Examples:
                      node scripts/blender-rt.mjs plan catalog
                      node scripts/blender-rt.mjs plan catalog --args '{"classes":true}'
                      node scripts/blender-rt.mjs plan audit_mesh --args '{"scope":"COL_Geo"}'
                      node scripts/blender-rt.mjs plan audit_scene --args '{"self_intersect":true,"summary_only":true}'

  worker <op>       Hot headless 'blender -b' session (reuses one process + persistent K):
                    start | exec | status | stop | restart | list
                    [--name default] [--code "..."] [--engine eevee] [--purge-prefix "lib"]

  txn <op>          Transactions & rollback (file-level snapshot/restore + object-level mark/revert):
                    snapshot | restore | list | prune | mark | revert | marks | drop | help
                    [--label before-boolean] [--objects "GEO-a,GEO-b"] [--into auto|snapshot|original]

  preset <op>       Dot-path parameter preset library:
                    save | list | get | apply | delete | export | import | help
                    [--name mat_steel] [--data '{"inputs.Roughness":0.4}'] [--targets "MAT:Steel"]

  job <op>          Long-running background job manager:
                    start | status | collect | wait | kill | list
                    [--id job-xxx] [--timeout-ms 120000] [--script-file path.py]

  selection [op]    Query native Blender selection, collections, and human/agent activity:
                    latest | live | collections | activity
`;
  process.stdout.write(helpText);
}

async function handleViewport(port, positional, args) {
  const op = String(args.op || positional[0] || 'status');
  const holder = String(args.holder || defaultHolder());

  if (op === 'start') {
    const url = `${base(port)}/health`;
    if (await probeHttp(url, 800)) {
      return { ok: true, op: 'start', status: 'already-running', endpoint: base(port) };
    }
    const how = spawnBackend(port);
    if (await waitHttp(url, 15000, 300)) {
      return { ok: true, op: 'start', status: 'started', how, endpoint: base(port) };
    }
    return { ok: false, op: 'start', error: `Backend failed to respond on ${base(port)}/health within 15s`, how };
  }

  if (op === 'restart') {
    const killed = killBackendByCmd(port, 'SIGTERM');
    await sleep(600);
    killBackendByCmd(port, 'SIGKILL');
    await sleep(300);
    const how = spawnBackend(port);
    const up = await waitHttp(`${base(port)}/health`, 15000, 300);
    return { ok: up, op: 'restart', killed, how, endpoint: base(port) };
  }

  if (op === 'stop') {
    const killed = killBackendByCmd(port, 'SIGTERM');
    await sleep(600);
    const killedHard = killBackendByCmd(port, 'SIGKILL');
    return { ok: true, op: 'stop', killed: Array.from(new Set([...killed, ...killedHard])), endpoint: base(port) };
  }

  if (!(await ensureBackend(port))) {
    return { ok: false, op, error: `Backend unreachable at ${base(port)}` };
  }

  if (op === 'who') {
    const w = await backendJson(port, '/who', 15000);
    return { ok: true, op: 'who', currentHolder: holder, ...w };
  }

  if (op === 'lease' || op === 'release') {
    const body = { holder };
    if (args.ttl_ms) body.ttlMs = Number(args.ttl_ms);
    if (op === 'lease' && args.force) body.force = true;
    const r = await backendPost(port, op === 'lease' ? '/lease' : '/release', body, 20000, holder);
    return { ok: !r.error, op, ...r };
  }

  if (op === 'launch') {
    const body = {};
    if (args.wait_ms) body.waitMs = Number(args.wait_ms);
    if (args.file) body.file = String(args.file);
    if (args.exe) body.exe = String(args.exe);
    if (args.addon_module) body.addonModule = String(args.addon_module);
    if (args.addon_file) body.addonFile = String(args.addon_file);
    else if (fs.existsSync(BUNDLED_ADDON)) body.addonFile = BUNDLED_ADDON;
    if (args.dry_run) body.dryRun = true;
    const waitBudget = Math.max(30000, Number(args.wait_ms || 90000) + 30000);
    const r = await backendPost(port, '/launch', body, waitBudget, holder);
    return { op: 'launch', ...r };
  }

  if (op === 'doctor') {
    const d = await backendJson(port, '/doctor', 25000);
    return { op: 'doctor', skillVersion: VERSION, skillRoot: SKILL_ROOT, ...d };
  }

  const s = await backendJson(port, '/status', 20000);
  return { op: 'status', skillVersion: VERSION, endpoint: base(port), ...s };
}

async function handleSee(port, _positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const size = Math.max(120, Math.min(1600, Number(args.max_size || 560)));
  const full = !!args.full;
  const area = Number(args.area || 0);
  const frm = numTriple(args.from);
  const look = numTriple(args.look_at);
  const force = !!args.force;

  if (frm || look) {
    const spec = {
      from: frm || [7, -7, 5],
      look_at: look || [0, 0, 1],
      lens: args.lens === undefined ? undefined : Number(args.lens),
      ortho: args.ortho === undefined ? undefined : !!args.ortho,
      ortho_scale: args.ortho_scale === undefined ? undefined : Number(args.ortho_scale),
      shading: args.shading || undefined,
      overlays: args.overlays === undefined ? undefined : !!args.overlays,
      mode: args.view_mode || undefined,
    };
    const vs = String(args.view_size || '');
    const mm = vs.match(/^(\d+)\s*[x×]\s*(\d+)$/);
    if (mm) {
      spec.width = Number(mm[1]);
      spec.height = Number(mm[2]);
    } else {
      spec.width = Math.round((size * 16) / 9);
      spec.height = size;
    }
    if (args.diagnostics !== undefined) spec.diagnostics = !!args.diagnostics;
    const fv = await fetchView(port, spec);
    const dkey = 'view:' + JSON.stringify([
      spec.width, spec.height, spec.from, spec.look_at,
      spec.lens ?? null, !!spec.ortho, spec.ortho_scale ?? null,
      spec.shading || null, spec.overlays ?? null, spec.mode || null,
    ]);
    const dd = frameDedupe(dkey, fv.hash, force);
    const savedPath = (dd.dup && dd.path && fs.existsSync(dd.path) && !args.out)
      ? dd.path
      : saveFramePng(fv.png, 'view', fv.hash, args.out);
    if (!dd.dup || args.out) recordFramePath(dkey, savedPath);
    return {
      ok: true,
      mode: (fv.meta && fv.meta.mode) || spec.mode || 'viewport',
      width: spec.width,
      height: spec.height,
      ms: fv.ms,
      bytes: fv.png.length,
      hash: fv.hash,
      from: spec.from,
      look_at: spec.look_at,
      coverage_estimate: fv.meta ? fv.meta.coverage_estimate : null,
      warning: fv.meta && fv.meta.warning ? fv.meta.warning : null,
      duplicate_of_previous: dd.dup,
      repeat_count: dd.repeats,
      image_path: savedPath,
    };
  }

  const f = await fetchFrame(port, size, full, area);
  const dkey = full ? `area:${area}` : `viewport:${size}`;
  const dd = frameDedupe(dkey, f.hash, force);
  const savedPath = (dd.dup && dd.path && fs.existsSync(dd.path) && !args.out)
    ? dd.path
    : saveFramePng(f.png, full ? 'area' : 'viewport', f.hash, args.out);
  if (!dd.dup || args.out) recordFramePath(dkey, savedPath);
  return {
    ok: true,
    mode: full ? 'screenshot_area' : 'viewport',
    max_size: size,
    ms: f.ms,
    bytes: f.png.length,
    hash: f.hash,
    duplicate_of_previous: dd.dup,
    repeat_count: dd.repeats,
    image_path: savedPath,
  };
}

async function handleDo(port, _positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const code = String(args.code || '');
  const file = args.file ? String(args.file) : null;
  if (!code && !file) {
    return { ok: false, error: 'Either --code or --file is required for `do`' };
  }
  const body = { code };
  if (file) body.file = file;
  const r = await backendPost(port, '/act', body, 180000, args.holder || defaultHolder());
  const out = { ...r };
  if (Number(r.mainThreadMs) > 1000) {
    out.warning = `Occupied Blender main thread for ${r.mainThreadMs}ms (>1s). Prefer headless or worker for heavy tasks.`;
  }
  const see = args.see !== false;
  if (see && r && r.ok) {
    try {
      const size = Math.max(120, Math.min(1600, Number(args.max_size || 560)));
      const f = await fetchFrame(port, size);
      const dkey = `do-see:${size}`;
      const dd = frameDedupe(dkey, f.hash, !!args.force);
      const savedPath = (dd.dup && dd.path && fs.existsSync(dd.path) && !args.out)
        ? dd.path
        : saveFramePng(f.png, 'viewport', f.hash, args.out);
      if (!dd.dup || args.out) recordFramePath(dkey, savedPath);
      out.frame = {
        max_size: size,
        ms: f.ms,
        bytes: f.png.length,
        hash: f.hash,
        duplicate_of_previous: dd.dup,
        repeat_count: dd.repeats,
        image_path: savedPath,
      };
    } catch (e) {
      out.frame_error = String((e && e.message) || e);
    }
  }
  return out;
}

async function handleWatch(port, _positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const seconds = Math.max(0.2, Math.min(20, Number(args.seconds || 2)));
  const fps = Math.max(0.5, Math.min(8, Number(args.fps || 4)));
  const size = Math.max(120, Math.min(1600, Number(args.max_size || 420)));
  let actResult = null;
  if (args.code) {
    actResult = await backendPost(port, '/act', { code: String(args.code) }, 180000, args.holder || defaultHolder());
  }
  const total = Math.max(1, Math.min(32, Math.round(seconds * fps)));
  const interval = (seconds * 1000) / total;
  const shots = [];
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    try {
      const f = await fetchFrame(port, size);
      shots.push({ index: i, t_ms: Date.now() - t0, ms: f.ms, hash: f.hash, png: f.png });
    } catch {
      shots.push({ index: i, t_ms: Date.now() - t0, ms: -1, hash: 'ERR', png: null });
    }
    const wait = (i + 1) * interval - (Date.now() - t0);
    if (wait > 1) await sleep(wait);
  }
  const hashes = shots.map((s) => s.hash);
  const distinct = Array.from(new Set(hashes)).length;
  const maxImages = 6;
  const picks = [];
  if (shots.length <= maxImages) {
    for (const s of shots) if (s.png) picks.push(s);
  } else {
    for (let k = 0; k < maxImages; k++) {
      const idx = Math.round((k * (shots.length - 1)) / (maxImages - 1));
      if (shots[idx] && shots[idx].png) picks.push(shots[idx]);
    }
  }
  const outDir = args.out_dir ? path.resolve(String(args.out_dir)) : framesDir();
  fs.mkdirSync(outDir, { recursive: true });
  const savedImages = picks.map((p, k) => {
    const filePath = path.join(outDir, `watch-${Date.now()}-${k}-${p.hash}.png`);
    fs.writeFileSync(filePath, p.png);
    return { index: p.index, t_ms: p.t_ms, hash: p.hash, image_path: filePath };
  });
  return {
    ok: true,
    seconds,
    fps,
    sampled_frames: shots.length,
    distinct_hashes: distinct,
    timeline: shots.map((s) => ({ index: s.index, t_ms: s.t_ms, ms: s.ms, hash: s.hash })),
    saved_frames: savedImages,
    ...(actResult ? { act: actResult } : {}),
  };
}

async function handleCmd(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const name = String(args.name || positional[0] || '');
  if (!name) return { ok: false, error: 'Command name is required (e.g. `cmd get_scene_info`)' };
  const params = jsonPayload(args.params);
  const timeoutMs = Number(args.timeout_ms || 120000);
  return await backendPost(port, '/cmd', { name, params, timeoutMs }, Math.max(300000, timeoutMs + 30000), args.holder || defaultHolder());
}

async function handleCommands(port) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  return await backendJson(port, '/commands', 120000);
}

async function handleLoop(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'status');
  const payload = {
    op,
    spec: jsonPayload(args.spec),
    history: Number(args.history || 8),
    board: Number(args.board || 0),
    limit: Number(args.limit || 10),
    groups: args.groups !== false,
    path: args.path ? String(args.path) : undefined,
    top: Number(args.top || 1),
    include_variants: !!args.include_variants,
    note: String(args.note || ''),
    iterations: Number(args.iterations || 5000),
  };
  return await backendPost(port, '/loop', payload, 300000, args.holder || defaultHolder());
}

async function handlePerf(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'status');
  const pargs = jsonPayload(args.args);
  return await backendPost(
    port,
    '/perf',
    { op, args: Object.keys(pargs).length ? pargs : undefined },
    600000,
    args.holder || defaultHolder()
  );
}

async function handleOpt(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'analyze');
  const oargs = jsonPayload(args.args);
  return await backendPost(
    port,
    '/opt',
    { op: op === 'join' ? 'opt_join' : 'opt_analyze', args: Object.keys(oargs).length ? oargs : undefined },
    600000,
    args.holder || defaultHolder()
  );
}

async function handleHeadless(port, _positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const runId = 'run-' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const asJob = !!args.as_job;
  const waitS = args.wait_s !== undefined && args.wait_s !== null && args.wait_s !== '' ? Number(args.wait_s) : null;
  let shotsVal = args.shots;
  if (typeof shotsVal === 'string') {
    try { shotsVal = JSON.parse(shotsVal); } catch {}
  }
  const scriptInline = args.script || args.code || '';
  const scriptFileVal = args.script_file || args.py_file || (args.file && String(args.file).endsWith('.py') ? args.file : undefined);
  const blendFileVal = args.blend || (args.file && !String(args.file).endsWith('.py') ? args.file : undefined);
  const body = {
    script: String(scriptInline),
    scriptFile: scriptFileVal ? String(scriptFileVal) : undefined,
    file: blendFileVal ? String(blendFileVal) : undefined,
    outdir: args.outdir ? String(args.outdir) : undefined,
    timeoutMs: args.timeout_ms ? Number(args.timeout_ms) : undefined,
    factoryStartup: args.factory_startup !== false,
    bootstrap: args.bootstrap !== false,
    preload: args.preload ? String(args.preload) : undefined,
    gpu: args.gpu ? String(args.gpu) : undefined,
    engine: args.engine ? String(args.engine) : undefined,
    useUserConfig: !!args.use_user_config,
    includeNoise: !!args.include_noise,
    expect: args.expect ? jsonPayload(args.expect) : undefined,
    workdir: args.workdir ? String(args.workdir) : undefined,
    env: args.env ? jsonPayload(args.env) : undefined,
    outJson: args.out_json ? String(args.out_json) : undefined,
    shots: shotsVal,
    runId,
  };
  if (args.args) body.args = splitArgs(args.args);
  const holder = args.holder || defaultHolder();
  const waitWindowMs = Number(process.env.BLENDER_RT_HEADLESS_WAIT_MS || process.env.DSH_HEADLESS_WAIT_MS || 100000);

  if (asJob) {
    const jr = await backendPost(port, '/headless', { ...body, asJob: true }, 60000, holder);
    if (!jr || jr.error) return jr;
    const inner = jr.result && typeof jr.result === 'object' ? jr.result : jr;
    const jobId = String(inner.jobId || (inner.job && inner.job.id) || '');
    const budget = waitS && waitS > 0 ? Math.min(Math.round(waitS * 1000), waitWindowMs + 2000) : 0;
    if (!budget) return { ok: true, mode: 'promoted', jobId, runId, job: inner.job || null };
    const wr = await backendPost(port, '/job', { op: 'wait', id: jobId, timeoutMs: budget }, budget + 30000, holder);
    return { ok: true, mode: 'job', jobId, runId, ...(wr || {}) };
  }

  const serverBudget = 60000 + Number(body.timeoutMs || 180000);
  try {
    return await backendPost(port, '/headless', body, Math.min(serverBudget, waitWindowMs + 2000), holder);
  } catch (e) {
    const statusRes = await backendPost(port, '/job', { op: 'status', id: runId }, 10000, holder).catch(() => null);
    return {
      ok: null,
      mode: 'promoted',
      promoted: true,
      runId,
      jobId: runId,
      reason: String((e && e.message) || e),
      job: statusRes && statusRes.job ? statusRes.job : null,
      hint: `Task is still running in background. Collect with: node scripts/blender-rt.mjs job wait --id ${runId}`,
    };
  }
}

async function handlePlan(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'status');
  const payload = jsonPayload(args.args);
  if (op === 'report' && args.path) payload.path = String(args.path);
  return await backendPost(port, '/plan', { op, args: payload }, 300000, args.holder || defaultHolder());
}

async function handleWorker(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'status');
  const body = { op };
  if (args.code !== undefined) body.code = String(args.code);
  if (args.timeout_ms) body.timeoutMs = Number(args.timeout_ms);
  if (args.gpu) body.gpu = String(args.gpu);
  if (args.engine) body.engine = String(args.engine);
  if (args.purge_prefix) body.purgePrefix = String(args.purge_prefix);
  if (args.name) body.name = String(args.name);
  const budget = 60000 + Number(body.timeoutMs || 120000);
  return await backendPost(port, '/worker', body, budget, args.holder || defaultHolder());
}

async function handleTxn(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'list');
  const a = {};
  if (args.label || args.tag) a.label = String(args.label || args.tag);
  if (args.note) a.note = String(args.note);
  if (args.keep) a.keep = Number(args.keep);
  if (args.into) a.into = String(args.into);
  if (typeof args.backup === 'boolean') a.backup = args.backup;
  if (args.objects) {
    a.objects = Array.isArray(args.objects)
      ? args.objects
      : String(args.objects).split(',').map((s) => s.trim()).filter(Boolean);
  }
  return await backendPost(port, '/txn', { op, args: a }, 300000, args.holder || defaultHolder());
}

async function handlePreset(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'list');
  const a = {};
  if (args.name) a.name = String(args.name);
  if (args.kind) a.kind = String(args.kind);
  if (args.note) a.note = String(args.note);
  if (args.path) a.path = String(args.path);
  if (args.tags) a.tags = Array.isArray(args.tags) ? args.tags : String(args.tags).split(',').map((x) => x.trim()).filter(Boolean);
  if (args.names) a.names = Array.isArray(args.names) ? args.names : String(args.names).split(',').map((x) => x.trim()).filter(Boolean);
  if (args.targets) a.targets = Array.isArray(args.targets) ? args.targets : String(args.targets).split(',').map((x) => x.trim()).filter(Boolean);
  if (args.data !== undefined) {
    a.data = typeof args.data === 'string' ? JSON.parse(args.data) : args.data;
  }
  if (args.overwrite === false) a.overwrite = false;
  return await backendPost(port, '/preset', { op, args: a }, 300000, args.holder || defaultHolder());
}

async function handleJob(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'list');
  const body = { op };
  if (args.id || args.job_id || positional[1]) body.id = String(args.id || args.job_id || positional[1]);
  if (args.script !== undefined || args.code !== undefined) body.script = String(args.script ?? args.code);
  if (args.script_file || args.py_file) body.scriptFile = String(args.script_file || args.py_file);
  if (args.args) body.args = splitArgs(args.args);
  if (args.env) body.env = jsonPayload(args.env);
  if (args.file || args.blend) body.file = String(args.file || args.blend);
  if (args.outdir) body.outdir = String(args.outdir);
  if (args.engine) body.engine = String(args.engine);
  if (args.preload) body.preload = String(args.preload);
  if (args.workdir) body.workdir = String(args.workdir);
  if (args.out_json) body.outJson = String(args.out_json);
  if (args.include_noise !== undefined) body.includeNoise = !!args.include_noise;
  if (args.factory_startup !== undefined) body.factoryStartup = !!args.factory_startup;
  if (args.bootstrap !== undefined) body.bootstrap = !!args.bootstrap;
  if (args.tail) body.tail = Number(args.tail);
  if (args.timeout_ms) body.timeoutMs = Number(args.timeout_ms);
  const budget = op === 'wait' ? Math.min(600000, Number(args.timeout_ms || 120000)) + 30000 : 60000;
  return await backendPost(port, '/job', body, budget, args.holder || defaultHolder());
}

async function handleSelection(port, positional, args) {
  if (!(await ensureBackend(port))) {
    return { ok: false, error: `Backend unreachable at ${base(port)}` };
  }
  const op = String(args.op || positional[0] || 'live');
  if (op === 'latest') {
    return await backendJson(port, '/host/selection/latest', 10000);
  }
  if (op === 'collections') {
    return await backendPost(port, '/cmd', { name: 'get_collections', params: {}, timeoutMs: 30000 }, 35000, args.holder || defaultHolder());
  }
  if (op === 'activity') {
    return await backendPost(port, '/cmd', { name: 'get_activity_state', params: {}, timeoutMs: 15000 }, 20000, args.holder || defaultHolder());
  }
  return await backendPost(port, '/cmd', { name: 'get_selection', params: {}, timeoutMs: 30000 }, 35000, args.holder || defaultHolder());
}

async function main() {
  const rawArgv = process.argv.slice(2);
  if (!rawArgv.length) {
    printHelp();
    process.exit(0);
  }
  const cmd = normalizeCmdName(rawArgv[0]);
  if (!cmd || cmd === 'help') {
    printHelp();
    process.exit(cmd ? 0 : 1);
  }
  const { positional, flags } = parseCliArgs(rawArgv.slice(1));
  if (flags.help) {
    printHelp();
    process.exit(0);
  }
  const { args } = mergeInputArgs(positional, flags);
  const port = resolveHttpPort(args.port);

  const handlers = {
    viewport: handleViewport,
    see: handleSee,
    do: handleDo,
    watch: handleWatch,
    cmd: handleCmd,
    commands: handleCommands,
    loop: handleLoop,
    perf: handlePerf,
    opt: handleOpt,
    headless: handleHeadless,
    plan: handlePlan,
    worker: handleWorker,
    txn: handleTxn,
    preset: handlePreset,
    job: handleJob,
    selection: handleSelection,
  };

  const fn = handlers[cmd];
  const res = await fn(port, positional, args);
  printOutput(res);
  if (res && res.ok === false) process.exitCode = 1;
}

main().catch((err) => {
  printOutput({ ok: false, error: String((err && err.message) || err) });
  process.exit(1);
});
