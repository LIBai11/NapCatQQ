# NapCat Shell - Headless HTTP 集成说明

本文档演示了如何在 Windows 环境下，使用 NapCat Shell 的 headless（无窗口）模式，将其以 HTTP 服务集成到你的后端/服务中，自动生成配置、通过 API 获取二维码、监听登录状态，并使用 OneBot HTTP API。

---

## 1. 预备：构建（只需 Windows）

1. 在工程根目录执行（确保 pnpm 和 node 已安装）：

```powershell
pnpm build:shell
```

2. 构建完成后，shell 的可执行文件会输出到 `packages/napcat-shell/dist/napcat.mjs`，并且 `dist/config/` 下有默认配置。

3. **重要**：构建过程会自动复制运行时依赖（express、ws、silk-wasm）到 `dist/node_modules/`。如果你要分发 `dist/` 目录，请确保包含整个 `node_modules/` 文件夹。

---

## 2. 可选：设置环境变量（覆盖默认配置）

**QQ 路径**：启动脚本会自动从 Windows 注册表读取 QQ 安装路径并注入启动，**无需手动配置任何 QQ 相关路径**。

**可选**：WebUI 和 OneBot 配置：

```powershell
$env:NAPCAT_WEBUI_HOST = '0.0.0.0'
$env:NAPCAT_WEBUI_PORT = '6099'
$env:NAPCAT_WEBUI_TOKEN = 'a_strong_token_here'
$env:NAPCAT_ONEBOT_PORT = '3000'
$env:NAPCAT_ONEBOT_HOST = '127.0.0.1'
$env:NAPCAT_ONEBOT_TOKEN = 'onebot_api_token'
$env:NAPCAT_QUICK_ACCOUNT = '123456789'
```

> 优先级：环境变量 > 模板文件 (`*.template.json`) > 内置默认值。

---

## 3. 启动 NapCat（Headless 模式）

## 3. 启动 NapCat（Headless 模式）

### 使用启动脚本（推荐）

推荐使用项目中提供的脚本：

- `packages/napcat-shell-loader/start-headless.bat` - 注入式启动，自动进入 headless 模式

**重要说明**：
- ✅ **需要管理员权限**（脚本会自动请求提权）
- ✅ 自动从注册表检测 QQ 安装路径
- ✅ 使用相对路径，支持移动/重命名构建目录
- ✅ 注入式启动 QQ，无界面后台运行

运行示例：

```powershell
# 进入 loader 目录
cd packages/napcat-shell-loader

# 运行脚本（会自动请求管理员权限）
.\start-headless.bat
```

运行时，程序会：
- 自动创建配置文件 `webui.json` 和 `onebot11.json`（当 config 文件不存在时）；
- 如果存在模板文件 `webui.template.json` 或 `onebot11.template.json`，会基于模板生成；
- 若设置了环境变量，会覆盖模板/默认配置。
- 若设置了环境变量，会覆盖模板/默认配置。

---

## 4. 获取登录二维码（API）

我们在 `napcat-webui-backend` 中新增了二维码图片 API：

- POST/GET `/api/QQLogin/GetQRCodeImage` - 获取二维码图片（默认返回 base64 编码 JSON；加 `?format=png` 返回 PNG 流）
- POST `/api/QQLogin/GetQQLoginQrcode` - 返回二维码 URL（兼容旧 API）
- POST `/api/QQLogin/CheckLoginStatus` - 检查登录状态和二维码 URL

示例调用：

- 使用 curl 获取 base64JSON（默认）

```bash
curl -s http://127.0.0.1:6099/api/QQLogin/GetQRCodeImage | jq .
```

- 获取 PNG 文件（保存为 qrcode.png）：

```bash
curl -s -o qrcode.png "http://127.0.0.1:6099/api/QQLogin/GetQRCodeImage?format=png"
```

- 使用 PowerShell 获取并保存 PNG：

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:6099/api/QQLogin/GetQRCodeImage?format=png" -OutFile qrcode.png
```

API 返回示例（Base64 JSON）:

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "image": "<base64...>",
    "url": "https://...",
    "timestamp": 168..., 
    "expiresIn": 120
  }
}
```

> 注意：二维码会在过期后自动刷新（内部监听 `onQRCodeSessionFailed` 事件），客户端需要定期轮询 `CheckLoginStatus` 或 `GetQRCodeImage` 来获取新二维码。

---

## 5. 登录与快速登录

