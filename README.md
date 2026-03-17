# OpenClaw 多实例 Docker 部署 (A–Z)

在同一台机器上运行最多 **26 个**独立的 OpenClaw 实例（A–Z），每个实例拥有独立的配置、工作空间、凭据、会话和网络端口。默认使用 **vLLM** 作为推理后端。

## 特性

- 开箱即用 26 个实例（A–Z），端口范围 40100–42601
- 默认配置指向本地 vLLM 后端（`https://127.0.0.1:8080`，模型 `qwen`）
- `setup.sh` 一键初始化：自动检测 LAN IP、生成 Gateway Token、写入默认配置、修复文件权限
- 每个实例完全隔离：独立配置、凭据、工作空间、Gateway Token、Channel Bot
- 支持 Telegram / Discord / Slack 频道
- 支持 OpenAI / Anthropic / vLLM 等多种 LLM Provider
- 内置健康检查，容器异常自动重启
- CLI 容器安全加固（cap_drop, no-new-privileges）

## 前置要求

- Docker Engine 20.10+ 或 Docker Desktop
- Docker Compose v2
- 每个实例约 512MB RAM（建议总计 2GB+）
- （可选）本地 vLLM 服务运行在 `https://127.0.0.1:8080`

## 快速开始

```bash
# 1. 创建 .env 并编辑
cp .env.example .env
# 编辑 .env，填入 API key 和 channel token（可选，setup.sh 会自动生成 gateway token）

# 2. 初始化（创建目录、生成 token、种子配置、拉取镜像）
bash setup.sh

# 3. 启动所有实例
docker compose up -d
```

## 目录结构

```
deploy-multi-openclaw/
├── docker-compose.yaml      # 26 个实例的服务定义（A–Z）
├── .env.example             # 环境变量模板
├── .env                     # 实际配置（git ignored）
├── setup.sh                 # 一键初始化脚本
├── README.md
└── instances/               # setup.sh 自动创建
    ├── a/
    │   ├── config/          # openclaw.json, credentials/, agents/, identity/
    │   └── workspace/
    ├── b/
    │   ├── config/
    │   └── workspace/
    ├── ...
    └── z/
        ├── config/
        └── workspace/
```

## 端口映射

端口规则：实例序号 N（1–26）→ Gateway `40N00`，Bridge `40N01`。

所有端口可通过 `.env` 中的 `OPENCLAW_X_GATEWAY_PORT` / `OPENCLAW_X_BRIDGE_PORT` 自定义。

| 实例 | 序号 | Gateway | Bridge | Control UI | user |
| ---- | ---- | ------- | ------ | ---------- | ---- |
| A    | 1    | 40100   | 40101  | `http://<host>:40100/` |      |
| B    | 2    | 40200   | 40201  | `http://<host>:40200/` |      |
| C    | 3    | 40300   | 40301  | `http://<host>:40300/` |      |
| D    | 4    | 40400   | 40401  | `http://<host>:40400/` |      |
| E    | 5    | 40500   | 40501  | `http://<host>:40500/` |      |
| F    | 6    | 40600   | 40601  | `http://<host>:40600/` |      |
| G    | 7    | 40700   | 40701  | `http://<host>:40700/` |      |
| H    | 8    | 40800   | 40801  | `http://<host>:40800/` |      |
| I    | 9    | 40900   | 40901  | `http://<host>:40900/` |      |
| J    | 10   | 41000   | 41001  | `http://<host>:41000/` |      |
| K    | 11   | 41100   | 41101  | `http://<host>:41100/` |      |
| L    | 12   | 41200   | 41201  | `http://<host>:41200/` |      |
| M    | 13   | 41300   | 41301  | `http://<host>:41300/` |      |
| N    | 14   | 41400   | 41401  | `http://<host>:41400/` |      |
| O    | 15   | 41500   | 41501  | `http://<host>:41500/` |      |
| P    | 16   | 41600   | 41601  | `http://<host>:41600/` |      |
| Q    | 17   | 41700   | 41701  | `http://<host>:41700/` |      |
| R    | 18   | 41800   | 41801  | `http://<host>:41800/` |      |
| S    | 19   | 41900   | 41901  | `http://<host>:41900/` |      |
| T    | 20   | 42000   | 42001  | `http://<host>:42000/` |      |
| U    | 21   | 42100   | 42101  | `http://<host>:42100/` |      |
| V    | 22   | 42200   | 42201  | `http://<host>:42200/` |      |
| W    | 23   | 42300   | 42301  | `http://<host>:42300/` |      |
| X    | 24   | 42400   | 42401  | `http://<host>:42400/` |      |
| Y    | 25   | 42500   | 42501  | `http://<host>:42500/` |      |
| Z    | 26   | 42600   | 42601  | `http://<host>:42600/` |      |

