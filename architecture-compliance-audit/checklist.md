> 在 **sparklore-forge 仓根**执行（不是本 skills 子模块根）。

# 扫描清单（可复制命令）

在 forge 仓根执行。clients 路径：`sparklore-clients/`（**独立 git 仓，嵌在 forge 工作树里，不被 forge 跟踪**）。

## 0. 仪器自检（先跑；不过就停，别往下扫）

下面 A–G 全部以 `sparklore-clients/` 为相对路径，路径不在位时结果不可信。

**2026-11-19 实测更正（原文的机制描述不准确）**：裸 `rg`/`grep` 扫不存在的路径**退出 2、会红**，并不会假绿；真正骗人的是接了 `| wc -l` 的形式——命中数 0、**退出码也是 0**，「没扫」与「干净」完全同形。而本清单与日常复扫恰恰最常用后一种写法，所以仍须先证明工具扫得到目标：

```bash
test -f go.mod || { echo "FATAL: 不在 forge 仓根" >&2; exit 1; }
test -d sparklore-clients/internal || { echo "FATAL: clients 不在位（工作树常见），A-G 会全部 0 命中=假全绿" >&2; exit 1; }
test -d skills/sparklore-architecture-gates/rules || echo "WARN: skills 子模块未检出，规则条文读不到"
```

工作树里 clients 与 `skills/` 通常都没有；审计请在主检出跑，或先把两者补齐。

**另有机器闸兜底：** forge `scripts/hooks/bash-guard.py`（`PreToolUse`）会直接拦住「用相对 `sparklore-clients/` 路径扫描但当前检出没装 clients」的命令，以及 `go test -run` 不带 `-v`、`pkill`/`killall` 三类。装法见该目录 `README.md`。下面每个块首行的自检是给**没装闸的环境**（人在终端直接跑）兜底的。

## A. 声称已删的僵尸文件 / 依赖

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 点名文件应不存在
for f in sqlite.go sqlite_cms.go editor_ops.go compile_fallback.go syncer.go; do
  find sparklore-clients -name "$f" -not -path '*/bin/*' -not -path '*/node_modules/*'
done

# go.mod 不应再有 modernc/sqlite（业务存储）
rg -n 'modernc|sqlite' go.mod sparklore-clients/go.mod || true
```

## B. 数据驱动 / 硬编码

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 业务专用路由（扩写即违规；台账已有的标已知债）
rg -n '"/api/(studio|space|living|ideas|admin/foundry)[^"]*"' \
  sparklore-clients/internal --glob '!*_test.go'

# Go 内硬编码 LLM system prompt（业务中文/英文长句）
rg -n --glob '!*_test.go' \
  -e 'sysPrompt\s*:=' -e 'SystemPrompt:' -e '你是一' -e 'You are a strict' \
  sparklore-clients/internal cmd

# freeze 冻结段是否被加行（对比清理基线）
rg -n 'server-file admin_foundry|冻结' sparklore-clients/internal/server/freeze.txt
```

两问人工复核：删该应用是否要改 Go？新应用是否要加 Go？

## C. 静默编排

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 前端串流程 / 轮询
rg -n -e 'postMessage\(' -e 'setInterval\(' \
  sparklore-clients/extensions sparklore-clients/assets \
  --glob '!*.min.js' --glob '!**/living/**'

# 自重排的轮询链：核心定时器常是 setTimeout 自己重排，上面那条 setInterval 抓不到
rg -n -e 'function [a-zA-Z]*([Pp]oll|[Ss]chedule)' -e 'pollTimer|pollInFlight|schedule[A-Z][a-zA-Z]*\(' \
  sparklore-clients/extensions --glob '!*.min.js'

# 静默改写 / 假成功
rg -n --glob '!*_test.go' \
  -e 'normalizeSynth|ensurePrivatePrefix|compile_fallback|规则兜底' \
  sparklore-clients

# 写失败吞掉
rg -n --glob '!*_test.go' -e 'for attempt := 0' -A6 sparklore-clients/internal/quest
```

## D. 双轨 / graph 残留

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 合集 JSON 不应再有 graph 键（生产数据）
python3 - <<'E'
import json,glob,sys
root='sparklore-clients/extensions'
hits=[]
for f in glob.glob(root+'/**/*.json', recursive=True):
  try: d=json.load(open(f))
  except Exception: continue
  def walk(o):
    if isinstance(o,dict):
      if 'graph' in o and isinstance(o['graph'],(dict,list)): hits.append(f)
      for v in o.values(): walk(v)
    elif isinstance(o,list):
      for v in o: walk(v)
  walk(d)
print('graph keys:', len(set(hits)) or 0)
for h in sorted(set(hits))[:20]: print(h)
E

# 代码侧仍接受 graph 的编译入口
rg -n 'CompileVisualGraph|CompileWorkflow\(|json:"graph' \
  genspec sparklore-clients/internal/extension --glob '!*_test.go'
```

## E. 死路由 / UI 假能力

**E1. 差集**——只说明「少了什么」，不支持「删掉即可」：

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
rg -o -e '/api/admin/foundry/[a-z-]+' sparklore-clients/extensions --glob '*.js' | sort -u
rg -n 'Path:.*foundry' sparklore-clients/internal/server --glob '!*_test.go'
```

**E2. 对 E1 每个差集命中反向走链**，走完才能填「建议」列（流程见 SKILL.md「反向走链」）：

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# ① 找调用点
rg -n '<差集里的路由名>' sparklore-clients/extensions --glob '*.js'
# ② 从调用点所在函数回溯到可见入口（按钮 id、addEventListener），读它真正 POST 的 URL
#    —— 很可能是另一条还活着的路由
# ③ 读那条活路由的后端 handler：现在还起 run / 写库 / 发事件吗
# ④ 按 G 段核两端字段是否同形
```

没走完 ②③ 的，这条只能标 `G3`，建议栏写「待核验」。

## F. 门禁（可选实跑）

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 必须带 -v：-run 打不中任何测试时 Go 输出 `ok ... [no tests to run]` 并**退出 0**，
# 与真绿只差方括号里那句话。结论只认下面 grep 出来的 `--- PASS: <真实函数名>` 行。
go test ./internal/depscheck/ -run TestUsecaseCodeDoesNotGrow -count=1 -v | grep -E '^(--- PASS|--- FAIL|ok|FAIL)'
cd sparklore-clients && go test ./internal/server/ -run TestUsecaseCodeDoesNotGrow -count=1 -v | grep -E '^(--- PASS|--- FAIL|ok|FAIL)'
```

门禁绿 ≠ 内容合规。大文件内容仍须按两问审。**没看到 `--- PASS: <函数名>` 就不算跑过**——只有 `ok` 一行可能是「no tests to run」。

## G. 响应契约错配（路由在，字段不在）

路由存在**不等于**契约同形。A–F 只扫路由与文件名，字段级错配对它们天然不可见，必须人工比两端：

```bash
test -d sparklore-clients/internal || echo "⚠️ FATAL: clients 不在位，下面每一条 0 命中都是假的" >&2
# 前端读的响应字段
rg -n -o 'res\.[a-z_]+' sparklore-clients/extensions/<app>/app.js | sort -u
# 后端该 handler 实际返回的键
rg -n 'jsonOK\(w, map\[string\]any\{' -A25 sparklore-clients/internal/server/<handler>.go
```

反例：前端按 `res.ai_mode === 'async_running' && res.enrich_job` 走异步分支，后端只返回 `enrich_run_id`、从不返回 `enrich_job`——异步分支**永远进不去**，而路由差集一个字都看不见这件事。
