#!/usr/bin/env bash
# 在 edu-dw 容器内执行：DWS ORC -> text 中转目录 -> Sqoop 导出 MySQL
set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

DT="${1:?用法: export_mysql.sh <YYYY-MM-DD>}"
: "${MYSQL_HOST:=mysql}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_USER:=root}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD 未设置}"
RESULT_DB="${RESULT_DB:-edu_result}"
JDBC="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${RESULT_DB}?useUnicode=true&characterEncoding=utf8&useSSL=false"

mysql_cmd() {
  mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    --default-character-set=utf8mb4 "${RESULT_DB}" -e "$1"
}

export_table() {
  local table="$1"
  local columns="$2"
  local select_list="$3"
  local dir="/tmp/export/${DT}/${table}"

  echo "[export] ${table} -> ${RESULT_DB}.${table}"
  hive -e "INSERT OVERWRITE DIRECTORY '${dir}' ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' SELECT ${select_list} FROM edu_dws.${table} WHERE dt='${DT}'"
  mysql_cmd "DELETE FROM ${table} WHERE dt='${DT}'"
  sqoop export \
    --connect "${JDBC}" \
    --driver com.mysql.jdbc.Driver \
    --username "${MYSQL_USER}" \
    --password "${MYSQL_PASSWORD}" \
    --table "${table}" \
    --export-dir "${dir}" \
    --fields-terminated-by '\t' \
    --input-null-string '\\N' \
    --input-null-non-string '\\N' \
    --columns "${columns}" \
    --num-mappers 1
  mysql_cmd "SELECT '${table}' AS table_name, COUNT(*) AS rows_exported FROM ${table} WHERE dt='${DT}'"
}

export_table "dws_visit_daily_agg" \
  "dt,session_cnt,uv_cnt,visit_ip_cnt,consult_session_cnt,consult_user_cnt,consult_ip_cnt,session_consult_rate,user_consult_rate,ip_consult_rate,high_intent_cnt,agent_reply_cnt,agent_reply_rate,funnel_visit_cnt,funnel_consult_cnt,funnel_reply_cnt,funnel_effective_cnt,funnel_consult_rate,funnel_reply_rate,funnel_effective_rate" \
  "dt, session_cnt, uv_cnt, visit_ip_cnt, consult_session_cnt, consult_user_cnt, consult_ip_cnt, session_consult_rate, user_consult_rate, ip_consult_rate, high_intent_cnt, agent_reply_cnt, agent_reply_rate, funnel_visit_cnt, funnel_consult_cnt, funnel_reply_cnt, funnel_effective_cnt, funnel_consult_rate, funnel_reply_rate, funnel_effective_rate"

export_table "dws_visit_region_agg" \
  "dt,country,province,city,session_cnt,uv_cnt,consult_session_cnt,consult_rate" \
  "dt, country, province, city, session_cnt, uv_cnt, consult_session_cnt, consult_rate"

export_table "dws_visit_channel_agg" \
  "dt,origin_channel,seo_source,session_cnt,session_share,consult_session_cnt,consult_rate,high_intent_cnt" \
  "dt, origin_channel, seo_source, session_cnt, session_share, consult_session_cnt, consult_rate, high_intent_cnt"

export_table "dws_page_rank_agg" \
  "dt,url_title,session_cnt,rank_no" \
  "dt, regexp_replace(url_title, '[\\t\\n\\r]', ' ') AS url_title, session_cnt, rank_no"

export_table "dws_device_hour_agg" \
  "dt,os_info,browser_name,hour_no,session_cnt,consult_session_cnt,consult_rate" \
  "dt, os_info, browser_name, hour_no, session_cnt, consult_session_cnt, consult_rate"

echo "[export] 全部完成"