> 首次访问 Control UI 时需在 URL 后附加 `#token=<GATEWAY_TOKEN>`，Gateway Token 存储在 `.env` 中。

## 实例隔离

| 维度          | 隔离方式                                         |
| ------------- | ------------------------------------------------ |
| 配置          | 各自 `instances/<id>/config/openclaw.json`       |
| 凭据          | 各自 `instances/<id>/config/credentials/`        |
| 身份          | 各自 `instances/<id>/config/identity/`           |
| 会话          | 各自 `instances/<id>/config/agents/`             |
| 工作空间      | 各自 `instances/<id>/workspace/`                 |
| 网络端口      | 各自不同宿主机端口，容器内统一为 18789/18790     |
| Gateway Token | 各自独立的 `OPENCLAW_*_GATEWAY_TOKEN`            |
| Channel Bot   | 各自独立的 bot token（Telegram/Discord/Slack）   |

## setup.sh 初始化脚本

`setup.sh` 完成以下工作：

1. 为 26 个实例创建目录结构（`config/identity`、`config/agents`、`config/credentials`、`workspace`）
2. 自动检测 LAN IP（用于 `allowedOrigins` 配置）
3. 为每个实例生成随机 Gateway Token（已有则跳过）
4. 为每个实例设置默认 `OPENAI_API_KEY=dummy`（用于 vLLM 兼容）
5. 拉取 Docker 镜像
6. 修复目录权限（容器以 uid 1000 运行）
7. 生成默认 `openclaw.json` 配置（vLLM 后端，含 LAN 访问配置）

```bash
# 正常运行（仅补充缺失内容，不覆盖已有配置）
bash setup.sh

# 强制覆盖所有 openclaw.json 配置
bash setup.sh --force
# 或
bash setup.sh -f

# 手动指定 LAN IP（自动检测不准确时）
OPENCLAW_LAN_IP=192.168.1.100 bash setup.sh
```

`setup.sh` 可重复运行，默认只补充缺失的目录和 token，不会覆盖已有配置。当检测到旧格式（`"agent"` 而非 `"agents"`）或缺少 LAN 访问相关字段时，会自动升级配置。

## 配置实例

### 方式一：环境变量（推荐）

编辑 `.env`，环境变量优先级高于配置文件：

```env
OPENCLAW_A_OPENAI_API_KEY=sk-xxx
OPENCLAW_A_ANTHROPIC_API_KEY=sk-ant-xxx
OPENCLAW_A_TELEGRAM_BOT_TOKEN=123456:ABCDEF
```

### 方式二：直接编辑配置文件

```bash
vim instances/a/config/openclaw.json
```

`setup.sh` 生成的默认配置（vLLM 后端）：

```json
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true,
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "allowedOrigins": [
        "http://<LAN_IP>:<PORT>",
        "http://localhost:<PORT>",
        "http://127.0.0.1:<PORT>"
      ]
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "vllm": {
        "baseUrl": "https://127.0.0.1:8080/v1",
        "apiKey": "dummy",
        "api": "openai-completions",
        "models": [
          {
            "id": "qwen",
            "name": "qwen",
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "vllm/qwen"
      }
    }
  }
}
```

### 方式三：通过 CLI onboard（交互式）

```bash
docker compose run --rm openclaw-a \
  node dist/index.js onboard --mode local --no-install-daemon
```

## 环境变量参考

### 全局变量

| 变量 | 默认值 | 说明 |
| ---- | ------ | ---- |
| `OPENCLAW_IMAGE` | `ghcr.io/openclaw/openclaw:latest` | Docker 镜像 |
| `TZ` | `Asia/Shanghai` | 时区 |

