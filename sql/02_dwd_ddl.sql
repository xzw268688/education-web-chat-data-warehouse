-- DWD 层：5 张维表 + 2 张事实表，全部 ORC + dt 日分区
CREATE DATABASE IF NOT EXISTS edu_dwd;

-- 日期维度
DROP TABLE IF EXISTS edu_dwd.dim_date;
CREATE TABLE edu_dwd.dim_date (
  date_key INT COMMENT '日期键 yyyyMMdd',
  year INT COMMENT '年',
  month INT COMMENT '月',
  day INT COMMENT '日',
  weekday INT COMMENT '星期 1-7',
  is_weekend INT COMMENT '是否周末 1/0'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 地区维度
DROP TABLE IF EXISTS edu_dwd.dim_region;
CREATE TABLE edu_dwd.dim_region (
  region_key STRING COMMENT '地区代理键',
  country STRING COMMENT '国家',
  province STRING COMMENT '省级行政区',
  city STRING COMMENT '城市'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 渠道维度
DROP TABLE IF EXISTS edu_dwd.dim_channel;
CREATE TABLE edu_dwd.dim_channel (
  channel_key STRING COMMENT '渠道代理键',
  origin_channel STRING COMMENT '来源渠道',
  seo_source STRING COMMENT '搜索来源'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 页面维度
DROP TABLE IF EXISTS edu_dwd.dim_page;
CREATE TABLE edu_dwd.dim_page (
  page_key STRING COMMENT '页面代理键',
  url_title STRING COMMENT '页面标题',
  from_url STRING COMMENT '会话来源页面',
  landing_page_url STRING COMMENT '着陆页面'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 设备维度
DROP TABLE IF EXISTS edu_dwd.dim_device;
CREATE TABLE edu_dwd.dim_device (
  device_key STRING COMMENT '设备代理键',
  os_info STRING COMMENT '操作系统',
  browser_name STRING COMMENT '浏览器'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 访问会话事实表
DROP TABLE IF EXISTS edu_dwd.fact_visit;
CREATE TABLE edu_dwd.fact_visit (
  session_id STRING COMMENT '会话唯一标识',
  sid STRING COMMENT '访客唯一标识',
  date_key INT COMMENT '日期键',
  region_key STRING COMMENT '地区维度键',
  channel_key STRING COMMENT '渠道维度键',
  page_key STRING COMMENT '页面维度键',
  device_key STRING COMMENT '设备维度键',
  ip STRING COMMENT '访客 IP',
  create_time TIMESTAMP COMMENT '会话创建时间',
  msg_count INT COMMENT '用户消息数',
  reply_msg_count INT COMMENT '客服回复数',
  is_consult INT COMMENT '是否咨询 1/0'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

-- 咨询事实表
DROP TABLE IF EXISTS edu_dwd.fact_consult;
CREATE TABLE edu_dwd.fact_consult (
  session_id STRING COMMENT '咨询会话标识',
  sid STRING COMMENT '访客唯一标识',
  date_key INT COMMENT '日期键',
  region_key STRING COMMENT '地区维度键',
  channel_key STRING COMMENT '渠道维度键',
  device_key STRING COMMENT '设备维度键',
  msg_count INT COMMENT '用户消息数',
  reply_msg_count INT COMMENT '客服回复数',
  is_agent_reply INT COMMENT '客服是否响应 1/0',
  is_high_intent INT COMMENT '是否高意向 1/0',
  is_effective INT COMMENT '是否有效沟通 1/0'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;