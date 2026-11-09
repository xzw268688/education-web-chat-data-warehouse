# 教育机构官网流量与咨询转化数据仓库

《数据仓库综合案例》期末项目。基于 MySQL `nev` 的真实访问/咨询数据，在 Ubuntu 24.04 虚拟机上构建 ODS / DWD / DWS 三层数仓，完成 Sqoop 采集、Hive 清洗与指标聚合、MySQL 导出和 FineBI 看板。

## 环境

| 组件 | 版本 | 说明 |
|---|---|---|
| 虚拟机 | Ubuntu 24.04 LTS | 主机名 `<HOSTNAME>`，IP `<VM_IP>`，SSH 用户 `<SSH_USER>/<SSH_PASSWORD>` |
| JDK | 8 | `/usr/lib/jvm/java-8-openjdk-amd64` |
| Hadoop | 2.7.6 | `/opt/programs/hadoop-2.7.6`，HDFS + 本地 MapReduce |
| Hive | 2.3.7 | `/opt/programs/apache-hive-2.3.7-bin`，Derby metastore |
| Sqoop | 1.4.7 | `/opt/programs/sqoop-1.4.7.bin__hadoop-2.6.0` |
| MySQL | 8.0.46 | `<VM_IP>:3306`，`root/<MYSQL_PASSWORD>`，源库 `nev`、结果库 `edu_result` |
| FineBI | 个人版 | Windows 本机，连接 `<VM_IP>:3306` |

## 快速开始

```bash
# 1. Xshell 登录
ssh <SSH_USER>@<VM_IP>

# 2. 启动 HDFS（如果未启动）
start-dfs.sh

# 3. 建库建表
bash /workspace/scripts/setup_schema.sh

# 4. 单日跑批
bash /workspace/scripts/run_pipeline.sh 2025-07-01

# 5. 质量校验
bash /workspace/scripts/dq_check.sh
```

脚本中的 MySQL 连接默认从环境变量读取：

```bash
export MYSQL_HOST=localhost MYSQL_USER=root MYSQL_PASSWORD=<MYSQL_PASSWORD> SOURCE_DB=nev
```

## 目录

| 路径 | 内容 |
|---|---|
| `/workspace/sql/` | ODS/DWD/DWS 建表、ODS 装载、DWD 清洗建模、DWS 聚合 |
| `/workspace/scripts/` | 建表、采集、导出、一键跑批、质量校验 |
| `/workspace/docs/` | 需求与设计文档、质量报告、Xshell 操作步骤 |
| `docs/数据仓库综合案例实验报告.docx` | 最终 Word 实验报告（提交件） |
| `docs/screenshots/xshell/` | Xshell 真实操作截图 |
| `CONTEXT.md` | 领域术语表 |

## 关键口径

- 访问会话：`web_chat_ems` 一行，业务键 `(session_id, create_time)`
- 咨询会话：`msg_count > 0`
- 客服响应：`reply_msg_count > 0`
- 高意向：`msg_count >= 9`（P75）
- 有效沟通：高意向且客服已响应
- 漏斗：访问 → 咨询 → 响应 → 有效沟通