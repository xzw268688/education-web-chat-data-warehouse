#!/usr/bin/env bash
# 一键跑批：采集 -> ODS -> DWD -> DWS -> 导出
# 用法: run_pipeline.sh <YYYY-MM-DD> [skip-import]
set -euo pipefail

# 容器默认 locale 为 POSIX，JVM 会以 ASCII 读取 SQL 文件，
# 导致脚本里的中文字面量（如 '未知'）变成 U+FFFD。必须强制 UTF-8。
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

DT="${1:?用法: run_pipeline.sh <YYYY-MM-DD> [skip-import]}"
SKIP_IMPORT="${2:-}"
HIGH_INTENT_THRESHOLD="${HIGH_INTENT_THRESHOLD:-9}"

echo "==================== [pipeline] ${DT} ===================="

if [ "${SKIP_IMPORT}" != "skip-import" ]; then
  echo "---- 阶段 1/4：Sqoop 采集 ----"
  bash /workspace/scripts/sqoop_import.sh
  echo "---- 阶段 1.5/4：写入 ODS ----"
  hive -f /workspace/sql/05_ods_load.sql
else
  echo "---- 跳过采集，直接使用现有 ODS ----"
fi

echo "---- 阶段 2/4：DWD 清洗与建模 ----"
hive --hivevar dt="${DT}" --hivevar high_intent_threshold="${HIGH_INTENT_THRESHOLD}" -f /workspace/sql/06_dwd_etl.sql

echo "---- 阶段 3/4：DWS 指标聚合 ----"
hive --hivevar dt="${DT}" -f /workspace/sql/07_dws_agg.sql

echo "---- 阶段 4/4：导出 MySQL ----"
bash /workspace/scripts/export_mysql.sh "${DT}"

echo "==================== [pipeline] 完成 ${DT} ===================="