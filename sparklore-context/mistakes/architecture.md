# Architecture Mistakes（现网）

> 条文 SSoT：`docs/02`、`AGENTS.md` §5、四闸。此处只记高频近失。

## 业务硬编码

**Wrong:** 为 Ideas/Studio 等加 Go `capability`、`/api/ideas/*`、`widgetdsl` 业务 `kind`。  
**Right:** QuestFlow + `userdata.apply` / Record + WidgetDSL body；Go 只留通用原子工具。

## 搬家冒充迁出

**Wrong:** 把 `admin.go` 拆成 `admin_foundry.go` 仍保留业务状态机。  
**Right:** 流程进合集 QuestFlow 后**删除** Go 编排。

## 双真相

**Wrong:** `graph` 与 `flow` 双写；生产传 `nil` 旧实现、测试续命。  
**Right:** 单 SSoT；测产同构；删旧不搬家。

## 假 SSoT

**Wrong:** 用过期 skill / 旧 `docs/0xx` 覆盖 `AGENTS.md`。  
**Right:** 规则优先级见 `AGENTS.md` §3；旧编号文档已删除（`docs/README.md` §3）。
