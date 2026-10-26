# Java 自研 MCP 网关技术方案 —— 评审意见

> 评审对象：`Java自研MCP网关技术方案 (2).md`（v1）
>
> **状态：评审意见已全部落地。** 原文件已原地改写为 v2（`~/Downloads/Java自研MCP网关技术方案 (2).md`），表名统一改为 `mcp_*`。本文保留作为问题背景与决策依据，具体以 v2 文档为准（v2 第 0 节有完整的修订对照表）。
>
> **后续三项调整（以 v2 为准，本文 1.1 节的实例表建议已被取代）**：
> 1. 不开 `mcp_service_instance` 表——对标 Higress 一层模型，多实例地址下沉为 `mcp_service.endpoints` JSON 列（v2 §2.0 有三方案对比）；
> 2. 限流改为**集群限流**，Redis 为唯一事实源，禁止单机计数（v2 §7.2）；
> 3. 长会话场景定为 **Redis 会话外置**（+ EventStore 断点续传），不采用会话亲和（v2 §1.2）。

> 结论：**整体结构成立**（Server→Tool 两层模型、三类链路分离、注册表驱动），可以按这个骨架做。
> 但有 **1 处设计自相矛盾、3 处会造成线上故障或越权的问题**，建议动手前先改掉。

---

## 0. 先回答：白名单与动态授权是干什么的

### 它解决什么问题

一个原生 MCP Server 接进网关后，它的 `tools/list` 会**原样枚举出全部工具**，网关默认全量代理。现实里这会带来两个麻烦：

1. 后端有些工具太危险（`deleteAll`、`refund`），**任何人都不该碰**；
2. 同一个后端要给不同人用，**每个人能用的工具不一样**（客服 vs 主管、免费版 vs 企业版）。

麻烦 1 是"跟后端绑定的、配死就行"，麻烦 2 是"跟调用者绑定的、每次请求都变"。方案于是拆成两层：

| 机制 | 谁来定 | 粒度 | 存在哪 / 怎么传 |
|---|---|---|---|
| 静态 `allow_tools` | 网关管理员 | 每个后端（Server） | 落在 `gw_service.allow_tools` 列 |
| 动态头 `x-allow-mcp-tools` | 前置鉴权插件（按用户角色/租户/套餐） | 每次请求 | 入站 HTTP 请求头，逗号分隔 |

**最终生效 = 静态白名单 ∩ 动态头。**

举例：订单 MCP 有 5 个工具
- 静态白名单配 `createOrder, cancelOrder, listOrders`（`refund`/`deleteAll` 永远不露）
- 某次请求动态头是 `createOrder, listOrders`（该用户是普通客服）
- → 这次 `tools/list` 只返回 `createOrder, listOrders`

好处：**一个后端接一次，多租户共享**，靠改头就能给不同角色看到不同工具集，不用为每个角色部署一套 MCP Server。这也是 Higress 的 `allowTools` + `x-envoy-allow-mcp-tools` 在做的事。

### ⚠️ 但这块有三个洞

**① `tools/call` 完全没校验（最严重）**
3.3 节只在 `listTools()` 里做了 `allowIntersect()` 过滤，`callTool()` 直接就 `resolver.resolve(toolName)` 转发了。
`tools/list` 过滤只是"让模型看不见"，**不是权限控制**。Agent 从历史上下文、提示注入、或者另一个权限更高的客户端那里知道了 `deleteAll` 这个名字，直接发 `tools/call {"name":"order.deleteAll"}` 就能打通。

修法：把交集校验抽成一个方法，在 list 和 call 两处都调用。

```java
public CallToolResult callTool(String toolName, Map<String,Object> args, Set<String> dynamicAllow) {
    Resolved rt = resolver.resolve(toolName);
    if (!allowIntersect(rt.service(), rt.rawTool(), dynamicAllow)) {
        return CallToolResult.builder().isError(true)
            .addTextContent("tool not allowed: " + toolName).build();  // 不要抛异常
    }
    return clientPool.getOrCreate(rt.service()).callTool(rt.rawTool(), args);
}
```

**② 动态头缺失 = 不限制，是 fail-open**
2.5 写"动态头不存在/空字符串=不额外限制"。这意味着前置鉴权插件一旦漏配、报错、或新接了个客户端忘了配，**权限全开**。安全上应该反过来：**没有这个头就按最低权限处理（全禁或走默认匿名角色）**，明确授权才放行。

**③ 匹配的是原始工具名还是带前缀名，文档没说清**
工具对外是 `{service}.{tool}`，`allow_tools` 里到底写 `deleteAll` 还是 `order.deleteAll`？`resolver.resolve()` 拆完之后必须用 **rawTool** 去匹配白名单。这个不写死，上线后一定有人配成前缀名导致白名单永久失配（失配结果按 ② 又是全开）。

