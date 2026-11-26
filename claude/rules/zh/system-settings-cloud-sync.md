# 所有系统设置必须经 Forge SSoT 云端同步（中文参考）

> **非执行正文。** 活镜像只加载英文版 `../system-settings-cloud-sync.md`。

本规则对 `sparklore-forge` 与 `sparklore-clients` 中所有系统级或 Admin 配置改动强制生效。

## 规则 1 — 所有系统 / Admin 设置单一云端 SSoT

1. 每一项系统级或 Admin 配置都必须持久化到 Forge PostgreSQL 唯一真相源（`platform_system_models` / `platform_settings`，经 `/v1/me/admin/*` 读写），并在所有已连接宿主（Desktop 与 Web Server）上自动水合：
   - LLM 提供商与 System Model 配置档案（profiles）；
   - 全部 9 个认知与多模态槽位（`decision`、`fast`、`deep`、`embedding`、`image`、`video`、`tts`、`stt`、`music`），包含 `voice` 与 `protocol`；
   - 全局 Web Search 配置（`web_search`：Tavily API Key 与 SearXNG URL）；
   - 平台运行时设置、角色、点数定价与已发布合集目录。
2. 在 `sparklore-clients` 中将新的 Admin 或系统设置做成仅本机存储（`ud_local` / `system-models.json`），而未同步补齐 Forge PG Schema/字段、`/v1/me/admin/*` 路由/字段、BFF 代理透传与双向水合，属于 **P0 架构违规**。

## 规则 2 — 封闭的本机豁免清单

1. **仅有**与宿主硬件或操作系统绑定的偏好项允许留在单机本地（`ud_local` 或 `~/.sparklore/runtimes/prefs.json`）：
   - 本地引擎生命周期与硬件开关（`local-voice`、`local-embed`、`local-computer-use` 的自启动、无头模式、本地路由）；
   - 本地文件路径；
   - 设备身份标识（`device.id`）；
   - 本地媒体录制文件。
2. 该豁免清单为**封闭清单**；清单之外的任何系统/Admin 设置均不得留作仅本机存储（除非获得明确架构豁免）。
3. 任何豁免的本机设置都必须在 UI 中明确标注 `"This device only"`。

## 规则 3 — 禁止静默吞掉云同步失败

1. `sparklore-clients` 中每一个系统设置保存接口都必须诚实返回 `forge_synced`（bool）与 `forge_sync_error`（string）。
2. Admin UI 在 `forge_synced === false` 时必须醒目且持久地展示同步失败及原因（`forge_sync_error`）；严禁在云端同步失败时仅弹出 `"Saved"` 提示。

## 规则 4 — 密钥卫生与受控运行时水合

1. 严禁在公开/成员端点（`GET /v1/me/system-models`）、`ud_sync`、默认 `GET /v1/me/admin/system-models` 或 `sparklore-clients` 任何面向浏览器的 `/api/*` 响应中暴露明文 API Key（始终返回 `.Sanitized()` 与脱敏状态投影）。
2. 受控服务端运行时密钥水合（`GET /v1/me/admin/system-models?include_secrets=1`）严格限定于已验证的 Admin 或服务鉴权调用方（普通成员令牌必须返回 `403`）。
3. 水合后的密钥仅允许留在服务端内存或 `ud_local` 中，不得回显到浏览器响应，也不得写入 `ud_sync`。

## 规则 5 — 跨仓部署一致性

任何新增或扩展 Forge `/v1/me/*` 路由或字段的 PR / 波次都必须核验 Forge 部署一致性，严禁让 `sparklore-clients` 静默调用尚未部署的 Forge 路由或字段。
