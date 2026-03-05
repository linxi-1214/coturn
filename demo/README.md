# Coturn Demo

本目录提供了一个开箱即用的 coturn TURN/STUN 服务器演示，涵盖三种常见的部署与认证模式。

> **English summary** at the [bottom of this file](#english-quick-start).

---

## 目录结构

```
demo/
├── README.md           # 本文件
├── turnserver.conf     # 最小化配置文件（长期凭证模式）
├── docker-compose.yml  # Docker Compose 一键启动
└── run_demo.sh         # 本地构建版本的演示脚本（自动测试三种场景）
```

---

## 方式一：Docker Compose（推荐，无需编译）

**前提条件：** 已安装 Docker 和 Docker Compose。

```bash
# 进入 demo 目录
cd demo

# 启动 coturn 服务器（后台运行）
docker compose up -d

# 查看日志
docker compose logs -f

# 停止服务
docker compose down
```

服务启动后，监听以下端口：

| 端口 | 协议 | 用途 |
|------|------|------|
| 3478 | UDP + TCP | STUN / TURN |

### 验证连通性

使用 Docker 内置的 `turnutils_stunclient` 验证 STUN：

```bash
docker run --rm --network=host coturn/coturn \
    turnutils_stunclient 127.0.0.1
```

使用 `turnutils_uclient` 测试 TURN 数据中继（长期凭证）：

```bash
docker run --rm --network=host coturn/coturn \
    turnutils_uclient \
      -n 5 -m 1 -l 100 \
      -u demo_user -w demo_pass \
      -e 127.0.0.1 -X -g \
      127.0.0.1
```

---

## 方式二：本地编译后运行演示脚本

### 1. 编译项目

```bash
# 在仓库根目录执行
./configure
make
```

或使用 cmake：

```bash
mkdir build && cd build
cmake ..
make -j$(nproc)
```

### 2. 运行 Demo 脚本

```bash
# 赋予执行权限
chmod +x demo/run_demo.sh

# 运行全部三个场景（推荐首次体验）
./demo/run_demo.sh

# 单独运行某个场景：
./demo/run_demo.sh --no-auth     # 无认证模式
./demo/run_demo.sh --lt-cred     # 长期凭证模式（用户名/密码）
./demo/run_demo.sh --rest-api    # TURN REST API（共享密钥）
./demo/run_demo.sh --stun        # 仅 STUN 绑定测试
```

脚本会自动启动服务器、运行对端监听进程、执行 TURN 数据中继测试，并在完成后清理进程。

---

## 方式三：直接使用配置文件启动服务器

```bash
# 使用 -c 指定配置文件
turnserver -c demo/turnserver.conf
```

`demo/turnserver.conf` 配置了以下内容：

| 参数 | 值 |
|------|----|
| 监听端口 | 3478 (UDP/TCP) |
| 中继端口范围 | 49152–65535 |
| 认证模式 | 长期凭证（用户名/密码） |
| 用户 | `demo_user` / `demo_pass` |
| 域 | `demo.example.com` |
| TLS/DTLS | 禁用（未配置证书） |
| 日志 | stdout，verbose |

启动后，用 `turnutils_uclient` 测试：

```bash
turnutils_uclient \
    -n 1000 -m 1 -l 170 \
    -u demo_user -w demo_pass \
    -e 127.0.0.1 -X -g \
    127.0.0.1
```

---

## 三种认证模式说明

### 1. 无认证模式（`--no-auth`）

最简单的模式，任何客户端均可连接，**仅用于开发/测试环境**。

```bash
turnserver --no-auth --no-tls --no-dtls \
    -L 0.0.0.0 --allow-loopback-peers --no-cli \
    --log-file=stdout
```

客户端不需要用户名和密码：

```bash
turnutils_uclient -n 100 -m 1 -e 127.0.0.1 -X -g 127.0.0.1
```

### 2. 长期凭证模式（`--lt-cred-mech`）

使用固定的用户名 + 密码进行认证，适合固定用户数量的场景。

```bash
turnserver --lt-cred-mech \
    --user=alice:password123 \
    --realm=mycompany.org \
    --no-tls --no-dtls \
    -L 0.0.0.0 --no-cli --log-file=stdout
```

客户端指定用户名和密码（`-u` / `-w`）：

```bash
turnutils_uclient \
    -u alice -w password123 \
    -n 100 -m 1 -e 127.0.0.1 -X -g \
    127.0.0.1
```

密钥形式（更安全，通过 `turnadmin` 生成）：

```bash
# 生成密钥
turnadmin -k -u alice -r mycompany.org -p password123
# 输出: 0xabc123...

# 在配置文件中使用密钥
user=alice:0xabc123...
```

### 3. TURN REST API（`--use-auth-secret`）

基于时效性凭证的认证，适合 WebRTC 应用。服务器与应用后端共享一个密钥（secret），应用后端为每个用户动态生成临时用户名和密码。

```bash
turnserver --use-auth-secret \
    --static-auth-secret=my_shared_secret \
    --realm=mycompany.org \
    --no-tls --no-dtls \
    -L 0.0.0.0 --no-cli --log-file=stdout
```

客户端使用 `-W` 传入共享密钥，`turnutils_uclient` 会自动计算临时凭证：

```bash
turnutils_uclient \
    -u demo_user -W my_shared_secret \
    -n 100 -m 1 -e 127.0.0.1 -X -g \
    127.0.0.1
```

**WebRTC 前端 ICE 服务器配置示例（JavaScript）：**

应用后端根据共享密钥动态生成如下 ICE 配置并返回给前端：

```javascript
// 后端生成（Node.js 示例）
const crypto = require('crypto');
const VALIDITY_SECONDS = 24 * 60 * 60; // 有效期 24 小时 / 24-hour validity
const unixTime = Math.floor(Date.now() / 1000) + VALIDITY_SECONDS;
const username = `${unixTime}:my_user_id`;
const credential = crypto
  .createHmac('sha1', 'my_shared_secret')
  .update(username)
  .digest('base64');

// 返回给前端的 ICE 配置
const iceServers = [
  {
    urls: 'turn:your-server-ip:3478',
    username: username,
    credential: credential,
  },
];
```

前端使用：

```javascript
const pc = new RTCPeerConnection({ iceServers });
```

---

## 启用 TLS/DTLS

生成测试证书：

```bash
cd examples/ca
./run.sh
```

然后在 `demo/turnserver.conf` 中取消注释并指向证书文件：

```ini
cert=../examples/ca/turn_server_cert.pem
pkey=../examples/ca/turn_server_pkey.pem
# 同时移除 no-tls 和 no-dtls 行
```

---

## 日志文件

`run_demo.sh` 运行后，日志保存在：

| 场景 | 日志路径 |
|------|---------|
| 无认证 | `/tmp/coturn_demo_noauth.log` |
| 长期凭证 | `/tmp/coturn_demo_ltcred.log` |
| REST API | `/tmp/coturn_demo_restapi.log` |
| STUN | `/tmp/coturn_demo_stun.log` |

---

## 常见问题

**Q: 端口已被占用？**

```bash
# 查找占用 3478 端口的进程
lsof -i :3478
```

**Q: 服务器位于 NAT/云主机后面？**

在 `turnserver.conf` 中设置：

```ini
external-ip=YOUR_PUBLIC_IP
```

或在命令行使用 `-X YOUR_PUBLIC_IP`。

**Q: 如何在生产环境中运行？**

参考 [docs/Configuration.md](../docs/Configuration.md) 中的完整配置参考，以及 [docker/coturn/README.md](../docker/coturn/README.md) 中的 Docker 部署指南。

---

## English Quick Start

```bash
# Option 1: Docker Compose (recommended, no compilation needed)
cd demo
docker compose up -d

# Option 2: Build from source, then run the demo script
./configure && make
chmod +x demo/run_demo.sh
./demo/run_demo.sh           # runs all three auth scenarios

# Option 3: Start server with demo config file directly
turnserver -c demo/turnserver.conf
# Then test with:
turnutils_uclient -n 1000 -m 1 -l 170 \
    -u demo_user -w demo_pass \
    -e 127.0.0.1 -X -g 127.0.0.1
```

See [docs/Configuration.md](../docs/Configuration.md) for the full configuration reference.
