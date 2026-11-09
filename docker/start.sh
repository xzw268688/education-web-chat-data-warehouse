#!/usr/bin/env bash
set -euo pipefail
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "[edu-dw] 已生成 .env，如需修改 MySQL root 密码请编辑后重新执行"
fi

docker compose up -d --build
sleep 5
docker compose ps
echo "---- edu-dw 日志 ----"
docker compose logs --tail=60 edu-dw || true
echo "---- MySQL 访问 ----"
echo "容器内: mysql:3306"
echo "宿主:   localhost:3307 (用户 root)"