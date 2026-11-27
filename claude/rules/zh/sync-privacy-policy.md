# 数据驱动同步策略与两层隐私门控（中文参考）

> **非执行正文。** 活镜像只加载英文版 `../sync-privacy-policy.md`。

本规则对 `sparklore-forge` 与 `sparklore-clients` 中所有同步、存储、隐私、记忆/图谱及出站 LLM/工具调用改动强制生效。

## 规则 1 — 数据驱动 `UserSyncPolicy`（零领域硬编码）

1. `UserSyncPolicy`（`ud/privacy`）必须保持 100% 领域无关，严禁在 Go/JS 中硬编码任何业务垂类或场景词，严格按三级通用结构控制：
   - 总开关（`auto_sync_enabled`）；
   - 分类开关（`agent_chat`、`preferences`、`workspace_records`）及从已装 bundle 动态发现的 `excluded_bundles`（`SyncCatalogIndex`）；
   - 临时/无痕不落盘控制（`ephemeral_bundles` 与会话级 `X-Sparklore-Private: 1` / `ephemeral` 开关）。
2. `ud_sync` 中的 `config/<user>/sync_policy` 是跨设备同步策略记录（豁免于排除列表以保证多端一致），并在 `ud_local`（`config/sync_policy/<seg>`）存一份首轮同步前的本机引导快照。

## 规则 2 — 两层隐私门控（同步排除 + 零落盘）

1. **第一层（同步边界 — `PolicyFilter` 与云端 Purge）**：
   - 被 `UserSyncPolicy` 排斥的键（`PolicyLocalOnly`）必须在推拉两端对称过滤（`ud/sync` `PolicyFilter`），严禁写入 `SK_UD_REV`。
   - 将已同步分类或 bundle 改为排除后，必须立即停止后续推送，并提供显式本机保留式云端清理（`POST /api/sync/purge` → `PurgeKeysDoc` 向 `SK_UD_REV` 追加 `Op: "delete"` + `DetachCloud` 清零 `Base`/`Dirty`/`Upstream*` 并保留本机 `Current`）。
2. **第二层（存储与记忆边界 — `ZeroPersist` 与 `sensitive`）**：
   - 标记为 `ephemeral` 的会话/bundle 或带 `persist: false`（`ZeroPersist`）的数据仅允许驻留 RAM `VolatileOverlay`，在登出、会话过期或租户驱逐时必须清零擦除（根桶 `ud_local` 中的 `webSessionStore` 保持完整），且绝不允许写入 `ud_sync`、`ud_local`、`SK_UD_REV`、CME（`LocalCME`、`appendWorkingMemory`、`EpisodicWorker`、`EpisodicConsumer`、`Assembler`）或知识图谱（`GraphExtractWorker`、`cme_graph_triple`）。
   - 标 `sensitive: true` 的记录必须留在 `ud_local`（`sensitive/record/<id>`）；`sensitive_fields`（或 `IsLocalField`）指定字段在写入 `ud_sync` 前必须拆入 `ud_local`（`local/<key>`）。

## 规则 3 — Fail-Closed 出站云端 PII 脱敏

1. 所有出站 Cloud LLM、嵌入、媒体生成与网页搜索请求必须按 `SyncRedactionPolicy` 通过 `privacy.Redactor`（`mask` 或 `block`）。
2. 无效脱敏正则（`400 INVALID_REDACTION_PATTERN`）与 `block` 命中（`422 REDACTION_BLOCKED`）必须 fail-closed 拒发，严禁静默回退到备用提供商。
3. 仅合法回环本地侧车地址（`privacy.IsLoopbackURL(targetURL)`）允许旁路脱敏。
4. 出站脱敏绝不允许改写本机已落盘或内存原文记录（`ud_sync`、`ud_local`、`VolatileOverlay`）。

## 规则 4 — `orbthread/*` 单一真相持久化

法球 Agent 对话线程（`orbthread/<scope>`）单一归属 `ud_sync`（经 `KindBridge` + 领域无关 `orbThreadMergeResolver`），从 `ud_local` 做一次性无损迁移，并严格服从 `agent_chat`、`excluded_bundles` 与 `ZeroPersist`（`VolatileOverlay`）。严禁永久双写 `ud_sync` 与 `ud_local`。
