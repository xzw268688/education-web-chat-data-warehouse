-- DWD 清洗与星型建模
-- 用法: hive --hivevar dt=2025-07-05 --hivevar high_intent_threshold=3 -f 06_dwd_etl.sql
USE edu_dwd;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.auto.convert.join=true;

-- 1. 清洗：删除空 ID、空/非法时间、同日重复会话
--    业务键为 (session_id, create_time)；跨日快照保留，不做跨日期去重
DROP TABLE IF EXISTS edu_dwd.tmp_cleaned_visit;
CREATE TABLE edu_dwd.tmp_cleaned_visit
STORED AS ORC
AS
SELECT
  id, session_id, sid, create_time, ip,
  seo_source, seo_keywords, area, country, province, city,
  origin_channel, user_match, reply_msg_count, msg_count,
  browser_name, os_info
FROM (
  SELECT
    e.id, trim(e.session_id) AS session_id, trim(e.sid) AS sid, e.create_time, e.ip,
    e.seo_source, e.seo_keywords, e.area, e.country, e.province, e.city,
    e.origin_channel, e.user_match,
    GREATEST(COALESCE(e.reply_msg_count, 0), 0) AS reply_msg_count,
    GREATEST(COALESCE(e.msg_count, 0), 0) AS msg_count,
    e.browser_name, e.os_info,
    ROW_NUMBER() OVER (
      PARTITION BY trim(e.session_id), e.create_time
      ORDER BY e.id
    ) AS rn
  FROM edu_ods.ods_web_chat_ems e
  WHERE e.dt = '${hivevar:dt}'
    AND e.session_id IS NOT NULL AND trim(e.session_id) <> ''
    AND e.sid IS NOT NULL AND trim(e.sid) <> ''
    AND e.create_time RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}'
) t
WHERE rn = 1;

-- 2. 页面信息按 session_id 映射，跨快照日复用页面维度
DROP TABLE IF EXISTS edu_dwd.tmp_page_by_session;
CREATE TABLE edu_dwd.tmp_page_by_session
STORED AS ORC
AS
SELECT session_id, url_title, from_url, landing_page_url
FROM (
  SELECT
    e.session_id,
    COALESCE(NULLIF(substr(
      CASE WHEN length(trim(t.url_title)) % 4 = 0 AND trim(t.url_title) RLIKE '^[A-Za-z0-9+/]+={0,2}$'
           THEN decode(unbase64(trim(t.url_title)), 'UTF-8') ELSE trim(t.url_title) END, 1, 255), ''), '未知') AS url_title,
    COALESCE(NULLIF(substr(
      CASE WHEN length(trim(t.from_url)) % 4 = 0 AND trim(t.from_url) RLIKE '^[A-Za-z0-9+/]+={0,2}$'
           THEN decode(unbase64(trim(t.from_url)), 'UTF-8') ELSE trim(t.from_url) END, 1, 1024), ''), '未知') AS from_url,
    COALESCE(NULLIF(substr(
      CASE WHEN length(trim(t.landing_page_url)) % 4 = 0 AND trim(t.landing_page_url) RLIKE '^[A-Za-z0-9+/]+={0,2}$'
           THEN decode(unbase64(trim(t.landing_page_url)), 'UTF-8') ELSE trim(t.landing_page_url) END, 1, 1024), ''), '未知') AS landing_page_url,
    ROW_NUMBER() OVER (PARTITION BY e.session_id ORDER BY t.id) AS rn
  FROM edu_ods.ods_web_chat_text_ems t
  JOIN (SELECT DISTINCT id, session_id FROM edu_ods.ods_web_chat_ems) e ON t.id = e.id
) x
WHERE rn = 1;

-- 2. 归一化 + 维度键 + 页面关联
DROP TABLE IF EXISTS edu_dwd.tmp_visit_norm;
CREATE TABLE edu_dwd.tmp_visit_norm
STORED AS ORC
AS
SELECT
  t.*,
  md5(concat_ws('|', t.country, t.province, t.city)) AS region_key,
  md5(concat_ws('|', t.origin_channel, t.seo_source)) AS channel_key,
  md5(concat_ws('|', t.os_info, t.browser_name)) AS device_key,
  md5(concat_ws('|', t.url_title, t.from_url, t.landing_page_url)) AS page_key
