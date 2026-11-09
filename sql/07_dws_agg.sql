-- DWS 指标聚合
-- 用法: hive --hivevar dt=2025-07-05 -f 07_dws_agg.sql
USE edu_dws;
SET hive.strict.checks.cartesian.product=false;
SET hive.mapred.mode=nonstrict;

-- 1. 日概览 + 三口径咨询率 + 漏斗
INSERT OVERWRITE TABLE edu_dws.dws_visit_daily_agg PARTITION (dt = '${hivevar:dt}')
SELECT
  v.session_cnt,
  v.uv_cnt,
  v.ip_cnt,
  v.consult_session_cnt,
  v.consult_user_cnt,
  v.consult_ip_cnt,
  CASE WHEN v.session_cnt = 0 THEN 0 ELSE ROUND(v.consult_session_cnt / v.session_cnt, 4) END AS session_consult_rate,
  CASE WHEN v.uv_cnt = 0 THEN 0 ELSE ROUND(v.consult_user_cnt / v.uv_cnt, 4) END AS user_consult_rate,
  CASE WHEN v.ip_cnt = 0 THEN 0 ELSE ROUND(v.consult_ip_cnt / v.ip_cnt, 4) END AS ip_consult_rate,
  c.high_intent_cnt,
  c.agent_reply_cnt,
  CASE WHEN v.consult_session_cnt = 0 THEN 0 ELSE ROUND(c.agent_reply_cnt / v.consult_session_cnt, 4) END AS agent_reply_rate,
  v.session_cnt AS funnel_visit_cnt,
  v.consult_session_cnt AS funnel_consult_cnt,
  c.agent_reply_cnt AS funnel_reply_cnt,
  c.effective_cnt AS funnel_effective_cnt,
  CASE WHEN v.session_cnt = 0 THEN 0 ELSE ROUND(v.consult_session_cnt / v.session_cnt, 4) END AS funnel_consult_rate,
  CASE WHEN v.consult_session_cnt = 0 THEN 0 ELSE ROUND(c.agent_reply_cnt / v.consult_session_cnt, 4) END AS funnel_reply_rate,
  CASE WHEN c.agent_reply_cnt = 0 THEN 0 ELSE ROUND(c.effective_cnt / c.agent_reply_cnt, 4) END AS funnel_effective_rate
FROM (
  SELECT
    COUNT(DISTINCT session_id) AS session_cnt,
    COUNT(DISTINCT sid) AS uv_cnt,
    COUNT(DISTINCT ip) AS ip_cnt,
    COUNT(DISTINCT CASE WHEN is_consult = 1 THEN session_id END) AS consult_session_cnt,
    COUNT(DISTINCT CASE WHEN is_consult = 1 THEN sid END) AS consult_user_cnt,
    COUNT(DISTINCT CASE WHEN is_consult = 1 THEN ip END) AS consult_ip_cnt
  FROM edu_dwd.fact_visit
  WHERE dt = '${hivevar:dt}'
) v
CROSS JOIN (
  SELECT
    COALESCE(SUM(is_high_intent), 0) AS high_intent_cnt,
    COALESCE(SUM(is_agent_reply), 0) AS agent_reply_cnt,
    COALESCE(SUM(is_effective), 0) AS effective_cnt
  FROM edu_dwd.fact_consult
  WHERE dt = '${hivevar:dt}'
) c;

-- 2. 地区聚合
INSERT OVERWRITE TABLE edu_dws.dws_visit_region_agg PARTITION (dt = '${hivevar:dt}')
SELECT
  r.country, r.province, r.city,
  COUNT(DISTINCT f.session_id) AS session_cnt,
  COUNT(DISTINCT f.sid) AS uv_cnt,
  COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) AS consult_session_cnt,
  CASE WHEN COUNT(DISTINCT f.session_id) = 0 THEN 0
       ELSE ROUND(COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) / COUNT(DISTINCT f.session_id), 4)
  END AS consult_rate
FROM edu_dwd.fact_visit f
JOIN edu_dwd.dim_region r ON f.region_key = r.region_key AND f.dt = r.dt
WHERE f.dt = '${hivevar:dt}'
GROUP BY r.country, r.province, r.city;

-- 3. 渠道聚合
INSERT OVERWRITE TABLE edu_dws.dws_visit_channel_agg PARTITION (dt = '${hivevar:dt}')
SELECT
  c.origin_channel, c.seo_source,
  COUNT(DISTINCT f.session_id) AS session_cnt,
  CASE WHEN t.total_cnt = 0 THEN 0 ELSE ROUND(COUNT(DISTINCT f.session_id) / t.total_cnt, 4) END AS session_share,
  COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) AS consult_session_cnt,
  CASE WHEN COUNT(DISTINCT f.session_id) = 0 THEN 0
       ELSE ROUND(COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) / COUNT(DISTINCT f.session_id), 4)
  END AS consult_rate,
  COALESCE(SUM(h.high_intent_cnt), 0) AS high_intent_cnt
FROM edu_dwd.fact_visit f
JOIN edu_dwd.dim_channel c ON f.channel_key = c.channel_key AND f.dt = c.dt
CROSS JOIN (
  SELECT COUNT(DISTINCT session_id) AS total_cnt
  FROM edu_dwd.fact_visit WHERE dt = '${hivevar:dt}'
) t
LEFT JOIN (
  SELECT channel_key, SUM(is_high_intent) AS high_intent_cnt
  FROM edu_dwd.fact_consult WHERE dt = '${hivevar:dt}'
  GROUP BY channel_key
) h ON c.channel_key = h.channel_key
WHERE f.dt = '${hivevar:dt}'
GROUP BY c.origin_channel, c.seo_source, t.total_cnt;

-- 4. 页面排行
INSERT OVERWRITE TABLE edu_dws.dws_page_rank_agg PARTITION (dt = '${hivevar:dt}')
SELECT url_title, session_cnt, rank_no
FROM (
  SELECT
    p.url_title,
    COUNT(DISTINCT f.session_id) AS session_cnt,
    ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT f.session_id) DESC) AS rank_no
  FROM edu_dwd.fact_visit f
  JOIN edu_dwd.dim_page p ON f.page_key = p.page_key AND f.dt = p.dt
  WHERE f.dt = '${hivevar:dt}'
  GROUP BY p.url_title
) x;

-- 5. 设备与时段聚合
INSERT OVERWRITE TABLE edu_dws.dws_device_hour_agg PARTITION (dt = '${hivevar:dt}')
SELECT
  d.os_info, d.browser_name, hour(CAST(f.create_time AS TIMESTAMP)) AS hour_no,
  COUNT(DISTINCT f.session_id) AS session_cnt,
  COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) AS consult_session_cnt,
  CASE WHEN COUNT(DISTINCT f.session_id) = 0 THEN 0
       ELSE ROUND(COUNT(DISTINCT CASE WHEN f.is_consult = 1 THEN f.session_id END) / COUNT(DISTINCT f.session_id), 4)
  END AS consult_rate
FROM edu_dwd.fact_visit f
JOIN edu_dwd.dim_device d ON f.device_key = d.device_key AND f.dt = d.dt
WHERE f.dt = '${hivevar:dt}'
GROUP BY d.os_info, d.browser_name, hour(CAST(f.create_time AS TIMESTAMP));