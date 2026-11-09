-- 可视化结果库（在 Windows MySQL 5.7 执行）
-- 强制客户端连接字符集为 utf8mb4，避免中文表/字段注释被 latin1 双重编码
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS edu_result DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE edu_result;

DROP TABLE IF EXISTS dws_visit_daily_agg;
CREATE TABLE dws_visit_daily_agg (
  id BIGINT NOT NULL AUTO_INCREMENT,
  dt DATE NOT NULL COMMENT '统计日期',
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
  funnel_effective_rate DECIMAL(10,4) COMMENT '响应到有效沟通转化率',
  PRIMARY KEY (id),
  UNIQUE KEY uk_dt (dt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='日概览与漏斗';

DROP TABLE IF EXISTS dws_visit_region_agg;
CREATE TABLE dws_visit_region_agg (
  id BIGINT NOT NULL AUTO_INCREMENT,
  dt DATE NOT NULL,
  country VARCHAR(64),
  province VARCHAR(64),
  city VARCHAR(128),
  session_cnt BIGINT,
  uv_cnt BIGINT,
  consult_session_cnt BIGINT,
  consult_rate DECIMAL(10,4),
  PRIMARY KEY (id),
  KEY idx_dt_region (dt, province, city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='地区汇总';

DROP TABLE IF EXISTS dws_visit_channel_agg;
CREATE TABLE dws_visit_channel_agg (
  id BIGINT NOT NULL AUTO_INCREMENT,
  dt DATE NOT NULL,
  origin_channel VARCHAR(128),
  seo_source VARCHAR(255),
  session_cnt BIGINT,
  session_share DECIMAL(10,4),
  consult_session_cnt BIGINT,
  consult_rate DECIMAL(10,4),
  high_intent_cnt BIGINT,
  PRIMARY KEY (id),
  KEY idx_dt_channel (dt, origin_channel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='渠道汇总';

DROP TABLE IF EXISTS dws_page_rank_agg;
CREATE TABLE dws_page_rank_agg (
  id BIGINT NOT NULL AUTO_INCREMENT,
  dt DATE NOT NULL,
  url_title VARCHAR(512),
  session_cnt BIGINT,
  rank_no INT,
  PRIMARY KEY (id),
  KEY idx_dt_rank (dt, rank_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='页面排行';

DROP TABLE IF EXISTS dws_device_hour_agg;
CREATE TABLE dws_device_hour_agg (
  id BIGINT NOT NULL AUTO_INCREMENT,
  dt DATE NOT NULL,
  os_info VARCHAR(128),
  browser_name VARCHAR(128),
  hour_no INT,
  session_cnt BIGINT,
  consult_session_cnt BIGINT,
  consult_rate DECIMAL(10,4),
  PRIMARY KEY (id),
  KEY idx_dt_device_hour (dt, hour_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备与时段汇总';