FROM (
  SELECT
    v.id, v.session_id, v.sid, v.create_time, v.ip,
    GREATEST(COALESCE(v.msg_count, 0), 0) AS msg_count,
    GREATEST(COALESCE(v.reply_msg_count, 0), 0) AS reply_msg_count,
    CASE WHEN COALESCE(v.msg_count, 0) > 0 THEN 1 ELSE 0 END AS is_consult,
    CAST(date_format(CAST(v.create_time AS TIMESTAMP), 'yyyyMMdd') AS INT) AS date_key,
    COALESCE(NULLIF(trim(v.country), ''), '未知') AS country,
    COALESCE(NULLIF(trim(v.province), ''), '未知') AS province,
    COALESCE(NULLIF(trim(v.city), ''), '未知') AS city,
    COALESCE(NULLIF(trim(v.origin_channel), ''), '未知') AS origin_channel,
    COALESCE(NULLIF(trim(v.seo_source), ''), '未知') AS seo_source,
    COALESCE(NULLIF(trim(v.os_info), ''), '未知') AS os_info,
    COALESCE(NULLIF(trim(v.browser_name), ''), '未知') AS browser_name,
    COALESCE(NULLIF(substr(trim(p.url_title), 1, 255), ''), '未知') AS url_title,
    COALESCE(NULLIF(substr(trim(p.from_url), 1, 1024), ''), '未知') AS from_url,
    COALESCE(NULLIF(substr(trim(p.landing_page_url), 1, 1024), ''), '未知') AS landing_page_url
  FROM edu_dwd.tmp_cleaned_visit v
  LEFT JOIN edu_dwd.tmp_page_by_session p ON v.session_id = p.session_id
) t;

-- 3. 维表（按 dt 日快照）
INSERT OVERWRITE TABLE edu_dwd.dim_date PARTITION (dt = '${hivevar:dt}')
SELECT DISTINCT
  date_key,
  year(CAST(create_time AS TIMESTAMP)) AS year,
  month(CAST(create_time AS TIMESTAMP)) AS month,
  day(CAST(create_time AS TIMESTAMP)) AS day,
  pmod(dayofweek(CAST(create_time AS TIMESTAMP)) + 5, 7) + 1 AS weekday,
  CASE WHEN dayofweek(CAST(create_time AS TIMESTAMP)) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM edu_dwd.tmp_visit_norm;

INSERT OVERWRITE TABLE edu_dwd.dim_region PARTITION (dt = '${hivevar:dt}')
SELECT DISTINCT region_key, country, province, city FROM edu_dwd.tmp_visit_norm;

INSERT OVERWRITE TABLE edu_dwd.dim_channel PARTITION (dt = '${hivevar:dt}')
SELECT DISTINCT channel_key, origin_channel, seo_source FROM edu_dwd.tmp_visit_norm;

INSERT OVERWRITE TABLE edu_dwd.dim_page PARTITION (dt = '${hivevar:dt}')
SELECT DISTINCT page_key, url_title, from_url, landing_page_url FROM edu_dwd.tmp_visit_norm;

INSERT OVERWRITE TABLE edu_dwd.dim_device PARTITION (dt = '${hivevar:dt}')
SELECT DISTINCT device_key, os_info, browser_name FROM edu_dwd.tmp_visit_norm;

-- 4. 事实表
INSERT OVERWRITE TABLE edu_dwd.fact_visit PARTITION (dt = '${hivevar:dt}')
SELECT
  session_id, sid, date_key, region_key, channel_key, page_key, device_key,
  ip, CAST(create_time AS TIMESTAMP) AS create_time, msg_count, reply_msg_count, is_consult
FROM edu_dwd.tmp_visit_norm;

INSERT OVERWRITE TABLE edu_dwd.fact_consult PARTITION (dt = '${hivevar:dt}')
SELECT
  session_id, sid, date_key, region_key, channel_key, device_key,
  msg_count, reply_msg_count,
  CASE WHEN reply_msg_count > 0 THEN 1 ELSE 0 END AS is_agent_reply,
  CASE WHEN msg_count >= ${hivevar:high_intent_threshold} THEN 1 ELSE 0 END AS is_high_intent,
  CASE WHEN msg_count >= ${hivevar:high_intent_threshold} AND reply_msg_count > 0 THEN 1 ELSE 0 END AS is_effective
FROM edu_dwd.tmp_visit_norm
WHERE is_consult = 1;

-- 5. 校验
SELECT 'cleaned' AS metric, COUNT(*) AS cnt FROM edu_dwd.tmp_cleaned_visit
UNION ALL
SELECT 'fact_visit', COUNT(*) FROM edu_dwd.fact_visit WHERE dt = '${hivevar:dt}'
UNION ALL
SELECT 'fact_consult', COUNT(*) FROM edu_dwd.fact_consult WHERE dt = '${hivevar:dt}';