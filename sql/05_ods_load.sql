-- 将 Sqoop 导入的 text 文件装入临时表，再写入 ODS ORC 分区
USE edu_ods;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

TRUNCATE TABLE edu_ods.tmp_web_chat_ems_text;
LOAD DATA INPATH '/tmp/sqoop/web_chat_ems' OVERWRITE INTO TABLE edu_ods.tmp_web_chat_ems_text;

TRUNCATE TABLE edu_ods.tmp_web_chat_text_ems_text;
LOAD DATA INPATH '/tmp/sqoop/web_chat_text_ems' OVERWRITE INTO TABLE edu_ods.tmp_web_chat_text_ems_text;

-- 访问会话写入 ODS，dt 取自 create_time；非法时间归入 unknown 分区
ALTER TABLE edu_ods.ods_web_chat_ems DROP IF EXISTS PARTITION (dt = 'unknown');

INSERT OVERWRITE TABLE edu_ods.ods_web_chat_ems PARTITION (dt)
SELECT
  id,
  session_id,
  sid,
  create_time,
  seo_source,
  seo_keywords,
  ip,
  area,
  country,
  province,
  city,
  origin_channel,
  user_match,
  manual_time,
  begin_time,
  end_time,
  last_customer_msg_time_stamp,
  last_agent_msg_time_stamp,
  reply_msg_count,
  msg_count,
  browser_name,
  os_info,
  CASE
    WHEN create_time RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'
      THEN substr(create_time, 1, 10)
    ELSE 'unknown'
  END AS dt
FROM edu_ods.tmp_web_chat_ems_text;

-- 页面信息通过 id 关联访问会话取得 dt
ALTER TABLE edu_ods.ods_web_chat_text_ems DROP IF EXISTS PARTITION (dt = 'unknown');

INSERT OVERWRITE TABLE edu_ods.ods_web_chat_text_ems PARTITION (dt)
SELECT
  t.id,
  t.referrer,
  t.from_url,
  t.landing_page_url,
  t.url_title,
  t.platform_description,
  t.other_params,
  t.history,
  e.dt
FROM edu_ods.tmp_web_chat_text_ems_text t
JOIN edu_ods.ods_web_chat_ems e ON t.id = e.id;

-- 校验：ODS 行数
SELECT 'ods_web_chat_ems' AS table_name, COUNT(*) AS cnt FROM edu_ods.ods_web_chat_ems
UNION ALL
SELECT 'ods_web_chat_text_ems' AS table_name, COUNT(*) AS cnt FROM edu_ods.ods_web_chat_text_ems;