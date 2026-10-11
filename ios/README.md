# ZCodeRemote for iOS

Android 版 [ZCodeRemote](../README.md) 的 iOS 适配。同一个 ZCode 手机远控网页，同一套注入式增强层，包装成 iOS App，面向越狱设备侧载分发（当前验证环境：Relaxin / RootHide 架构，iOS 16.5+）。

> ⚠️ 本应用**非智谱官方产品**，与 Z.ai / ZCode 官方无关，仅供个人使用与学习。远控链接即凭证，请勿分享本应用及其中保存的链接。

---

## 功能对照（Android → iOS）

| 能力 | Android | iOS 版状态 |
|---|---|---|
| 注入式增强层（8 模块 JS bundle） | evaluateJavascript 注入 | ✅ 同一份 `dev/bundle/*.js`，WKUserScript 全帧注入（documentStart 挂资源 + documentEnd 引导），由 `ios/tools/build_bundle.py` 与 Android 端同源生成 |
| 原生桥 `zcodeBridge` | `addJavascriptInterface`（同步） | ✅ `webkit.messageHandlers.zcodeBridge`（异步）+ `getTrace`/`getLogoPos` 预注入快照（见 [桥的实现差异](#桥的实现差异)） |
| 扫码进入 | zxing-android-embedded | ✅ AVFoundation 元数据识别 |
| 粘贴链接 / 最近会话 / 自动恢复 | SharedPreferences | ✅ UserDefaults，合并逻辑（mid/name 去重）一致 |
| 回复通知 | 通知渠道 + heads-up | ✅ UNUserNotificationCenter，前台也弹横幅 |
| 回复去重 | FNV-1a 64 + 7 天窗口 | ✅ 同算法移植（Swift `&*`/`^` 环绕运算） |
| 后台不断连 | 前台服务保活 | ✅ 静音音频保活（`UIBackgroundModes: audio`，设置可关、可选时长） |
| 键盘挡输入框 | v72 IME inset 垫底 | ✅ 复用注入层 `__zcodeSafeB` 机制：键盘期把让位高度写入 `__zcodeSafeB`，悬浮输入框抬到键盘上方 |
| 主题跟随 | onTheme/onBars → 系统栏取色 | ✅ 状态栏/导航栏样式与底色跟随 |
| 电池优化白名单引导 | Android 专属 | ➖ 无（iOS 由"后台保活"开关替代） |
| 悬浮 logo 拖动位置记忆 | getLogoPos/saveLogoPos | ✅ 桥保留（v81 起 logo 已移除，仅兼容旧桥） |
| 文字缩放 | WebView textZoom | ✅ `webkitTextSizeAdjust` 注入 |

## 桥的实现差异

Android 的 `addJavascriptInterface` 是**同步**调用；WKWebView 的 messageHandlers 是**异步单向**的。当前 v81 注入包实际用到的桥方法里，只有 `getTrace()`（诊断卡取原生埋点）需要返回值，处理方式：

1. 原生在 documentEnd 引导脚本里预注入快照 `window.__zcodeNativeTrace`；
2. 每次 `onReply`/`onProgress` 等事件后，原生用 `evaluateJavaScript` 刷新快照；
3. shim 的 `getTrace()` 直接读快照——毫秒级新鲜度，诊断卡展示够用。

其余方法（`onReply` / `onProgress` / `onTheme` / `onBars` / `saveLogoPos` / `setGestureExclude`）都是 fire-and-forget，直接映射到 `webkit.messageHandlers.zcodeBridge.postMessage({fn, args})`。`setGestureExclude` 在 iOS 上无意义（无系统返回手势冲突），接受即忽略。

## 构建

iOS 构建在 GitHub Actions（macOS runner）完成，Windows 本地无 Xcode：

```bash
git clone https://github.com/liudubin/zcode-remote.git
cd zcode-remote
python3 _patch_web2.py            # 重拼 Android 端注入包（iOS 同源校验用）
python3 _validate.py
python3 ios/tools/build_bundle.py # 生成 ios/App/Resources/ZCodeBundle.js（生成物，勿手改）
brew install xcodegen ldid        # 仅 macOS 需要
cd ios && xcodegen generate
xcodebuild -project ZCodeRemote.xcodeproj -scheme ZCodeRemote \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

或直接推送到仓库，CI（`.github/workflows/ios.yml`）自动产出两个 artifact：

- `ZCodeRemote-unsigned.ipa` —— 未签名 IPA（ldid 假签），适合 TrollStore 或越狱设备直装
- `com.zcode.remote_*_iphoneos-arm64e.deb` —— **roothide scheme** deb（Architecture `iphoneos-arm64e`，相对路径 `Applications/ZCodeRemote.app` 由 RootHide dpkg 映射到 `/var/jb`，postinst 自动 uicache 注册图标），适合 Sileo/命令行 `dpkg -i` 安装

## 安装（Relaxin / RootHide 设备）

1. 从 Actions 构建下载 `ZCodeRemote-ios` artifact；
2. deb 拷进手机，Sileo 直接打开安装，或 `dpkg -i xxx.deb`（RootHide 自带 dpkg 会映射路径）；
3. 桌面出现 ZCodeRemote 图标（postinst 已自动 uicache，没有的话手动 `uicache -p /var/jb/Applications/ZCodeRemote.app`）；
4. 打开 App，扫描桌面端 ZCode 左下角「手机图标」的二维码进入。

IPA + AppSync 类插件的直装路径同样可用（ldid 假签在越狱设备上可直接运行）。

## 工程结构

```
ios/
├── project.yml              # xcodegen 工程描述（CI 上生成 .xcodeproj，不提交生成物）
├── tools/
│   ├── build_bundle.py      # dev/bundle/ + WebActivity.kt CSS → ZCodeBundle.js（与 Android 同源）
│   ├── make_deb.py          # 纯 Python 打 roothide deb（不依赖 dpkg-deb）
│   └── make_icon.py         # 生成 1024 图标（本地一次性）
└── App/
    ├── Sources/             # Swift 源码（UIKit，min iOS 15）
    │   ├── AppDelegate.swift / Theme.swift
    │   ├── EntryViewController.swift      # 入口：扫码/粘贴/最近会话/自动恢复
    │   ├── WebViewController.swift        # 核心：WKWebView + 注入 + 桥 + 键盘/安全区 + 导航策略
    │   ├── SettingsViewController.swift   # 设置（变更即时热更新页面）
    │   ├── QRScannerViewController.swift  # 扫码
    │   ├── RecentStore / SettingsStore / ReplyDedupe / Trace / KeepAlive
    └── Resources/
        ├── ZCodeShim.js     # 桥 shim（异步映射 + 同步快照）
        ├── ZCodeBundle.js   # 生成物（build_bundle.py 产出，gitignore）
        └── Assets.xcassets  # AppIcon
```

## 已知取舍（v0.0.2-ios1）

- **后台保活**用静音音频方案：状态栏可能有电量感知、部分系统版本会限制后台音频时长（实测越狱设备上稳定）；设置里可关。
- **前台横幅**：通知权限未授予时，前台回复只在通知中心列表可见（iOS 无 Android 的 Toast 等价物，暂未做应用内横幅）。
- **getTrace 快照**新鲜度受主帧 evaluateJavaScript 时机影响，iframe 内的诊断卡可能读到旧值。
- 竖屏锁定（Android 版同样以竖直布局设计）。
