# Gapfill — Mind the Gap

> A tiny menu-bar English practice app. Fill the missing word, check the sentence meaning, and let short idle moments turn into vocabulary review.

空闲一段时间后，屏幕右上角弹出一道填空练习：一句英文挖掉一个词，配上整句中文翻译，让你填对应的英文单词。练习记录会持久化，**经常做错的题会更频繁地推给你**。

## 截图

<table>
  <tr>
    <td align="center"><b>菜单栏入口</b></td>
    <td align="center"><b>答对效果</b></td>
    <td align="center"><b>显示答案</b></td>
  </tr>
  <tr>
    <td><img src="assets/screenshot-menu.png" width="220"/></td>
    <td><img src="assets/screenshot-correct.png" width="220"/></td>
    <td><img src="assets/screenshot-answer.png" width="220"/></td>
  </tr>
</table>

## 功能

- 🕐 **空闲检测**：无键盘/鼠标操作超过 10 分钟后自动弹题（可调）
- 📖 **整句翻译**：卡片下方显示完整中文翻译，而非单词释义
- 🧠 **加权选题**：常错的题权重更高，掌握后逐渐淡出（Leitner 算法）
- ⌨️ **即时聚焦**：弹出后输入框自动获焦，直接打字即可
- 🤖 **AI 出题**：后台调用 Codex CLI 实时生成新题，内置 16 道题保底
- 📊 **今日统计**：菜单栏实时显示题数与正确率
- 💾 **进度持久化**：重启后仍记得"这道我以前错过"

## 系统要求

| 项目 | 要求 |
|------|------|
| macOS | 13.0 Ventura 及以上 |
| 架构 | Apple Silicon（arm64） |
| Codex CLI | 可选，用于 AI 生成新题 |

## 安装与运行

### 方案 A：Swift Package Manager（无需 Xcode）

```bash
git clone https://github.com/feng-Qinyu/EnglishCloze.git
cd EnglishCloze
swift build -c release
```

构建完成后创建 app bundle：

```bash
APP="$HOME/Applications/EnglishCloze.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/EnglishCloze "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --deep --sign - "$APP"
```

### 方案 B：XcodeGen（需要 Xcode）

```bash
brew install xcodegen
./build.sh        # 生成工程并打开 Xcode
# 在 Xcode 里按 Cmd-R 运行
```

### 设置为开机启动（推荐）

```bash
# 创建 LaunchAgent（开机自动启动）
cat > ~/Library/LaunchAgents/com.example.EnglishCloze.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.EnglishCloze</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/EnglishCloze.app/Contents/MacOS/EnglishCloze</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.example.EnglishCloze.plist
```

> **macOS 安全提示**：如果 Finder 双击无反应，通过终端启动一次：  
> `open /Applications/EnglishCloze.app`  
> 或使用上方的 LaunchAgent 方案（推荐，完全绕开 Gatekeeper）。

## 使用说明

启动后菜单栏出现 📖 图标，点击展开菜单：

| 操作 | 说明 |
|------|------|
| **现在来一题** `⌘⇧E` | 立刻弹出一道题，不等空闲 |
| **暂停/开启自动弹出** | 临时关闭空闲检测 |
| **退出** `⌘Q` | 完全退出 |

卡片操作：

| 操作 | 说明 |
|------|------|
| 直接打字 | 弹出后输入框自动聚焦 |
| `Return` / 检查 | 提交答案 |
| 看答案 | 显示正确答案（计入错误） |
| 再来一个 | 答完后立刻出下一题 |
| 稍后再说 | 关闭卡片，1 小时内不再自动弹 |

## 可调参数

| 文件 | 变量 | 默认值 | 说明 |
|------|------|--------|------|
| `Coordinator.swift` | `idleThreshold` | `600` | 多少秒空闲后弹题（调成 `15` 方便调试） |
| `Coordinator.swift` | `cooldown` | `45` | 答完一题后的冷却时间（秒） |
| `CodexGenerator.swift` | `codexPath` | `/opt/homebrew/bin/codex` | Codex CLI 路径（`which codex` 查看） |
| `CodexGenerator.swift` | `difficulty` | `intermediate, CET-6 / IELTS 6.0` | 出题难度（可改为「GRE 难词」「商务邮件高频词」等） |

## 项目结构

```
Sources/
├── EnglishClozeApp.swift   # 入口；菜单栏图标与下拉菜单
├── Coordinator.swift       # 空闲检测 → 决定何时弹卡
├── IdleMonitor.swift       # 用 CGEventSource 读系统空闲时长
├── PopupController.swift   # 右上角浮层面板（KeyablePanel 支持键盘输入）
├── ClozePopupView.swift    # 填空练习卡片 UI
├── ClozeModel.swift        # 卡片模型、内置题库、持久化、加权选题
└── CodexGenerator.swift    # 调 Codex CLI 后台生成新题
```

**数据存储**：`~/Library/Application Support/EnglishCloze/state.json`

## AI 出题（可选）

需要安装并登录 [Codex CLI](https://github.com/openai/codex)：

```bash
npm install -g @openai/codex
codex auth          # 登录 OpenAI
which codex         # 复制路径填入 CodexGenerator.swift 的 codexPath
```

未安装 Codex 时，app 使用内置 16 道题正常运行，不影响基础功能。

## License

MIT
