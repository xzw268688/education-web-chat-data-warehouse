#!/usr/bin/env bash
# 在 edu-dw 容器内执行：数据质量校验并生成 Markdown 报告
set -euo pipefail

# 容器默认 locale 为 POSIX，Hive JVM 会把 SQL 里的中文字面量读成替换字符
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

: "${MYSQL_HOST:=mysql}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_USER:=root}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD 未设置}"
RESULT_DB="${RESULT_DB:-edu_result}"
REPORT="/workspace/docs/质量报告.md"
DT_LIST="2025-07-01 2025-07-02 2025-07-25"
TABLES="dws_visit_daily_agg dws_visit_region_agg dws_visit_channel_agg dws_page_rank_agg dws_device_hour_agg"

mkdir -p /workspace/docs

hive_val() {
  hive -S -e "$1" 2>/dev/null | tail -1 | tr -d '[:space:]' || true
}

mysql_val() {
  mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
    --default-character-set=utf8mb4 -N -e "$1" 2>/dev/null | tail -1 || true
}

pass_eq() {
  local name="$1" actual="$2" expected="$3" note="$4"
  local status="PASS"
  [ "${actual}" = "${expected}" ] || status="FAIL"
  printf '| %s | %s | %s | %s | %s |\n' "${name}" "${actual}" "${expected}" "相等" "${status}" >> "${REPORT}"
}

pass_le() {
  local name="$1" actual="$2" threshold="$3" note="$4"
  local status
  status=$(awk -v a="${actual}" -v t="${threshold}" 'BEGIN { print (a <= t) ? "PASS" : "FAIL" }')
  printf '| %s | %s | ≤ %s | %s | %s |\n' "${name}" "${actual}" "${threshold}" "${note}" "${status}" >> "${REPORT}"
}

{
  echo "# 数据质量校验报告"
  echo
  echo "- 生成时间：$(date '+%Y-%m-%d %H:%M:%S')"
  echo "- 校验范围：${DT_LIST}"
  echo
  echo "## 1. 校验结果"
  echo
  echo "| 校验项 | 实际值 | 阈值/期望 | 说明 | 状态 |"
  echo "|---|---|---|---|---|"
} > "${REPORT}"

# 行数守恒：源表 vs ODS
SRC_EMS=$(mysql_val "SELECT COUNT(*) FROM nev.web_chat_ems_2025_07")
SRC_TEXT=$(mysql_val "SELECT COUNT(*) FROM nev.web_chat_text_ems_2025_07")
ODS_EMS=$(hive_val "SELECT COUNT(*) FROM edu_ods.ods_web_chat_ems")
ODS_TEXT=$(hive_val "SELECT COUNT(*) FROM edu_ods.ods_web_chat_text_ems")
pass_eq "源表→ODS 访问会话行数" "${ODS_EMS}" "${SRC_EMS}" "源表 211,197 行"
pass_eq "源表→ODS 页面信息行数" "${ODS_TEXT}" "${SRC_TEXT}" "页面表 105,599 行"

# ODS vs DWD
DWD_VISIT=$(hive_val "SELECT COUNT(*) FROM edu_dwd.fact_visit")
DWD_CONSULT=$(hive_val "SELECT COUNT(*) FROM edu_dwd.fact_consult")
pass_eq "ODS→DWD 访问事实行数" "${DWD_VISIT}" "${ODS_EMS}" "三个快照日合计"
pass_eq "DWD 咨询事实行数" "${DWD_CONSULT}" "7262" "msg_count > 0 的快照行"

# 主键唯一性
DUP_VISIT=$(hive_val "SELECT COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', session_id, CAST(create_time AS STRING))) FROM edu_dwd.fact_visit")
DUP_CONSULT=$(hive_val "SELECT COUNT(*) - COUNT(DISTINCT CONCAT_WS('|', session_id, dt)) FROM edu_dwd.fact_consult")
pass_eq "fact_visit 业务键重复数" "${DUP_VISIT}" "0" "(session_id, create_time) 唯一"
pass_eq "fact_consult 业务键重复数" "${DUP_CONSULT}" "0" "(session_id, dt) 唯一"