### 每实例变量（以 `X` 代表实例字母 A–Z）

| 变量 | 说明 |
| ---- | ---- |
| `OPENCLAW_X_GATEWAY_TOKEN` | Gateway 认证 Token（setup.sh 自动生成） |
| `OPENCLAW_X_GATEWAY_PORT` | Gateway 宿主机端口 |
| `OPENCLAW_X_BRIDGE_PORT` | Bridge 宿主机端口 |
| `OPENCLAW_X_GATEWAY_BIND` | 绑定模式，默认 `lan` |
| `OPENCLAW_X_OPENAI_API_KEY` | OpenAI API Key |
| `OPENCLAW_X_ANTHROPIC_API_KEY` | Anthropic API Key |
| `OPENCLAW_X_TELEGRAM_BOT_TOKEN` | Telegram Bot Token |
| `OPENCLAW_X_DISCORD_BOT_TOKEN` | Discord Bot Token |
| `OPENCLAW_X_SLACK_BOT_TOKEN` | Slack Bot Token |
| `OPENCLAW_X_SLACK_APP_TOKEN` | Slack App Token |

## 常用命令

```bash
# 查看所有实例状态
docker compose ps

# 查看单个实例日志
docker compose logs -f openclaw-a

# 重启单个实例
docker compose restart openclaw-b

# 停止所有实例
docker compose down

# 更新镜像并重启
docker compose pull && docker compose up -d

# 对实例执行 CLI 命令（使用 cli profile）
docker compose --profile cli run --rm openclaw-a-cli channels status --probe
docker compose --profile cli run --rm openclaw-b-cli health

# 直接在 gateway 容器中执行 CLI
docker compose exec openclaw-a node dist/index.js channels status --probe

# WhatsApp 扫码登录（实例 A）
docker compose --profile cli run --rm openclaw-a-cli channels login

# 添加 Telegram channel（实例 B）
docker compose --profile cli run --rm openclaw-b-cli channels add --channel telegram --token <token>

# 查看 dashboard URL
docker compose exec openclaw-c node dist/index.js dashboard --no-open
```

## 容器架构

每个实例包含两个服务：

| 服务 | 说明 |
| ---- | ---- |
| `openclaw-<id>` | Gateway 主服务，长期运行 |
| `openclaw-<id>-cli` | CLI 工具容器，按需启动（`profiles: ["cli"]`） |

### Gateway 服务

- `init: true` — 正确处理僵尸进程
- `restart: unless-stopped` — 异常自动重启
- 健康检查：每 30s 访问 `/healthz`，超时 5s，最多重试 5 次，启动等待 20s

### CLI 服务

- 共享 Gateway 的网络命名空间（`network_mode: "service:openclaw-<id>"`）
- 安全加固：`cap_drop: [NET_RAW, NET_ADMIN]`，`no-new-privileges: true`
- 依赖 Gateway 健康后才可启动
- 仅在 `--profile cli` 时启动

## 安全说明

默认配置中启用了以下 Control UI 设置以方便 LAN 内访问：

| 设置 | 值 | 说明 |
| ---- | -- | ---- |
| `allowInsecureAuth` | `true` | 允许非 HTTPS 认证 |
| `dangerouslyDisableDeviceAuth` | `true` | 禁用设备级认证 |
| `dangerouslyAllowHostHeaderOriginFallback` | `true` | 允许 Host Header 作为 Origin 回退 |
| `allowedOrigins` | LAN IP + localhost + 127.0.0.1 | 限制允许的来源 |

> 如果部署在公网环境，强烈建议关闭 `dangerouslyDisableDeviceAuth` 并配置 HTTPS 反向代理。

## 注意事项

- **每个 channel bot 只能被一个实例使用**。同一个 Telegram bot token 不能同时给两个实例，否则会冲突。
- Gateway Token 用于访问 Control UI 和 API 认证，请妥善保管。
- 容器以 `node` 用户（uid 1000）运行，`setup.sh` 会自动修复目录权限。
- 默认配置使用 vLLM 后端，如需使用 OpenAI / Anthropic 等其他 Provider，请修改 `openclaw.json` 或设置对应环境变量。
- 如需 sandbox 功能，参考主仓库文档 `docs/install/docker.md` 中的 sandbox 配置。