另外两个小建议：
- `",,"` 表示全禁太隐晦，容易误配，建议改成显式的 `x-allow-mcp-tools: none`。
- 白名单的作用范围文档前后不一致：2.0/3.1 说只裁剪 `MCP_REMOTE`，第 6 节又说两类合并后一起裁剪。**建议统一作用于两类**（`OPENAPI_REST` 生成的静态工具同样危险）。

---

## 1. P0 — 必须改，否则出事故

### 1.1 `gw_service.name` 唯一约束 与 "多实例同名多行" 直接冲突

- 字段表写 `name`：服务/容器名，**唯一**，聚合后工具名是 `{name}.{tool}`；
- 建表语句 `UNIQUE KEY uk_name (name)`；
- 但 2.6 又写「**多实例：同名服务多行，按 `weight` 轮询**」；2.1 的 `weight` 字段也是"同名多实例权重"。

**同名多行插不进去**，而且就算能插，`{name}.{tool}` 前缀也会重复导致聚合工具名冲突。

修法（二选一）：
- **推荐**：拆出实例维度。`gw_service` 存逻辑服务（name 唯一），新增 `gw_service_instance`（service_id / base_url / weight / status / last_heartbeat）。心跳、权重、故障转移都在实例层，`name` 只做命名空间。
- 或者：多实例用 `name` 加后缀（`order-1`/`order-2`），工具前缀取逻辑名——但这会让路由 key 和命名空间耦合，后续改名很痛，不推荐。

### 1.2 默认"客户端凭证原样透传给后端"——混淆代理人风险

方案反复强调（2.1 注、F 节、7.1）「默认把客户端认证信息原样透传给后端，不设开关，后端信任网关侧已完成的入口校验」。这个假设不成立：

- 网关入口校验的是「**这个调用方是不是我的合法网关用户**」；
- 后端需要判断的是「**这个调用方有没有权限访问这个接口 / 这份数据**」。

把同一个 Key 透传给后端，等于**任何一个合法网关用户都自动获得后端全量权限**。这是典型的 confused deputy。而且后端收到的是网关用户的 Key，日志里根本分不清是谁，事后无法追溯。

更要命的是 REST_PROXY 里 `h.putAll(headers)` 是**所有头全透传**，`Authorization` 也在里面——如果后端用的是自己的 JWT，客户端拿一个针对网关的头就可能通过后端的校验。

建议改成：
1. **默认不透传**，默认用后端固定 Key（`upstream_scheme_id`）+ 网关自己签发的身份上下文头（如 `X-Gateway-Tenant` / `X-Gateway-User`，下游只信这个）；
2. 要透传必须**按工具显式开启**（加 `credential_passthrough` 开关），且限定只透传白名单内的头名，绝不放行 `Authorization`。

### 1.3 REST 透传代理的头处理（这段代码上线必出问题）

```java
h.putAll(headers);   // 客户端所有头原样透传
```

必须处理，否则：
- **`Host` 头**：没替换成后端 host，后端按虚拟主机路由会 404 或串到错误站点；
- **hop-by-hop 头**：`Connection` / `Keep-Alive` / `Transfer-Encoding` / `Upgrade` / `Proxy-*` 必须剔除；
- **`Content-Length`**：body 重组后长度可能变化，直接透传会让请求挂死或截断；
- **`Cookie`**：跨服务透传 Cookie 是会话固定风险；
- **`x-allow-mcp-tools`**：2.5 明确要求"处理完立即删除，不下发给后端"，但 proxy 面这段代码**没删**，客户端伪造这个头就能给自己授权。

最小修复：

```java
private static final Set<String> STRIP = Set.of(
    "host","connection","keep-alive","transfer-encoding","upgrade",
    "proxy-authenticate","proxy-authorization","content-length",
    "x-allow-mcp-tools","te","trailer","expect");

headers(h -> {
    headers.forEach((k,v) -> { if (!STRIP.contains(k.toLowerCase())) h.set(k, v); });
    h.set("Host", URI.create(svc.getBaseUrl()).getHost());
    h.set("X-Forwarded-For", clientIp);
    h.set("X-Forwarded-Proto", req.getScheme());
    applyUpstreamAuth(h, svc);
});
```

顺带：`uri(svc.getBaseUrl() + path + queryString(req))` 是字符串硬拼，path/query 没做编码，遇到空格、中文、多个 `?` 都会出错，用 `UriComponentsBuilder` 构造。

