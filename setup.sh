#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INSTANCES=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")
INSTANCES_UPPER=("A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z")
IMAGE="${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}"

GATEWAY_PORTS=(40100 40200 40300 40400 40500 40600 40700 40800 40900 41000 41100 41200 41300 41400 41500 41600 41700 41800 41900 42000 42100 42200 42300 42400 42500 42600)

# ---- vLLM Configuration ----
VLLM_BASE_URL="https://127.0.0.1:8080"
VLLM_MODEL_NAME="qwen"
VLLM_API_KEY="dummy"

# ---- Force overwrite config ----
FORCE_CONFIG="${FORCE_CONFIG:-false}"
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE_CONFIG=true
  echo "==> Force mode: will overwrite all openclaw.json configs"
fi

fail() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"
}

gen_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_hex(32))"
  else
    fail "Need openssl or python3 to generate tokens"
  fi
}

# ---- Detect LAN IP for allowedOrigins ----
detect_lan_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)" || true
  fi
  if [[ -z "$ip" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')" || true
  fi
  if [[ -z "$ip" ]] && command -v ifconfig >/dev/null 2>&1; then
    ip="$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')" || true
  fi
  if [[ -z "$ip" ]]; then
    echo "0.0.0.0"
  else
    echo "$ip"
  fi
}

LAN_IP="${OPENCLAW_LAN_IP:-$(detect_lan_ip)}"
echo "==> Detected LAN IP: ${LAN_IP}"

require_cmd docker
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 required"

echo "==> Creating instance directories"
for inst in "${INSTANCES[@]}"; do
  mkdir -p "instances/$inst/config/identity"
  mkdir -p "instances/$inst/config/agents/main/agent"
  mkdir -p "instances/$inst/config/agents/main/sessions"
  mkdir -p "instances/$inst/config/credentials"
  mkdir -p "instances/$inst/workspace"
done

echo "==> Preparing .env"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "    Created .env from .env.example"
fi

fill_token() {
  local key="$1"
  local current
  current="$(grep "^${key}=" .env 2>/dev/null | head -1 | cut -d= -f2-)"
  if [[ -z "$current" ]]; then
    local token
    token="$(gen_token)"
    if grep -q "^${key}=" .env 2>/dev/null; then
      sed -i.bak "s|^${key}=.*|${key}=${token}|" .env && rm -f .env.bak
    else
      echo "${key}=${token}" >> .env
    fi
    echo "    Generated token for $key"
  fi
}

for inst_upper in "${INSTANCES_UPPER[@]}"; do
  fill_token "OPENCLAW_${inst_upper}_GATEWAY_TOKEN"
done

echo "==> Setting default OPENAI_API_KEY for vLLM instances"
for inst_upper in "${INSTANCES_UPPER[@]}"; do
  key="OPENCLAW_${inst_upper}_OPENAI_API_KEY"
  current="$(grep "^${key}=" .env 2>/dev/null | head -1 | cut -d= -f2-)"
  if [[ -z "$current" ]]; then
    if grep -q "^${key}=" .env 2>/dev/null; then
      sed -i.bak "s|^${key}=.*|${key}=${VLLM_API_KEY}|" .env && rm -f .env.bak
    else
      echo "${key}=${VLLM_API_KEY}" >> .env
    fi
    echo "    Set $key=dummy"
  fi
done

echo "==> Pulling image: $IMAGE"
docker pull "$IMAGE"

echo "==> Fixing directory permissions (container uid 1000)"
for inst in "${INSTANCES[@]}"; do
  docker run --rm \
    -v "$SCRIPT_DIR/instances/$inst/config:/data/config" \
    -v "$SCRIPT_DIR/instances/$inst/workspace:/data/workspace" \
    --entrypoint sh "$IMAGE" -c \
    'chown -R 1000:1000 /data/config /data/workspace'
done

echo "==> Seeding default configs (vLLM @ ${VLLM_BASE_URL}, model: ${VLLM_MODEL_NAME})"
for i in "${!INSTANCES[@]}"; do
  inst="${INSTANCES[$i]}"
  port="${GATEWAY_PORTS[$i]}"
  config_file="instances/$inst/config/openclaw.json"
  need_write=false

  if [[ ! -f "$config_file" ]]; then
    need_write=true
  elif grep -q '"agent"' "$config_file" 2>/dev/null && ! grep -q '"agents"' "$config_file" 2>/dev/null; then
    echo "    WARNING: instances/$inst/config/openclaw.json uses legacy format, overwriting..."
    need_write=true
  fi

  # Auto-upgrade: detect missing LAN-access keys
  if [[ "$need_write" == "false" && -f "$config_file" ]]; then
    if ! grep -q '"dangerouslyDisableDeviceAuth"' "$config_file" 2>/dev/null; then
      echo "    UPGRADE: instances/$inst/config/openclaw.json missing dangerouslyDisableDeviceAuth, overwriting..."
      need_write=true
    elif ! grep -q '"allowedOrigins"' "$config_file" 2>/dev/null; then
      echo "    UPGRADE: instances/$inst/config/openclaw.json missing allowedOrigins, overwriting..."
      need_write=true
    fi
  fi

  # Force mode
  if [[ "$FORCE_CONFIG" == "true" ]]; then
    need_write=true
  fi

  if [[ "$need_write" == "true" ]]; then
    cat > "$config_file" <<JSON
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
        "http://${LAN_IP}:${port}",
        "http://localhost:${port}",
        "http://127.0.0.1:${port}"
      ]
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "vllm": {
        "baseUrl": "${VLLM_BASE_URL}/v1",
        "apiKey": "${VLLM_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "${VLLM_MODEL_NAME}",
            "name": "${VLLM_MODEL_NAME}",
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
        "primary": "vllm/${VLLM_MODEL_NAME}"
      }
    }
  }
}
JSON
    docker run --rm \
      -v "$SCRIPT_DIR/instances/$inst/config:/data" \
      --entrypoint sh "$IMAGE" -c 'chown 1000:1000 /data/openclaw.json'
    echo "    Seeded instances/$inst/config/openclaw.json (origin: http://${LAN_IP}:${port})"
  else
    echo "    instances/$inst/config/openclaw.json already exists, skipping"
  fi
done

echo ""
echo "============================================================"
echo "  Setup complete!"
echo "============================================================"
echo ""
echo "  LAN IP        : ${LAN_IP}"
echo "  vLLM endpoint : ${VLLM_BASE_URL}"
echo "  Model name    : ${VLLM_MODEL_NAME}"
echo ""
echo "Next steps:"
echo ""
echo "  1. (Optional) Edit .env — channel tokens, custom settings"
echo ""
echo "  2. (Optional) Edit each instance config:"
for inst in "${INSTANCES[@]}"; do
  echo "     instances/$inst/config/openclaw.json"
done
echo ""
echo "  3. Start all instances:"
echo "     docker compose up -d"
echo ""
echo "  4. Access Control UI from LAN (append #token=<TOKEN> on first visit):"
for i in "${!INSTANCES_UPPER[@]}"; do
  echo "     Instance ${INSTANCES_UPPER[$i]}: http://${LAN_IP}:${GATEWAY_PORTS[$i]}/#token=\$OPENCLAW_${INSTANCES_UPPER[$i]}_GATEWAY_TOKEN"
done
echo ""
echo "  Gateway tokens are in .env (OPENCLAW_*_GATEWAY_TOKEN)."
echo ""
echo "  TIP: If LAN IP was detected incorrectly, re-run with:"
echo "       OPENCLAW_LAN_IP=192.168.x.x ./$(basename "$0")"
echo ""
