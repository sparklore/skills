# Go Patterns Mistakes（现网）

## 共享模块放错仓

**Wrong:** 在 clients 复制 forge 已有共享逻辑。  
**Right:** 共享只在 forge 一份（`ud/`、`widgetdsl/`、`genspec/`、`genloop/`…）；clients 用模块依赖。

## 进程连错依赖

**Wrong:** bff/bridge 连 PG；clients 直连云端 NATS/PG；agent 挂可写 PG 图存储。  
**Right:** 以 `docs/03` 表为准；`depscheck` 测试是门禁。

## Subject 常量

**Wrong:** 内联硬编码 NATS subject，或到已删除的 `sparklore/pkg/subjects`。  
**Right:** 平台用 `internal/contract/subjects.go`。

## 静默成功

**Wrong:** `SyncStore == nil` 或写失败却 `return nil` 对外成功。  
**Right:** 失败必须可见；CAS 重试有界且最终返回 error。
