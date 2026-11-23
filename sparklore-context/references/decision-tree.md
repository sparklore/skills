# Architecture Decision Tree（现网）

权威细则：`AGENTS.md` §5、`docs/02`、`docs/03`、四闸 skills。本页只做分流。

## 1. 代码放哪？

```
业务工作流 / 提示词 / 看板矩阵表单 / 领域字段？
  └─ YES → 合集 JSON / QuestFlow / Record / WidgetDSL body
       └─ 禁止：业务 Go capability、/api/<feature>/*、widgetdsl 业务 kind

通用引擎能力（状态机、校验、genloop、Record/Bridge/Quest 入口）？
  └─ forge 对应模块；名字与字段无业务词

设备 / 媒体 / OS 桥接（相机、推流、云台）？
  └─ clients capability（仅底层原生）

平台 HTTP / 事件翻译？
  └─ forge：quest / bff / bridge（bridge 可有 HTTP 门面，无 PG、无业务编排）

本机用户端页面 / 本地 KV / 本机 Quest？
  └─ sparklore-clients（hydrate / orb / extensions）
```

## 2. 数据怎么存？

```
同步类用户数据？ → ud_sync（经 bridge HTTP 版本线）
本机类？         → ud_local
平台工作流真相？ → forge PG（QuestRun 等）
缓存 / 内嵌 NATS？→ 投影或本机存储，不是跨设备唯一真相
```

## 3. 改前过哪道闸？

```
新增业务 capability / 专用路由 / widgetdsl 业务 kind？
  └─ 停手 → data-driven 拦截话术 → 数据驱动替代方案

要在 Go/JS 加重试、串并行、prompt、兜底、旁路？
  └─ 先答 no-silent-orchestration 五问 → 等人说「可以改」

删旧实现 / 疑似双轨（graph+flow、测产脱节、搬家）？
  └─ no-zombie-dual-track 三问 → 定 SSoT 再删

写审计 / 台账？
  └─ audit-evidence：每条 G1/G2/G3；G3 不带波次
```

## 4. 怎么探路？

```
1. graphify query "<问题>"
2. 需要关系 → graphify path / explain
3. 再读定位到的文件；禁止先全仓瞎扫
4. 无 GitNexus
```
