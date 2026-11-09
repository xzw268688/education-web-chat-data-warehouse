#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker compose down
echo "[edu-dw] 容器已停止；MySQL 数据保留在 mysql-data 卷中"
echo "[edu-dw] 如需彻底清空，执行: docker compose down -v"