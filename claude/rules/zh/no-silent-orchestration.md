# 禁止静默编排（No Silent Orchestration）（中文参考）

> **非执行正文。** 活镜像只加载英文版（SSoT：`sparklore-architecture-gates/rules/no-silent-orchestration.md`）。

「静默」= 没先对人说清，就把重试、串并行、提示词、失败兜底、旁路触发写进 Go/JS，或静默回退旧路径。与 `architecture` 的「禁静默回退」、`AGENTS.md` §5 零硬编码告警同族；本文件专打「编排写进代码」。

现网反例（效仿即违规）：`quest.go` 合成修复环、`gen.go` 旧生成管道、前端 `postMessage`/轮询串多条 `/api/quest/*`+`/api/admin/foundry/*`、`compile_fallback` 静默假成功、`follow.go` 旁路、`bundle_synth` 静默 `normalize*` 改写模型输出、CAS/写失败 `return nil` 对外成功。台账见 `docs/04` §4.1。

**搬家不算合规**：把业务编排从 `admin.go` 拆到 `admin_foundry.go` / `admin_quest_services.go` 仍是 Go 静默编排；正解是迁进 QuestFlow 后**删除** Go 编排。

## 动手前必须先回答（未答完禁止改代码）

用 3～6 行写在回复里，等人明确说「可以改」再动手：

1. **为什么改**：现在坏在哪（失败形态 / 谁受影响），不是「为了更好」。
2. **好处是什么**：可观察指标（成功率、可观测、可配置、少一条双轨）。
3. **为何不放进 QuestFlow / 合集数据**：若能放却放进 Go/JS，默认**否决**。
4. **失败时对外长什么样**：禁止「内部失败、对外成功」；观测 / X-Ray / 日志必须同真相。
5. **退场**：临时方案须台账条目 + 截止日期或触发条件（见 `architecture`）。

## 一律禁止（除非上一节过闸且用户明确同意）

- 引擎热路径私有 LLM 修复环、硬编码修复 prompt、专用 `if 某业务失败 then 重试`
- 静默确定性兜底（LLM 失败 → 模板假成功）而不显式失败
- 前端 `postMessage` / 轮询旁路串多条工作流（刷新即断的「假编排」）
- 为业务场景新增 `/api/<feature>/*` 或业务 capability（见 `data-driven` / AGENTS.md §5）
- 双写、双真相、静默回退旧管道（见 `no-zombie-dual-track`）
- 存储/引擎未就绪时返回空成功（`SyncStore == nil` → 丢日志当 OK）

## 允许（仍须第 1 节披露）

- 通用、与业务无关的校验器 / `genloop` 结构化自愈（次数与策略在公开契约里）
- 纯工具能力（骨架提取、X-Ray、沙盒文件），不含业务提示词与流程顺序
- 把既有静默逻辑**迁出** Go/JS、迁进 QuestFlow 的删除式改动
- 乐观锁 CAS 重试：次数有界且**最终失败必须返回 error**

## 反例 → 正解

`quest.go` 合成失败后硬拼 `"Fix validation errors: ..."` 私自再调 LLM → 违规。  
应：QuestFlow `repeat`/`branch`，或显式失败把错误交给调用方。

前端 `start → poll run → stage → install` 用 `postMessage`/定时器串起 → 违规。  
应：单一 QuestFlow（含 `subquest`/`parallel`），页面只触发一次并订阅状态。