# 未知值比例
# 未知值比例
U_COUNTRY=$(hive_val "SELECT ROUND(SUM(CASE WHEN r.country='未知' THEN 1 ELSE 0 END)/COUNT(*),4) FROM edu_dwd.fact_visit f JOIN edu_dwd.dim_region r ON f.region_key=r.region_key AND f.dt=r.dt")
U_PROVINCE=$(hive_val "SELECT ROUND(SUM(CASE WHEN r.province='未知' THEN 1 ELSE 0 END)/COUNT(*),4) FROM edu_dwd.fact_visit f JOIN edu_dwd.dim_region r ON f.region_key=r.region_key AND f.dt=r.dt")
U_CITY=$(hive_val "SELECT ROUND(SUM(CASE WHEN r.city='未知' THEN 1 ELSE 0 END)/COUNT(*),4) FROM edu_dwd.fact_visit f JOIN edu_dwd.dim_region r ON f.region_key=r.region_key AND f.dt=r.dt")
U_CHANNEL=$(hive_val "SELECT ROUND(SUM(CASE WHEN c.origin_channel='未知' THEN 1 ELSE 0 END)/COUNT(*),4) FROM edu_dwd.fact_visit f JOIN edu_dwd.dim_channel c ON f.channel_key=c.channel_key AND f.dt=c.dt")
U_OS=$(hive_val "SELECT ROUND(SUM(CASE WHEN d.os_info='未知' THEN 1 ELSE 0 END)/COUNT(*),4) FROM edu_dwd.fact_visit f JOIN edu_dwd.dim_device d ON f.device_key=d.device_key AND f.dt=d.dt")
pass_le "国家未知比例" "${U_COUNTRY}" "0.01" "归一化后仍保留"
pass_le "省份未知比例" "${U_PROVINCE}" "0.01" "归一化后仍保留"
pass_le "城市未知比例" "${U_CITY}" "0.30" "归一化后仍保留"
pass_le "渠道未知比例" "${U_CHANNEL}" "0.30" "归一化后仍保留"
pass_le "操作系统未知比例" "${U_OS}" "0.05" "归一化后仍保留"

# 比率区间与漏斗单调性
BAD_RATE=$(hive_val "SELECT COUNT(*) FROM edu_dws.dws_visit_daily_agg WHERE session_consult_rate NOT BETWEEN 0 AND 1 OR user_consult_rate NOT BETWEEN 0 AND 1 OR ip_consult_rate NOT BETWEEN 0 AND 1 OR agent_reply_rate NOT BETWEEN 0 AND 1")
BAD_FUNNEL=$(hive_val "SELECT COUNT(*) FROM edu_dws.dws_visit_daily_agg WHERE NOT (funnel_visit_cnt >= funnel_consult_cnt AND funnel_consult_cnt >= funnel_reply_cnt AND funnel_reply_cnt >= funnel_effective_cnt)")
pass_eq "咨询率越界行数" "${BAD_RATE}" "0" "所有比率在 0–1 之间"
pass_eq "漏斗非单调行数" "${BAD_FUNNEL}" "0" "四段计数单调不增"

# 导出对账
for dt in ${DT_LIST}; do
  for table in ${TABLES}; do
    hive_cnt=$(hive_val "SELECT COUNT(*) FROM edu_dws.${table} WHERE dt='${dt}'")
    mysql_cnt=$(mysql_val "SELECT COUNT(*) FROM ${RESULT_DB}.${table} WHERE dt='${dt}'")
    pass_eq "导出 ${table} ${dt}" "${mysql_cnt}" "${hive_cnt}" "DWS 与 MySQL 行数一致"
  done
done

# 关键指标
{
  echo
  echo "## 2. 关键指标（MySQL 结果库）"
  echo
  echo "| 日期 | 会话数 | UV | 咨询会话 | 会话咨询率 | 高意向 | 客服响应率 | 有效沟通 |"
  echo "|---|---|---|---|---|---|---|---|"
} >> "${REPORT}"

mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
  --default-character-set=utf8mb4 -N -e \
  "SELECT dt, session_cnt, uv_cnt, consult_session_cnt, session_consult_rate, high_intent_cnt, agent_reply_rate, funnel_effective_cnt FROM ${RESULT_DB}.dws_visit_daily_agg ORDER BY dt;" 2>/dev/null \
  | awk -F'\t' '{printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n", $1,$2,$3,$4,$5,$6,$7,$8}' >> "${REPORT}"

{
  echo
  echo "## 3. 结论"
  echo
  if grep -q "FAIL" "${REPORT}"; then
    echo "存在未通过校验项，请查看上表。"
    exit_code=1
  else
    echo "全部校验项通过。"
    exit_code=0
  fi
} >> "${REPORT}"

cp "${REPORT}" /workspace/docs/quality_report.md 2>/dev/null || true
echo "[dq] 报告已生成：${REPORT}"
exit ${exit_code:-0}