# Frontend Mistakes（现网 clients）

> 主路径：`sparklore-clients/assets`（hydrate / orb）、合集 `extensions/*.json` WidgetDSL。  
> 营销站 `sites/company` 的 templ 是旁路，不是产品主客户端。

## 页面硬编码业务 API

**Wrong:** 页面直调已删或业务专用 `/api/<feature>/*`；或用 `postMessage`/轮询串多条工作流。  
**Right:** 通用 Record / Quest 入口；单一 QuestFlow；订阅状态。

## 伪造数据撑 UI

**Wrong:** 空列表时编造名称、价格、订单。  
**Right:** 空数组 / `null`（`no-fake-data`）。

## 绕过设计令牌

**Wrong:** 页面写死色值。  
**Right:** 用设计令牌；缺则先加令牌（`frontend` / `ui-designer`）。

## 卸载不清理

**Wrong:** 定时器 / 订阅 / 进行中请求在卸载后仍跑。  
**Right:** 卸载时清理。