### 1.4 模板渲染没有转义 → URL 注入 / JSON 注入 / SSRF

`{{.args.x}}` 直接拼进 URL 和手写 body：

```json
"url": "https://api.example.com/products/{{.args.product_id}}",
"body": "{\"sku\": \"{{.args.sku}}\", \"qty\": {{.args.qty}}}"
```

- `product_id` 传 `../admin` 或 `x?a=1&b=2` → 路径穿越 / 参数注入；
- `sku` 里带一个双引号 → 拼出来的 body 不是合法 JSON，后端 400，或者更糟：能闭合字段注入额外键；
- url 整体由 args 控制时 → SSRF（Agent 被提示注入后让模型访问内网地址）。

必须做的三件事：
1. 提供并**强制**使用 `toJson`（JSON 转义）、`urlEncode`（query/path 编码）两个函数；path 占位替换默认做 URL 编码（除 `/` 外转义）；
2. `position: path/query` 的参数在渲染时自动编码，不让裸值进 URL；
3. 目标 host 做**出站白名单校验**（只允许 `gw_service.base_url` / `request_template.url` 里声明的 host），防 SSRF。

另外：必填参数缺失时模板会渲染出 `<no value>` 或空串，必须在渲染前按 `input_schema` 做校验（SDK 不会替你拒绝）。

---

## 2. P1 — 重要，影响可用性/正确性

### 2.1 MCP 会话是有状态的，"无状态 + HPA" 的假设不成立

第 1 节说"无状态，注册表在 DB"，但 6 节对外是 StreamableHTTP。官方 SDK 的 `HttpServletStreamableServerTransport` **按 session 保存 transport 实例**（内存 Map），`initialize` 握手后要靠 `Mcp-Session-Id` 找回会话。多副本 + 随机负载均衡 → 第二次请求落到另一个 Pod 就 404。

需要三选一：**会话亲和（sticky session）** / **session 状态外置到 Redis** / 走**无状态模式**（stateless，每次请求自带完整上下文，官方 SDK 支持）。方案里必须明确选哪个，否则 M5 上线就炸。

### 2.2 `McpClientPool` 有几处会卡死/泄漏

```java
return pool.computeIfAbsent(svc.getName(), k -> { ...initialize(); });
```

- **`computeIfAbsent` 里做阻塞网络调用**：`initialize()` 可能耗时几秒，期间该 bin 被锁，其他服务的 `getOrCreate` 全被阻塞；
- **初始化失败不放进池，也没有重试/熔断**：一次网络抖动后，这个服务会**每次请求都重试 initialize**，雪崩；
- **`evict()` 只在注销时调**：后端挂了、连接半开，池里那条死连接不会被换掉；
- **`timeout_ms`(默认 5s) 也被用作 `initialize` 的超时**：和 2.1 里"初始化/探测不计入此值"的描述矛盾，慢后端会连不上；
- **没提线程模型**：`McpSyncClient` 是同步阻塞调用，容器线程会被后端拖住，需要单独线程池/虚拟线程 + 舱壁隔离，否则 MCP 面把 REST 面的线程吃光。

建议：`ConcurrentHashMap<String, CompletableFuture<McpSyncClient>>` + 单飞，失败走指数退避与熔断，后台健康检查定期 `ping`/`tools/list` 探活，失效主动 `evict` 重建。

### 2.3 `tools/list` 每次都实时拉后端，且串行阻塞

3.3 的 `listTools()` 对每个 ONLINE 的 MCP_REMOTE 都 `getOrCreate().listTools()`。N 个后端串行 RPC，**`tools/list` 是每次会话都会频繁调用的热路径**，延迟直接叠加到模型首 token。

建议：后端工具列表缓存（Caffeine，TTL 30~60s + 变更时主动失效），并在 Server 侧声明 `capabilities.tools.listChanged = true`，后端工具变化时发 `notifications/tools/list_changed` 主动推送失效。

顺带：方案完全没提 `initialize` 的能力协商、`prompts`/`resources`（至少明确返回空列表而不是报错）、cancellation、progress。补齐协议握手部分。

### 2.4 OpenAPI 转换的几个真实陷阱

- **`operationId` 缺失或重复**：很多 Spring 项目生成的 spec 没有 operationId，或者重复，工具名会冲突。需要 fallback（`method + path` 规范化）和冲突检测。
- **工具数量爆炸**：一个 spec 几百个 operation 全转成工具 → 工具列表塞爆上下文，模型选不准工具（这是 REST→MCP 最常见的失败模式）。建议**默认按 tag 白名单裁剪**，单服务工具数设上限（比如 ≤ 30），超出的走人工挑选。
- **spec 刷新会冲掉人工修补**：运营在后台手工改过某个工具的 `request_template`（2.4 也承认 parser 只做 80%），下次自动刷新 spec 就被覆盖。需要"人工覆写锁定"标记（`manual_override` 字段），刷新时跳过。
- **`description` 用 `op.getSummary()`**：summary 常常为空或一句话带过。而 description 是**给模型看的、决定它选不选对工具**，应回退到 `description` + 参数说明拼接。

