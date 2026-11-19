# 数据驱动（Zero Use-Case Hardcoding）

完整条文见 `docs/02-rules-data-driven.md` 与 `AGENTS.md` §5。本文件只写 **Agent 动手闸**。

## 两问（都答「是」才算合格）

1. 删掉某个应用（合集 JSON），Go / JS **一行都不用改**？
2. 新增一个应用，Go / JS **一行都不用加、不用重新编译**？

任一为「否」→ 停手，先警告用户，再给数据驱动替代方案。**禁止静默照写。**

## 必须是数据（合集 / QuestFlow / Record / WidgetDSL body）

- 业务工作流步骤、提示词、输出 Schema、写回规则
- 页面布局、看板 / 矩阵 / 表单 / 列表、领域字段与枚举
- Foundry 导入 / 晋升 / 修复等**业务编排顺序**

## 允许留在 Go / JS（引擎）

- 通用状态机、校验器、`genloop` 结构化自愈（策略在公开契约）
- 通用 Record / Bridge / Quest 入口（非业务名）
- 设备 / 媒体 / OS 桥接 capability（相机、推流、云台等）
- 纯工具（骨架提取、X-Ray 诊断框架、沙盒文件）——**不含业务 prompt 与流程顺序**

## 一律禁止（无架构豁免）

- 新增业务 Go `capability`、`/api/<feature>/*`、`widgetdsl` 业务 `kind` / 结构体
- 在 Go/JS 硬编码业务中文/英文 **system prompt**、领域评分公式、术语黑名单当产品规则
- **搬家冒充合规**：把 `admin.go` 拆成 `admin_foundry.go` 仍保留业务状态机 / 专用路由
- **往 `freeze.txt` 冻结段加行**或给业务大文件加 `server-file` 白名单让测试变绿（冻结段只能删）
- 应用自带脚本写业务规则（换地方硬编码）

## 缺能力时的顺序（不可跳）

1. 改合集 / QuestFlow / Record 形状  
2. 加**第二个应用也能用**的通用构件（名字与字段无业务词）  
3. 触及事务 / 并发 / 写回 → 先写 `docs/design/` 短设计  

## 拦截话术（必须原样停）

> 该方案违反「Data-Driven Quest + Declarative WidgetDSL」铁律。应把流程放进 `extensions/*.json` 的 QuestFlow，数据走 `userdata.apply` / 通用 Record；Go 只留原子工具。需要架构豁免请明确说「豁免」并登记 `docs/04` 台账。

## 门禁（必要但不充分）

```bash
go test ./internal/depscheck/ -run TestUsecaseCodeDoesNotGrow -count=1
cd sparklore-clients && go test ./internal/server/ -run TestUsecaseCodeDoesNotGrow -count=1
```

只扫文件名 / 路由前缀，**不看文件内容**。内容审查仍按上面两问。
