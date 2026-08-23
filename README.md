# OpenCode 环境迁移（bootstrap）

把一台 x86-64 Linux 主机上的 OpenCode 运行环境，完整、可复现地搬到另一台同架构主机。覆盖：skills、全局指令（AGENTS.md）、opencode / quota 配置、quota 插件（含原生 better-sqlite3）、web 服务、systemd 常驻。

📚 配套文档（部署 / 性能排障 / 运维）：https://github.com/fewhg3yhjt/opencode-wiki-public

## 适用前提
- 目标机：x86-64 Linux（与源机架构一致；ARM 需改用官方按架构安装包）
- 目标机已 / 将由本脚本安装 opencode（npm 全局 `opencode-ai`，版本 1.18.x）
- 能访问 GitHub（skills / wiki 已 public，匿名 clone 即可）
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

## 用法
将本仓库传到目标机（任选其一）：`scp -r opencode-bootstrap 目标机:~/`、或 `git clone https://github.com/fewhg3yhjt/opencode-bootstrap.git`。然后：
```bash
cd opencode-bootstrap

# 可选：固定 web 密码（不填则自动生成随机密码并回显）
export OPCODE_PASSWORD=自定强密码

# 可选：指定文档仓（默认即下方 public 地址）
# export WIKI_REPO=https://github.com/fewhg3yhjt/opencode-wiki-public.git

./setup.sh
```
脚本幂等，可重复运行。

## 完整部署流程（新机从零到 web 可访问）
适用：一台干净的 x86-64 Linux（Ubuntu/Debian），具备 sudo 与联网。

```bash
# 1) 取仓库（public，可匿名 clone）
git clone https://github.com/fewhg3yhjt/opencode-bootstrap.git
cd opencode-bootstrap

# 2) （可选）固定 web 密码；不设则自动随机生成并回显
export OPCODE_PASSWORD='自定强密码'

# 3) 一键还原环境（幂等，可重跑）
./setup.sh
#    脚本依次：装 Node22 → 装 opencode → 写配置与 quota 插件 → 渲染 systemd → 拉起 web
#    末尾打印 web 用户名(opencode) 与密码
```

4) 验证服务
```bash
systemctl is-active opencode-web                # 期望 active
curl -u opencode:密码 http://127.0.0.1:4096/session   # 返回 JSON
```

5) 浏览器访问：`http://<服务器公网IP>:4096`，用户名 `opencode` + 上面密码。
   公网暴露务必用强密码；如需 HTTPS，前置 Caddy / Nginx 反代。

6) 配置模型 provider（各人自备 key）
   opencode 默认不带模型额度。把你的 provider 凭据放入 `~/.opencode-credentials`
   （或按对应 provider 的登录方式写入），web 界面才能调用模型。详见配套文档。

7) skills 默认已 clone 到 `~/.opencode-skills`；如需同步文档仓：
   `export WIKI_REPO=https://github.com/fewhg3yhjt/opencode-wiki-public.git`（默认即此）。

## 网络受限：GitHub 443 不通时怎么办
默认的 `git clone https://github.com/...` 走 HTTPS 443。若目标机连不上 `github.com:443`（常见于国内/受限网络，表现为 clone 卡在 `Cloning into...` 或报错 `Failed to connect to github.com port 443`），说明 HTTPS 不通——但 **SSH 的 22 端口通常放行**。改用以下任一方式：

### 方式 A：SSH clone（推荐，国内最稳）
1. 生成密钥——**文件名必须用默认 `id_ed25519`**，否则 git 不会自动使用它；生成时若设了 passphrase，clone 时会提示输入一次：
   ```bash
   ssh-keygen -t ed25519 -C "$(hostname)"
   ```
2. 把公钥 `~/.ssh/id_ed25519.pub` 内容加到你的 GitHub 账号：
   Settings → SSH and GPG keys → New SSH key（这是**账号级**设置，不是仓库级；整个过程不需要仓库主人提供任何私人信息）。
3. 测试并 clone：
   ```bash
   ssh -T git@github.com          # 应返回成功问候
   git clone git@github.com:fewhg3yhjt/opencode-bootstrap.git
   ```
   > 若私钥用了自定义文件名（如 `yes`），要么 `mv` 改成 `id_ed25519`，要么在 `~/.ssh/config` 写 `Host github.com` + `IdentityFile ~/.ssh/你的文件名`。

### 方式 B：GitHub 代理镜像（若目标机可访问镜像站）
```bash
git clone https://ghproxy.com/https://github.com/fewhg3yhjt/opencode-bootstrap.git
# 或 https://gitclone.com/github.com/fewhg3yhjt/opencode-bootstrap.git
```
镜像站可用性不稳定，按实际能连通的选。

### 方式 C：完全不依赖 GitHub（scp tarball）
若目标机与源机可 SSH 互访，直接取源机打包好的 tar 包：
```bash
scp user@<源机IP>:/path/opencode-bootstrap.tar.gz .
tar xzf opencode-bootstrap.tar.gz
cd opencode-bootstrap && ./setup.sh
```

## GitHub HTTPS 认证（踩坑）
本仓与 skills 均已 public，匿名 `git clone` 即可，无需认证。以下仅当你使用 **private** 仓时才需要：
- **Username**：GitHub 用户名（如 `fewhg3yhjt`）。
- **Password**：**不是 GitHub 登录密码**，必须用 Personal Access Token（PAT）——GitHub 自 2021 年起已停用密码认证 HTTPS git，用错会报 `403`。
- 避免反复输入：克隆前先 `git config --global credential.helper store`，凭据会缓存。
- 若目标机已配 SSH key 并加进 GitHub，可改用 `git clone git@github.com:fewhg3yhjt/opencode-bootstrap.git` 免密。

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