### 2.5 `config_json` 存 apiKey 与自身定义矛盾

2.1 说 `config_json` 存"**非凭证**配置（不是密钥）"，但 2.4-B 的示例就是 `{"key":"X-API-Key","value":"{{.config.apiKey}}"}`，2.4-G 也是。这就是凭证，而且 `config_json` 没说要加密。

建议：要么把 apiKey 统一挪进 `gw_auth_scheme`（那里说了加密），`config_json` 严格只放非敏感业务参数；要么 `config_json` 同等级加密 + 管理接口返回时脱敏。**别让密钥躺在明文 JSON 列里**。

### 2.6 限流与一致性细节

- 限流写"Redis 或 Caffeine 计数器"——多实例下 Caffeine 无效，直接定 Redis（Lua 令牌桶）。
- `default_credential` 说了加密存储，但没说密钥从哪来（KMS / 环境变量），也没提日志脱敏、管理接口的导出防泄露。
- 缓存刷新用 `updated_at` 增量拉取，但**物理删除感知不到**（2.6 提到注册/注销事件主动失效，但跨副本广播没做）。建议统一用**软删除**（`deleted` 标记）+ 版本号，或引入 DB binlog/CDC 或简单广播。
- "删除 `gw_auth_scheme` 前代码检查引用"存在并发 TOCTOU，建议**禁止物理删除**，只做软删/停用。

---

## 3. P2 — 建议补上

1. **审计日志**：MCP 网关最需要的是"谁在什么时候用哪个工具传了什么参数、拿到什么结果"，7.3 只写了 metrics 和结构化日志，建议单独落一张 `gw_call_log`（含 tenant/user/tool/args 摘要/耗时/结果码），合规和排查都靠它。
2. **`config_json` / 模板的版本与灰度**：工具定义变更目前直接生效，建议加版本号 + 灰度（按租户/百分比），不然改错一个 description 全量用户一起炸。
3. **REST_PROXY 与流式**：代码是 `byte[]` 全量读进内存，与 5 节"流式/SSE 用 WebClient 分块"矛盾。大文件/长连接场景要单独走 WebClient 流式，并设响应体大小上限。
4. **超时/重试/幂等**：7.2 提到"重试（仅幂等 GET）"，但没有幂等键、没有重试次数上限与 jitter，容易把后端的抖动放大成雪崩。
5. **依赖版本**：`swagger-parser-v3` 2.1.29 建议确认与 Spring Boot 3.x 的 Jackson 版本兼容（该库传递依赖较旧，常见 `NoSuchMethodError`），必要时 exclude 后统一 Jackson BOM。
6. **MCP SDK 的 API 细节**：3.2 里 `new SseClientTransport(new HttpClientTransport(...))` 这个写法与官方 SDK 实际 API 不符，SSE 客户端应用 `SseClientTransport.builder(baseUrl).build()`。编码时以当前 SDK 版本的 javadoc 为准。

---

## 4. 修改清单（按里程碑插入）

| 里程碑 | 需要补进去的修改 |
|---|---|
| M1 骨架 | 1.1 拆实例表；2.6 软删除 + 版本化缓存 |
| M2 链路一 | 0-① `tools/call` 同样校验交集；2.1 会话方案定稿；2.2 连接池单飞/熔断/探活；2.3 工具列表缓存 + listChanged |
| M3 链路二 | 1.4 模板转义 + SSRF 出站白名单 + 入参校验；2.4 OpenAPI 陷阱四条；2.5 config_json 不放密钥 |
| M4 链路三 | 1.3 头剥离 + Host/XFF + UriComponentsBuilder + 删掉 `x-allow-mcp-tools` |
| M5 治理 | 1.2 改为默认不透传 / 显式开关；0-② 动态头缺失按 fail-closed；限流定 Redis；补审计日志 |

---

## 5. 一句话总结

骨架和分层是对的，主要风险集中在三处：**`tools/call` 没做权限校验**（等于白名单只做了 UI 隐藏）、**客户端凭证默认全透传**（越权）、**REST 代理头不处理 + 服务名唯一与多实例自相矛盾**（线上故障）。这三块改完，其余都是工程量问题。