- 若你使用快速登录 (已登录的历史账号)
  - `POST /api/QQLogin/SetQuickLogin`  body: `{ "uin": "123456" }`

- 检查登录状态：`POST /api/QQLogin/CheckLoginStatus` 返回: `{ isLogin: boolean, qrcodeurl: string }`

- 登录成功后，`WebUiDataRuntime.setQQLoginInfo` 被设置，WebUI 会反映状态。

---

## 6. OneBot HTTP 接口（消息 API）

OneBot11 的 HTTP 服务器默认监听 `127.0.0.1:3000`（可在 `config/onebot11.json` 或通过 `NAPCAT_ONEBOT_PORT` 覆盖），支持：

- POST/GET `http://host:port/<action>` 的 OneBot 标准 API（如 `/send_msg`、`/get_msg` 等）
- Token 验证：若配置 `token`，则需在请求头 `Authorization: Bearer <token>` 或查询参数 `?access_token=<token>` 中附带 token

示例（发送文本）:

```bash
curl -X POST "http://127.0.0.1:3000/send_msg" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <onebot-token>" \
  -d '{ "action": "send_msg", "params": { "message": "Hello" } }'
```

> 如果你没有设置 token，OneBot 将允许匿名请求（不建议在公网上使用）。

---

## 7. 配置说明与自定义

- 默认自动生成路径：`config/` （或 NapCat 的用户数据目录下 `config/`）
- 可用的模板文件：
  - `packages/napcat-shell-loader/webui.template.json`（WebUI 模板）
  - `packages/napcat-shell-loader/onebot11.template.json`（OneBot 模板）
- 你可以在分发包的 `dist/config/` 中直接修改或替换 `webui.json` 与 `onebot11.json`。
- 环境变量优先级最高，适合在容器或系统服务中覆盖配置。

### 通用字段快速说明

- `webui.json`  - host / port / token / autoLoginAccount
- `onebot11.json` - network.httpServers[0].port / host / token / enableCors

---

## 8. 日志与故障排查

- 日志位置（headless 模式）: `logs/napcat.log` 或 `logs/napcat-headless.log`（如果使用了 start-headless-background.bat）
- 检查 WebUI 监听端口：

```powershell
# Windows: 列出 6099 端口监听
netstat -ano | Select-String ":6099"
```

- 文件位置：
  - 二维码缓存: `{cachePath}/qrcode.png`（用于手动扫码）
  - 配置文件: `{configPath}/webui.json`, `{configPath}/onebot11.json`

- 如果二维码获取失败，请查看：
  - `logs/` 中的错误输出
  - 检查 `npm run build:shell` 是否成功，确认 `dist` 的内容完整

---

## 9. 示例客户端（Node.js）

保存为 `fetch_qrcode.js`：

```js
const fetch = require('node-fetch');
const fs = require('fs');

(async () => {
  const res = await fetch('http://127.0.0.1:6099/api/QQLogin/GetQRCodeImage');
  const data = await res.json();
  const base64 = data.data.image;
  const buffer = Buffer.from(base64, 'base64');
  fs.writeFileSync('./qrcode.png', buffer);
  console.log('qrcode saved');
})();
```

运行：

```powershell
node fetch_qrcode.js
# 然后打开 qrcode.png 扫码
```

---

## 10. 常见问题

- 如果没有在 `GetQRCodeImage` 中获取到二维码：请确认 WebUI 的 `GET/POST /api/QQLogin/GetQRCodeImage` 返回的 `url` 非空，同时检查 `cache/qrcode.png` 是否存在。
- 如果端口冲突导致服务无法启动：当前实现没有自动端口递增（后续会添加），建议手动修改 `webui.json` 或使用环境变量 `NAPCAT_WEBUI_PORT`。
- 如果 OneBot 请求返回 403：请确认 OneBot 的 `token` 设置一致并在请求头或 query 参数中传递。

---

## 11. 后续改进建议（可选）

- 增加端口冲突自动重试（尝试递增绑定），并将实际端口写入 runtime 文件
- 增加 `/api/Health` 健康检查端点
- 增加日志轮转和保留策略（按天或按大小）
- 制作 Windows 服务包装器或 NSSM 支持

---

如果你需要，我可以：
- 把这份文档写进 `packages/napcat-shell-loader/INTEGRATION.md`（已经创建）
- 添加示例的 curl 或 Node.js 脚本到 `packages/napcat-shell-loader/examples/`
- 实现端口自动递增和日志轮转

告诉我你想优先做什么，我将继续。