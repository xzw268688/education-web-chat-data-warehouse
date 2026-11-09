# 教育机构官网流量与咨询转化数仓

本项目分析一家教育机构官网 2025 年 7 月的访问与咨询数据，构建 ODS / DWD / DWS 三层数据仓库，并向经营看板输出指标。

## Language

### 数据粒度

**访问会话（Visit Session）**：
访客在官网客服系统中的一次独立会话快照，对应 `web_chat_ems_2025_07` 的一行，由 `session_id` 与 `create_time` 共同标识；同一 `session_id` 在不同日期视为不同快照。
_Avoid_: 访问、浏览记录、订单

**访客（Visitor）**：
以 `sid` 去重的用户身份标识；同一访客可以产生多次访问会话。
_Avoid_: 用户、客户（单独使用）

**咨询会话（Consult Session）**：
用户至少发送过一条消息的访问会话，判定条件为 `msg_count > 0`。
_Avoid_: 咨询、聊天、对话（单独使用）

**咨询率（Consult Rate）**：
咨询会话数除以访问会话数，衡量访问转化为咨询的比例。
_Avoid_: 转化率（无修饰时）

### 转化与响应

**客服响应（Agent Response）**：
客服至少回复过一条消息的咨询会话，判定条件为 `reply_msg_count > 0`。
_Avoid_: 接待、回复率（单独使用）

**有效沟通（Effective Conversation）**：
用户消息数达到 9 条（咨询会话 `msg_count` 的 P75）、且客服已响应的咨询会话。
_Avoid_: 成交、成单

**转化漏斗（Conversion Funnel）**：
按“访问会话 → 咨询会话 → 客服响应 → 有效沟通”四段依次计数并计算转化率的分析结构。
_Avoid_: 漏斗图、转化路径

### 来源与地域

**来源渠道（Origin Channel）**：
会话进入官网的渠道分类，对应 `origin_channel` 字段。
_Avoid_: 渠道（单独使用）、来源（易与搜索来源混淆）

**搜索来源（SEO Source）**：
用户进入官网前使用的搜索引擎或入口，对应 `seo_source` 字段。
_Avoid_: 来源、渠道

**地区（Region）**：
会话归属的行政区划，依次由 `country` / `province` / `city` 三级字段描述。
_Avoid_: 地址、位置