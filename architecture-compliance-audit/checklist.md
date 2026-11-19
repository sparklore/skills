> 在 **sparklore-forge 仓根**执行（不是本 skills 子模块根）。

# 扫描清单（可复制命令）

在 forge 仓根执行。clients 路径：`sparklore-clients/`（子模块或并列）。

## A. 声称已删的僵尸文件 / 依赖

```bash
# 点名文件应不存在
for f in sqlite.go sqlite_cms.go editor_ops.go compile_fallback.go syncer.go; do
  find sparklore-clients -name "$f" -not -path '*/bin/*' -not -path '*/node_modules/*'
done

# go.mod 不应再有 modernc/sqlite（业务存储）
rg -n 'modernc|sqlite' go.mod sparklore-clients/go.mod || true
```

## B. 数据驱动 / 硬编码

```bash
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
# 前端串流程 / 轮询
rg -n -e 'postMessage\(' -e 'setInterval\(' \
  sparklore-clients/extensions sparklore-clients/assets \
  --glob '!*.min.js' --glob '!**/living/**'

# 静默改写 / 假成功
rg -n --glob '!*_test.go' \
  -e 'normalizeSynth|ensurePrivatePrefix|compile_fallback|规则兜底' \
  sparklore-clients

# 写失败吞掉
rg -n --glob '!*_test.go' -e 'for attempt := 0' -A6 sparklore-clients/internal/quest
```

## D. 双轨 / graph 残留

```bash
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

```bash
# 前端路径 − 后端路由 差集（人工核对）
rg -o -e '/api/admin/foundry/[a-z-]+' sparklore-clients/extensions --glob '*.js' | sort -u
rg -n 'Path:.*foundry' sparklore-clients/internal/server --glob '!*_test.go'
```

## F. 门禁（可选实跑）

```bash
go test ./internal/depscheck/ -run TestUsecaseCodeDoesNotGrow -count=1
cd sparklore-clients && go test ./internal/server/ -run TestUsecaseCodeDoesNotGrow -count=1
```

门禁绿 ≠ 内容合规。大文件内容仍须按两问审。
