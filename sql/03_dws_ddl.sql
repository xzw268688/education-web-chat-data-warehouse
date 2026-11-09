-- DWS 层：5 张场景聚合表，全部 ORC + dt 日分区
CREATE DATABASE IF NOT EXISTS edu_dws;

DROP TABLE IF EXISTS edu_dws.dws_visit_daily_agg;
CREATE TABLE edu_dws.dws_visit_daily_agg (
  session_cnt BIGINT COMMENT '会话总量',
  uv_cnt BIGINT COMMENT '独立访客数',
  visit_ip_cnt BIGINT COMMENT '访问 IP 数',
  consult_session_cnt BIGINT COMMENT '咨询会话数',
  consult_user_cnt BIGINT COMMENT '咨询用户数',
  consult_ip_cnt BIGINT COMMENT '咨询 IP 数',
  session_consult_rate DECIMAL(10,4) COMMENT '会话咨询率',
  user_consult_rate DECIMAL(10,4) COMMENT '用户咨询率',
  ip_consult_rate DECIMAL(10,4) COMMENT 'IP 咨询率',
  high_intent_cnt BIGINT COMMENT '高意向会话数',
  agent_reply_cnt BIGINT COMMENT '客服响应会话数',
  agent_reply_rate DECIMAL(10,4) COMMENT '客服响应率',
  funnel_visit_cnt BIGINT COMMENT '漏斗-访问',
  funnel_consult_cnt BIGINT COMMENT '漏斗-咨询',
  funnel_reply_cnt BIGINT COMMENT '漏斗-响应',
  funnel_effective_cnt BIGINT COMMENT '漏斗-有效沟通',
  funnel_consult_rate DECIMAL(10,4) COMMENT '访问到咨询转化率',
  funnel_reply_rate DECIMAL(10,4) COMMENT '咨询到响应转化率',
  funnel_effective_rate DECIMAL(10,4) COMMENT '响应到有效沟通转化率'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

DROP TABLE IF EXISTS edu_dws.dws_visit_region_agg;
CREATE TABLE edu_dws.dws_visit_region_agg (
  country STRING COMMENT '国家',
  province STRING COMMENT '省级行政区',
  city STRING COMMENT '城市',
  session_cnt BIGINT COMMENT '访问会话数',
  uv_cnt BIGINT COMMENT '独立访客数',
  consult_session_cnt BIGINT COMMENT '咨询会话数',
  consult_rate DECIMAL(10,4) COMMENT '会话咨询率'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

DROP TABLE IF EXISTS edu_dws.dws_visit_channel_agg;
CREATE TABLE edu_dws.dws_visit_channel_agg (
  origin_channel STRING COMMENT '来源渠道',
  seo_source STRING COMMENT '搜索来源',
  session_cnt BIGINT COMMENT '访问会话数',
  session_share DECIMAL(10,4) COMMENT '占当日会话比例',
  consult_session_cnt BIGINT COMMENT '咨询会话数',
  consult_rate DECIMAL(10,4) COMMENT '会话咨询率',
  high_intent_cnt BIGINT COMMENT '高意向会话数'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

DROP TABLE IF EXISTS edu_dws.dws_page_rank_agg;
CREATE TABLE edu_dws.dws_page_rank_agg (
  url_title STRING COMMENT '页面标题',
  session_cnt BIGINT COMMENT '访问会话数',
  rank_no INT COMMENT '当日排名'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

DROP TABLE IF EXISTS edu_dws.dws_device_hour_agg;
CREATE TABLE edu_dws.dws_device_hour_agg (
  os_info STRING COMMENT '操作系统',
  browser_name STRING COMMENT '浏览器',
  hour_no INT COMMENT '小时 0-23',
  session_cnt BIGINT COMMENT '访问会话数',
  consult_session_cnt BIGINT COMMENT '咨询会话数',
  consult_rate DECIMAL(10,4) COMMENT '会话咨询率'
)
PARTITIONED BY (dt STRING)
STORED AS ORC;