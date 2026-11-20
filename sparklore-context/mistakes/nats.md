# NATS / 同步 Mistakes（现网）

## 搞混本机与云端

**Wrong:** 假设 clients 进程订云端 NATS 做同步。  
**Right:** clients 内嵌本机 NATS；云端同步走 bridge HTTP `ud.rev`（`docs/03` §1、§3）。

## 页面碰 NATS

**Wrong:** 浏览器直连 NATS。  
**Right:** 页面只打本机 HTTP；SSE 由本机服务推。

## Bridge 职责

**Wrong:** 在 bridge 写业务编排、连 PG、或「bridge 禁止一切 HTTP」。  
**Right:** bridge 可做 HTTP 门面（SSE、`/v1/me/rev/*`）；禁止业务逻辑与 PG。领域→`ui.event.*` 翻译表在 `internal/bridge/`。

## Outbox

**Wrong:** 工作流关键事件先发 NATS 再提交、或塞进易失通道当唯一投递。  
**Right:** quest 侧与业务同事务写 `outbox_events` 再 Relay（见 `docs/03`）。
