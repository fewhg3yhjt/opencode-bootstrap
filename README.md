# OpenCode 环境迁移（bootstrap）

把一台 x86-64 Linux 主机上的 OpenCode 运行环境，完整、可复现地搬到另一台同架构主机。覆盖：skills、全局指令（AGENTS.md）、opencode / quota 配置、quota 插件（含原生 better-sqlite3）、web 服务、systemd 常驻。

📚 配套文档（部署 / 性能排障 / 运维）：https://github.com/fewhg3yhjt/opencode-wiki-public

## 适用前提
- 目标机：x86-64 Linux（与源机架构一致；ARM 需改用官方按架构安装包）
- 目标机已 / 将由本脚本安装 opencode（npm 全局 `opencode-ai`，版本 1.18.x）
- 已配置 GitHub SSH 访问（见下方「完整部署流程」第 1 步）
- 有 sudo 权限

## 本仓结构
```
opencode-bootstrap/
├── README.md                     # 本文件（迁移文档）
├── setup.sh                      # 一键还原脚本
├── config/
│   ├── opencode.jsonc            # 主配置（skills 路径 / plugin / compaction / models）
│   ├── tui.jsonc                 # TUI 配置（quota 插件）
│   ├── package.json              # 插件依赖（@slkiser/opencode-quota 等）
│   └── opencode-quota/
│       └── quota-toast.jsonc     # quota 插件配置
└── systemd/
    └── opencode-web.service      # web 服务 unit 模板
```

## 完整部署流程（新机从零到 web 可访问）
适用：一台干净的 x86-64 Linux（Ubuntu/Debian），具备 sudo 与联网。

```bash
# 1) 配置 GitHub SSH 访问（仅需一次）
ssh-keygen -t ed25519 -C "$(hostname)"      # 一路回车，生成 ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub                   # 复制输出内容
#   打开 GitHub → Settings → SSH and GPG keys → New SSH key → 粘贴保存
ssh -T git@github.com                       # 应返回成功问候

# 2) 取仓库
git clone git@github.com:fewhg3yhjt/opencode-bootstrap.git
cd opencode-bootstrap

# 3) （可选）固定 web 密码；不设则自动随机生成并回显
export OPCODE_PASSWORD='自定强密码'

# 4) 一键还原环境（幂等，可重跑）
./setup.sh
#    脚本依次：装 Node22 → 装 opencode → 写配置与 quota 插件 → 渲染 systemd → 拉起 web
#    末尾打印 web 用户名(opencode) 与密码
```

5) 验证服务
```bash
systemctl is-active opencode-web                # 期望 active
curl -u opencode:密码 http://127.0.0.1:4096/session   # 返回 JSON
```

6) 浏览器访问：`http://<服务器公网IP>:4096`，用户名 `opencode` + 上面密码。
   公网暴露务必用强密码；如需 HTTPS，前置 Caddy / Nginx 反代。

7) 配置模型 provider（各人自备 key）
   opencode 默认不带模型额度。把你的 provider 凭据放入 `~/.opencode-credentials`
   （或按对应 provider 的登录方式写入），web 界面才能调用模型。详见配套文档。

8) skills 默认已 clone 到 `~/.opencode-skills`；如需同步文档仓：
   `export WIKI_REPO=https://github.com/fewhg3yhjt/opencode-wiki-public.git`（默认即此）。

## setup.sh 做了什么
1. 克隆 `~/.opencode-skills`（全局 skill + AGENTS.md 指令）；可选克隆 `~/wiki`
2. 确保 Node ≥ 22（quota 插件硬要求，否则用 NodeSource 装 22）
3. 确保 opencode 已装（否则走 npmmirror 镜像 `npm install -g opencode-ai`）
4. 写入 `~/.config/opencode/` 下的配置（路径占位 `__HOME__` 渲染为 `$HOME`）
5. `npm install` 安装 quota 插件（better-sqlite3 为原生模块，需 build-essential + python3 本地编译）
6. 渲染 systemd unit 并 `enable --now` 拉起 web 服务

## 不迁移的内容（需手动处理）
- **provider 凭据**：`~/.opencode-credentials`（opencode-go 等认证）不在本仓，含密钥。目标机若要使用相同模型 provider，请单独 `scp` 该文件到目标机同路径，或重新登录获取凭据。
- **会话历史**：`~/.local/share/opencode/opencode.db` 不迁移，每台机器独立。
- **web 密码**：默认随机生成并回显；如要沿用旧密码，运行前 `export OPCODE_PASSWORD=旧密码`。密码不写进仓库。

## 兼容性注意
- 源机 opencode 1.18.19（独立二进制），目标机 1.18.21（npm 全局）。config schema 兼容；`package.json` 里 `@opencode-ai/plugin` 用 `^1.18.0` 宽松匹配。
- 若目标机 opencode 通过 npm 安装，unit 的 `ExecStart` 由脚本自动解析 `command -v opencode` 得到，不写死路径。
- 架构不同（如 ARM）时，npm 原生模块 better-sqlite3 仍可编译，但 opencode 二进制需官方按架构包；本脚本假设 x86-64。

## 验证
```bash
systemctl is-active opencode-web      # active
opencode session list                 # 能列出（空）
curl -u opencode:密码 http://127.0.0.1:4096/session   # 返回 JSON
```
浏览器开 `http://<目标机IP>:4096` 用用户名 `opencode` + 密码登录。

---
📚 完整文档（部署 / 性能 / 运维）：https://github.com/fewhg3yhjt/opencode-wiki-public
