#!/usr/bin/env bash
# 在 edu-dw 容器内执行：Sqoop 全量导入两张源表到 HDFS text 目录
set -euo pipefail

: "${MYSQL_HOST:=host.docker.internal}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_USER:=root}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD 未设置}"
: "${SOURCE_DB:=nev}"

JDBC_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${SOURCE_DB}?useUnicode=true&characterEncoding=utf8&useSSL=false&zeroDateTimeBehavior=convertToNull"

import_table() {
  local table="$1"
  local target="$2"
  echo "[sqoop] 导入 ${table} -> ${target}"
  sqoop import \
    --connect "${JDBC_URL}" \
    --driver com.mysql.jdbc.Driver \
    --username "${MYSQL_USER}" \
    --password "${MYSQL_PASSWORD}" \
    --table "${table}" \
    --target-dir "${target}" \
    --delete-target-dir \
    --fields-terminated-by '\t' \
    --hive-delims-replacement ' ' \
    --null-string '\\N' \
    --null-non-string '\\N' \
    --num-mappers 1
}

"${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p /tmp/sqoop
"${HADOOP_HOME}/bin/hdfs" dfs -chmod -R 777 /tmp/sqoop

import_table "web_chat_ems_2025_07" "/tmp/sqoop/web_chat_ems"
import_table "web_chat_text_ems_2025_07" "/tmp/sqoop/web_chat_text_ems"

echo "[sqoop] 导入完成"
"${HADOOP_HOME}/bin/hdfs" dfs -ls /tmp/sqoop