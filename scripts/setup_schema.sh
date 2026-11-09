#!/usr/bin/env bash
# 在 edu-dw 容器内执行：创建三层数据库与 14 张正式表
set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

hive -f /workspace/sql/01_ods_ddl.sql
hive -f /workspace/sql/02_dwd_ddl.sql
hive -f /workspace/sql/03_dws_ddl.sql

echo "[schema] 三层数据库与表创建完成"
hive -e "SHOW DATABASES; SHOW TABLES IN edu_ods; SHOW TABLES IN edu_dwd; SHOW TABLES IN edu_dws;"