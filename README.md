# OpenClaw 多实例 Docker 部署

在同一台机器上运行多个独立的 OpenClaw 实例，每个实例拥有独立的配置、工作空间、凭据和会话。

## 前置要求

- Docker Engine 20.10+ 或 Docker Desktop
- Docker Compose v2
- 每个实例约 512MB RAM（建议总计 2GB+）

## 快速开始

```bash
cd deploy-multi

# 1. 创建 .env 并编辑
cp .env.example .env
# 编辑 .env，填入 API key 和 channel token

# 2. 初始化（创建目录、生成 token、拉取镜像）
bash setup.sh

# 3. 启动所有实例
docker compose up -d
```

## 目录结构

```
deploy-multi/
├── docker-compose.yaml
├── .env.example
├── .env                    # 你的实际配置（git ignored）
├── setup.sh
├── README.md
└── instances/              # setup.sh 自动创建
    ├── a/
    │   ├── config/         # openclaw.json, credentials, agents...
    │   └── workspace/      # AGENTS.md, SOUL.md, skills...
    ├── b/
    │   ├── config/
    │   └── workspace/
    └── c/
        ├── config/
        └── workspace/
```

## 端口映射

| 实例 | Gateway (WS + HTTP) | Bridge | Control UI             |
| ---- | ------------------- | ------ | ---------------------- |
| A    | 18789               | 18790  | `http://<host>:18789/` |
| B    | 28789               | 28790  | `http://<host>:28789/` |
| C    | 38789               | 38790  | `http://<host>:38789/` |

端口可在 `.env` 中自定义（`OPENCLAW_A_GATEWAY_PORT` 等）。

## 实例隔离

| 维度          | 隔离方式                                   |
| ------------- | ------------------------------------------ |
| 配置          | 各自 `instances/<id>/config/openclaw.json` |
| 凭据          | 各自 `instances/<id>/config/credentials/`  |
| 会话          | 各自 `instances/<id>/config/agents/`       |
| 工作空间      | 各自 `instances/<id>/workspace/`           |
| 网络端口      | 各自不同宿主机端口，容器内都是 18789       |
| Gateway Token | 各自独立的 `OPENCLAW_*_GATEWAY_TOKEN`      |
| Channel Bot   | 各自独立的 bot token                       |

## 配置实例

### 方式一：环境变量（推荐）

编辑 `.env`，OpenClaw 的 channel token 环境变量优先级高于配置文件：

```env
OPENCLAW_A_OPENAI_API_KEY=sk-xxx
OPENCLAW_A_TELEGRAM_BOT_TOKEN=123456:ABCDEF
```

### 方式二：直接编辑配置文件

```bash
# 编辑实例 A 的配置
vim instances/a/config/openclaw.json
```

示例配置：

```json
{
  "gateway": {
    "mode": "local",
    "bind": "lan"
  },
  "agent": {
    "model": "openai/gpt-4o"
  },
  "channels": {
    "telegram": {
      "botToken": "123456:ABCDEF"
    }
  }
}
```

### 方式三：通过 CLI onboard（交互式）

```bash
docker compose run --rm openclaw-a \
  node dist/index.js onboard --mode local --no-install-daemon
```

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

## 增减实例

在 `docker-compose.yaml` 中复制一个实例块（gateway + cli），修改：

1. 服务名：`openclaw-d` / `openclaw-d-cli`
2. `container_name`
3. 环境变量前缀：`OPENCLAW_D_*`
4. volumes 路径：`./instances/d/...`
5. 端口映射：`48789:18789` / `48790:18790`

在 `.env` 中添加对应的 `OPENCLAW_D_*` 变量，然后重新运行 `setup.sh`。

## 注意事项

- **每个 channel bot 只能被一个实例使用**。同一个 Telegram bot token 不能同时给两个实例，否则会冲突。
- Gateway token 用于访问 Control UI 和 API 认证，请妥善保管。
- `setup.sh` 可以重复运行，只会补充缺失的目录和 token，不会覆盖已有配置。
- 容器以 `node` 用户（uid 1000）运行，`setup.sh` 会自动修复目录权限。
- 如需 sandbox 功能，参考主仓库文档 `docs/install/docker.md` 中的 sandbox 配置。


| 实例 | 序号 | Gateway | Bridge | user |
| ---- | ---- | ------- | ------ | ---- |
| A    | 1    | 40100   | 40101  |      |
| B    | 2    | 40200   | 40201  |      |
| C    | 3    | 40300   | 40301  |      |
| D    | 4    | 40400   | 40401  |      |
| E    | 5    | 40500   | 40501  |      |
| F    | 6    | 40600   | 40601  |      |
| G    | 7    | 40700   | 40701  |      |
| H    | 8    | 40800   | 40801  |      |
| I    | 9    | 40900   | 40901  |      |
| J    | 10   | 41000   | 41001  |      |
| K    | 11   | 41100   | 41101  |      |
| L    | 12   | 41200   | 41201  |      |
| M    | 13   | 41300   | 41301  |      |
| N    | 14   | 41400   | 41401  |      |
| O    | 15   | 41500   | 41501  |      |
| P    | 16   | 41600   | 41601  |      |
| Q    | 17   | 41700   | 41701  |      |
| R    | 18   | 41800   | 41801  |      |
| S    | 19   | 41900   | 41901  |      |
| T    | 20   | 42000   | 42001  |      |
| U    | 21   | 42100   | 42101  |      |
| V    | 22   | 42200   | 42201  |      |
| W    | 23   | 42300   | 42301  |      |
| X    | 24   | 42400   | 42401  |      |
| Y    | 25   | 42500   | 42501  |      |
| Z    | 26   | 42600   | 42601  |      |
