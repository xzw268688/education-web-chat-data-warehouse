#!/usr/bin/env bash
set -euo pipefail

: "${MYSQL_HOST:=mysql}"
: "${MYSQL_PORT:=3306}"
: "${MYSQL_USER:=root}"
: "${MYSQL_PASSWORD:=}"
: "${MYSQL_DB:=hive_metastore}"

echo "[edu-dw] 等待 MySQL ${MYSQL_HOST}:${MYSQL_PORT}"
for _ in $(seq 1 60); do
  if nc -z "${MYSQL_HOST}" "${MYSQL_PORT}" 2>/dev/null; then
    break
  fi
  sleep 2
done
if ! nc -z "${MYSQL_HOST}" "${MYSQL_PORT}" 2>/dev/null; then
  echo "[edu-dw] 无法连接 MySQL，请检查 bind-address、3306 防火墙与 docker --add-host"
  exit 1
fi

export MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DB
envsubst '${MYSQL_HOST} ${MYSQL_PORT} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DB}' \
  < "${HIVE_HOME}/conf/hive-site.xml.template" > "${HIVE_HOME}/conf/hive-site.xml"

if [ ! -f /opt/hadoop/data/name/current/VERSION ]; then
  echo "[edu-dw] 格式化 NameNode"
  "${HADOOP_HOME}/bin/hdfs" namenode -format -force -nonInteractive
fi

"${HADOOP_HOME}/sbin/hadoop-daemon.sh" start namenode
"${HADOOP_HOME}/sbin/hadoop-daemon.sh" start datanode

echo "[edu-dw] 等待 HDFS"
for _ in $(seq 1 60); do
  if "${HADOOP_HOME}/bin/hdfs" dfsadmin -report >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
# HDFS 可能因残留损坏块处于安全模式，此时 mkdir/chmod 会失败；
# 不能因这两步失败就让容器退出，否则会陷入 restart 死循环。
"${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p /user/hive/warehouse /tmp/hive || true
"${HADOOP_HOME}/bin/hdfs" dfs -chmod -R 777 /tmp /user/hive || true

if ! "${HIVE_HOME}/bin/schematool" -dbType mysql -info >/dev/null 2>&1; then
  echo "[edu-dw] 初始化 Hive metastore"
  "${HIVE_HOME}/bin/schematool" -dbType mysql -initSchema
fi

echo "[edu-dw] 环境就绪：HDFS 9000 / NameNode UI 50070"
exec tail -f /dev/null