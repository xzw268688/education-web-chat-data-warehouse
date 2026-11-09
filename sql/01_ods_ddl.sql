-- ODS 层建库建表
CREATE DATABASE IF NOT EXISTS edu_ods;

-- 访问会话：Sqoop 导入用 text 临时表（制表符分隔）
DROP TABLE IF EXISTS edu_ods.tmp_web_chat_ems_text;
CREATE TABLE edu_ods.tmp_web_chat_ems_text (
  id INT,
  session_id STRING,
  sid STRING,
  create_time STRING,
  seo_source STRING,
  seo_keywords STRING,
  ip STRING,
  area STRING,
  country STRING,
  province STRING,
  city STRING,
  origin_channel STRING,
  user_match STRING,
  manual_time STRING,
  begin_time STRING,
  end_time STRING,
  last_customer_msg_time_stamp STRING,
  last_agent_msg_time_stamp STRING,
  reply_msg_count INT,
  msg_count INT,
  browser_name STRING,
  os_info STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

-- 访问会话：ORC 正式表，按 dt 日分区
DROP TABLE IF EXISTS edu_ods.ods_web_chat_ems;
CREATE TABLE edu_ods.ods_web_chat_ems (
  id INT,
  session_id STRING,
  sid STRING,
  create_time STRING,
  seo_source STRING,
  seo_keywords STRING,
  ip STRING,
  area STRING,
  country STRING,
  province STRING,
  city STRING,
  origin_channel STRING,
  user_match STRING,
  manual_time STRING,
  begin_time STRING,
  end_time STRING,
  last_customer_msg_time_stamp STRING,
  last_agent_msg_time_stamp STRING,
  reply_msg_count INT,
  msg_count INT,
  browser_name STRING,
  os_info STRING
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');

-- 页面信息：text 临时表
DROP TABLE IF EXISTS edu_ods.tmp_web_chat_text_ems_text;
CREATE TABLE edu_ods.tmp_web_chat_text_ems_text (
  id INT,
  referrer STRING,
  from_url STRING,
  landing_page_url STRING,
  url_title STRING,
  platform_description STRING,
  other_params STRING,
  history STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;

-- 页面信息：ORC 正式表，按 dt 日分区
DROP TABLE IF EXISTS edu_ods.ods_web_chat_text_ems;
CREATE TABLE edu_ods.ods_web_chat_text_ems (
  id INT,
  referrer STRING,
  from_url STRING,
  landing_page_url STRING,
  url_title STRING,
  platform_description STRING,
  other_params STRING,
  history STRING
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');