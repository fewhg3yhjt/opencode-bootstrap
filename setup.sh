#!/usr/bin/env bash
# opencode-bootstrap: 在新主机还原与源机一致的 opencode 环境
# 用法:
#   git clone <this-repo> && cd opencode-bootstrap
#   [可选] export OPCODE_PASSWORD=旧密码   # 沿用旧密码; 不填则自动生成随机密码
#   [可选] export SKILLS_REPO=https://<PAT>@github.com/fewhg3yhjt/opencode-skills.git  # private 仓
#   [可选] export WIKI_REPO=https://<PAT>@github.com/fewhg3yhjt/opencode-wiki.git
#   ./setup.sh
set -euo pipefail

# 脚本自身所在目录（绝对路径），不依赖当前工作目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SKILLS_REPO="${SKILLS_REPO:-https://github.com/fewhg3yhjt/opencode-skills.git}"
WIKI_REPO="${WIKI_REPO:-}"
PORT="${OPCODE_PORT:-4096}"

USER_NAME="$(whoami)"
HOME_DIR="$HOME"

# 密码: 沿用请 export OPCODE_PASSWORD; 否则随机生成
if [ -n "${OPCODE_PASSWORD:-}" ]; then
  PASSWORD="$OPCODE_PASSWORD"
  echo "使用提供的 OPCODE_PASSWORD (沿用旧密码)"
else
  PASSWORD="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 24)"
  echo "未提供 OPCODE_PASSWORD, 已自动生成随机密码: $PASSWORD"
fi

command -v opencode >/dev/null 2>&1 && OPCODE_BIN="$(command -v opencode)" || OPCODE_BIN="/usr/bin/opencode"

echo "==> 1. 部署 skills / wiki"
if [ ! -d "$HOME/.opencode-skills" ]; then
  git clone "$SKILLS_REPO" "$HOME/.opencode-skills"
else
  echo "   ~/.opencode-skills 已存在, 跳过"
fi
if [ -n "$WIKI_REPO" ] && [ ! -d "$HOME/wiki" ]; then
  git clone "$WIKI_REPO" "$HOME/wiki"
fi

echo "==> 2. 确保 Node >= 22 (quota 插件要求)"
if ! node --version 2>/dev/null | grep -qE '^v(2[2-9]|[3-9][0-9])'; then
  echo "   安装 Node 22 ..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "==> 3. 确保 opencode 已安装"
if ! command -v opencode >/dev/null 2>&1; then
  sudo npm config set registry https://registry.npmmirror.com
  sudo npm install -g opencode-ai
fi
OPCODE_BIN="$(command -v opencode || echo /usr/bin/opencode)"

echo "==> 4. 写入配置"
mkdir -p "$HOME/.config/opencode/opencode-quota"
cp "$SCRIPT_DIR/config/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
cp "$SCRIPT_DIR/config/tui.jsonc" "$HOME/.config/opencode/tui.jsonc"
cp "$SCRIPT_DIR/config/opencode-quota/quota-toast.jsonc" "$HOME/.config/opencode/opencode-quota/quota-toast.jsonc"
cp "$SCRIPT_DIR/config/package.json" "$HOME/.config/opencode/package.json"
sed -i "s|__HOME__|$HOME|g" "$HOME/.config/opencode/opencode.jsonc"

echo "==> 5. 安装插件 (含 better-sqlite3 原生编译, 需 build 工具)"
sudo apt-get install -y build-essential python3 >/dev/null 2>&1 || true
cd "$HOME/.config/opencode"
npm config set registry https://registry.npmmirror.com >/dev/null 2>&1 || true
npm install

echo "==> 6. 部署 systemd 服务"
SYSTEMD_TPL="$SCRIPT_DIR/systemd/opencode-web.service"
if [ ! -f "$SYSTEMD_TPL" ]; then
  echo "错误: 未找到 systemd 模板 $SYSTEMD_TPL" >&2
  echo "请确认在仓库根目录运行, 且已完整 clone (仓库需含 systemd/opencode-web.service)" >&2
  echo "如 clone 不完整, 先: rm -rf opencode-bootstrap && git clone git@github.com:fewhg3yhjt/opencode-bootstrap.git" >&2
  exit 1
fi
sudo sed -e "s|__USER__|$USER_NAME|g" -e "s|__HOME__|$HOME_DIR|g" -e "s|__PASSWORD__|$PASSWORD|g" -e "s|__OPCODE_BIN__|$OPCODE_BIN|g" -e "s|__PORT__|$PORT|g" \
  "$SYSTEMD_TPL" > /etc/systemd/system/opencode-web.service
sudo systemctl daemon-reload
sudo systemctl enable --now opencode-web

echo "==> 完成. web 监听 $PORT, 用户名 opencode, 密码: $PASSWORD"
echo "    如需沿用旧密码, 重跑前: export OPCODE_PASSWORD=旧密码"
