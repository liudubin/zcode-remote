# Changelog

本项目的所有重要变更记录在此。版本号遵循语义化版本（受早期开发阶段约束，主版本固定为 0）。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/)。

## [Unreleased]

- feat(ios): UI v3 重设计「终端窗 · 霓虹」——新 App 图标（亮渐变底 + 深色终端窗卡 + 渐变 >_，Android mipmap/自适应同步重制）
- feat(ios): 全新色板（墨绿黑 + 电光绿→青渐变），入口页重构（品牌头部/渐变扫码 CTA/链接卡片/会话列表状态点）
- feat(ios): 设置页左缘主色图标芯片 + 品牌绿分区头；扫码页取景框四角括号 + 玻璃提示卡；会话页 topBar 品牌状态点
- feat(ios+bundle): 会话页自定义背景——设置「个性化」选图（PHPicker 免权限）/压暗 4 档/一键清除；压暗原生烘焙进图，注入层 `07b_wallpaper` 把 html 背景铺图 + 消息区透明化，气泡表面色保留保证可读；`__zcSettings.wpImage/wpDim` 引导注入 + applySettings 热切换（9 模块重拼，Android 嵌入同步 patch，键缺失自动 no-op）

## [v0.0.2-ios67 · iOS] — 2026-10-10

- 例行构建发布
## [v0.0.2-ios69 · iOS] — 2026-10-10

- fix(ios): 升级自动重置诊断档位——注入档位回'完整'、解除禁用注入,避免困在诊断模式
## [v0.0.2-ios71 · iOS] — 2026-10-10

- feat(ios): 注入诊断升级 DOM 取证——dock/composer/消息行存在性、页面全部 data-testid 清单、zcode 状态类、floatOn
## [v0.0.2-ios75 · iOS] — 2026-10-10

- fix(ios): os_log 无插值字符串不能带 privacy 参数
- fix(ios): WebContent 进程被杀后整页重载——恢复的页面不重跑注入脚本,增强层凭空消失的根因
## [v0.0.2-ios76 · iOS] — 2026-10-11

- 例行构建发布
## [v0.0.2-ios81 · iOS] — 2026-10-11

- feat(ios): 移除注入档位/禁用开关字段
- feat(ios): 设置页随强制禁用精简,移除注入相关开关
- feat(ios): 强制禁用注入增强层——回归纯 WebView 壳,只保留文字缩放
## [v0.0.2-ios83 · iOS] — 2026-10-11

- fix(deb): postinst 升级时先 uicache -u 注销再 -p 注册,强制刷新主屏图标缓存
## [v0.0.2-ios88 · iOS] — 2026-10-11

- fix(ios): lastWebkillAt 挪回类主体(extension 不能有存储属性)
- feat(ios): 设置页恢复诊断入口(纯原生事件,不依赖注入)
- feat(ios): 导航事件进诊断(loaded/loadfail/retry/webkill)+进程被杀重载 10s 节流防循环白屏
## [v0.0.2-ios90 · iOS] — 2026-10-11

- feat(ios): 回挂桥 shim(仅错误上报不碰页面)——纯 WebView 白屏时页面侧 JS 错误可见;doc:readyState 心跳
## [v0.0.2-ios95 · iOS] — 2026-10-11

- revert(ios): 恢复注入档位/禁用字段与诊断重置迁移(ios75 版)
- revert(ios): 设置页恢复注入相关开关(ios75 版)
- revert(ios): 回退强制禁用——恢复注入增强层(延迟注入+noBroadcast+快照),回到 ios75 验证可用形态
## [v0.0.2-ios97 · iOS] — 2026-10-11

- feat(ios): 最近会话改左滑删除——自绘卡片列表换 UITableView(原生 trailing swipe action,点按进入),顺带根除自绘卡片点击/手势兼容问题
## [v0.0.2-ios103 · iOS] — 2026-10-11

- fix(ios): 入口页左上角徽标从 ⚡ emoji 换成与新 App 图标同款的 >_ 渐变符号
- icon: IconSymbol imageset 清单
- icon: 入口页徽标符号 @3x
- icon: 入口页徽标符号 @2x
- build(icon): 附产透明底 >_ 符号 imageset(入口页徽标用);路径改 pathlib 消除 ../ 形态
## [v0.0.2-ios105 · iOS] — 2026-10-26

- fix(ios): 重新登录登不上根修——WKUIDelegate 承载 OAuth 弹窗、放行登录 IdP 域、Safari UA、主帧 HTTP 错误接管、语言前缀远控链接判定
## [v0.0.2-ios115 · iOS] — 2026-11-27

- fix: constraint(greaterThanOrEqualTo/lessThanOrEqualTo) — correct anchor factory names
- fix: SettingsCell API misuse — anchor constraints, removeAction(for:), insertSegment
- fix: Swift compile errors — stored props out of extensions, missing framework imports
- fix: extension deinit moved to class body + CI pillow PEP668 + smoke pipefail
- UI v3: terminal-window neon redesign + wallpaper + icon v3
## [v0.0.2-ios119 · iOS] — 2026-11-27

- fix(ui): composer input focus after preventDefault + GPU morph animation (v81 patch via CI)
- fix: QR scanner never started session (lost wiring in refactor) + stop camera on close
- fix: entry button icon misalignment + settings crash on missing cell registration
## [v0.0.2-ios121 · iOS] — 2026-11-28

- fix: wallpaper & settings never applied on first page load (bootstrap overwrote ZSET after bundle init)
## [未发布] — v81 工作区（bundleVer 58）

v80 实机二验三条反馈的修复轮：两条居中根修 + 两个功能整套删除。

- **⑦ ↓ 圆钮"不居中"根修——translate 属性与 transform 属性叠加**：Tailwind v4 的 `-translate-x-1/2` 编译成**独立 CSS `translate` 属性**（不是 transform），z.ai 的 ↓ 钮水平居中靠它；v80 的避让规则写的是 `transform: translate(-50%, …)`，两属性**叠加生效** → 二次左移半个钮宽（14px，实机截图偏左量与理论值精确吻合）。规则改为只写 Y 分量 `translateY(calc(-6px - var(--zc-safe-b)))`，水平完全不碰
- **全屏（半屏）输入面板"不居中"中和**：注入层全屏几何本是对称（inset 0 + flex 居中 + 宽 min(94vw,640px)），偏移来自 z.ai 原生 dock 内层（`[data-v4-composer-dock-content]`）在全屏态残留的 padding/margin——float/full 两态一并归零并补 `width:100%`（对齐真页 w-full，dock 是 flex 缺了它内容层 shrink-to-fit 塌缩），全屏面板另加 `margin-inline:auto` 强制居中；dock 自身 `translate:none` 与 `transform:none` 并列（同源教训：位移工具类走 translate 属性，transform 归零拦不住）
- **② 图标双击直进全屏：整套删除**（用户淘汰，"跟单击抢同一手势，真机做不稳"）：双击判定分支、`lastIconTapAt/XY`、`ensureIcon` 的 520ms 隐形宽限 hack、遮罩落点回退（05_nav）、`whenMorphDone` 帮手函数全链路移除；图标回归"唤出即隐"，双击第二击落遮罩=收起（点外部语义，不再误进全屏）
- **③ 键盘跟随·实验：整套删除**（用户淘汰，"收益从未被实机证明，两轮翻车"）：JS 侧 `calcKbLift/applyKbLift/setKbH/__zcKb` 桥、visualViewport 兜底、`zc-kb-on` CSS 规则、`kbCalls/kbAgo` 埋点、设置开关（Kotlin `reportKb`/insets 分支/PageSettings/设置页/XML/strings）、mock f_kb 全链路移除；WebView 恢复 v72 行为（IME inset 垫 content，页面自己坐到键盘上方）。`kbFollowExp` 注入键退役（旧存档多出的键无害）；mock ↓ 钮居中改 `translate:-50%` 属性（Tailwind v4 真页同构）并新增带恶意不对称 padding 的 dock-content 包装层（验证中和规则）
- mock 回归全绿：↓ 钮中心 341.3 vs 视口中心 341.5（safeB=26 时恰抬 32px、X 不动）、悬浮胶囊/全屏面板居中顶着恶意 padding 通过、双击不进全屏、发送归位①（contenteditable 路径）、AMOLED 热更、零 jsErrors

## [未发布] — v80 工作区（bundleVer 57）

v79 实机首验四条反馈的修复轮。

- **⑧ 长按消息菜单：整套删除**（用户淘汰）：bundle 手势/动作条/复制引用、设置开关（Kotlin/XML/strings）、注入键、诊断字段、mock 钩子全链路移除
- **① 发送后归位真机失效根修**：实机诊断 `dockHtml` 实锤 z.ai 输入区是 **Lexical contenteditable div**（`data-lexical-editor`），不是 textarea——v79 的输入跟踪只认 `TEXTAREA/INPUT.value`，真机上 `sendHadText` 永假、①从不触发（mock 用 textarea 所以本地全绿，又一次"mock 同构性"教训）。文本读取改双形态兼容（`.value` / `.textContent`），事件过滤放宽 contenteditable；mock 输入区同步换 contenteditable
- **② 双击直进全屏加宽**：窗口 330→500ms、tap 位移容差 10→14px（真机手指起落天然漂移十几像素，mock 合成事件零漂移测不出）；新增遮罩落点回退——第二击落在 44px 图标之外的遮罩上（距首击 120px 内）也认双击，直进全屏
- **⑦ ↓ 圆钮抬升根修**：v79 的几何解析器整棵排除 dock 子树，而实机诊断实锤 ↓ 钮（`v4-timeline-bottom`，28×28，absolute/bottom-full 悬在 0 高 dock 上方 8px）**就在 dock 内部**——被自己排除了。选择器已知（testid 稳定），几何解析器删除，换 02_style 静态 CSS 直抬 `translate(-50%, calc(-6px - var(--zc-safe-b)))`（复刻其 Tailwind 居中；mock 实测 Y −6→−32，底距 8→40px）
- **③ 键盘跟随·实验加固**（实机"键盘盖住输入框"）：原生侧 onProgress 动画期按 ≥8px 步进补报（v79 只在 onApply 报终值，任一环没送到 JS 就全程不知键盘来了）；JS 侧 visualViewport 高度差兜底（部分 WebView 版本会更新 vv）；诊断 `feats` 新增 `kbCalls/kbAgo` 桥接埋点（kbCalls=0=桥断、≥100=vv 兜底生效过），下次实机一发诊断即可分辨"原生没报"vs"报了没生效"
- ⑥ 阅读线经全链路探针回归 4/4 通过（间歇失败为测试脚手架内容高度不足，非代码问题；实机诊断 uiTrace 本有 readline-place 成功记录）；⑤ 骨架/⑨ AMOLED 无回归；全套 validate/smoke/Playwright 绿

## [已推送 03e510a] — v79（bundleVer 56）

小屏交互提案批次落地：用户从 10 条提案中划掉 ④（音量键翻页）与 ⑩（边缘手势分区），其余 ①②③⑤⑥⑦⑧⑨ 全部实现。设置页新增四个开关（发送后归位 / 长按消息菜单 / 键盘跟随·实验 / 纯黑 AMOLED·实验），经 `window.__zcSettings` 注入、`applySettings` 热更，不重进会话即生效。

- **① 发送后归位（默认开，可关）**：发送消息后输入框自动收纳、回复全屏阅读。触发用双证据签名——"输入框刚有字 → 新用户行出现 且 输入框已清空"，手动删光字不会误触（没有新用户行）；归位前先 blur 收键盘（IME 逐帧 resize 不与 morph 重叠），延迟 420ms 让 z.ai 自己的发送动画先走完
- **② 图标双击直进全屏**：单击唤出后 380ms 宽限窗内图标"隐形但可接"（opacity:0 仍收触摸，display:none 会收不到第二击），morph 替身从图标位起飞同时图标淡出无双影；第二击落图标 → `whenMorphDone` 等飞行结束再切全屏（两段 morph 的 morphTok 会互相顶掉替身清理）
- **③ 键盘跟随·实验（默认关）**：键盘起落时 WebView 不再缩放（原生 insets 监听按开关跳过 ime 垫高，页面零重排、虚拟列表不再逐帧重算），onApply 只报一次键盘终值给 JS（`__zcKb`），bundle 换算 `--zc-kb-lift`（胶囊底缘越过键盘顶沿多少抬多少、封顶到胶囊顶缘−8px），CSS 过渡让胶囊贴键盘顶沿升降。CSS 选择器带 `html.zcode-float-on` 前缀压过基础 float 规则的 transform（同特异性会静默失效，mock 实测抓出）
- **⑤ 会话切换骨架屏**：包装 `history.pushState/replaceState` + popstate（SPA 换会话不触发导航事件）→ 铺一层与页面底色一致（边缘采样色）的微光条骨架，首条 v4-row 渲染即淡出、1.4s 硬上限；淡入 140ms（快切几乎不可见）；主文档独占路由钩子（shadow root 共享 history，双包装会双触发）；骨架期自动收起导航/面板/阅读线
- **⑥ 流式阅读位置线**：流式输出中上滑离开底部 ≥260px → 在离开时刻的内容底边插"新内容 ↓"细线（锚在最后一个可见行后，内容只在尾部追加故锚点稳定），新内容持续生长在线下方；滚回底部 ≤160px 或流式结束（scrollHeight 2.2s 无增长）即淡出；锚行被虚拟化卸载顺手收线不重建；判据 scrollHeight 增长由 1s 轮询跟踪（v75 的 tailShLast 同源思路）
- **⑦ z.ai 原生 ↓ 圆钮避让小白条（用户实测补充）**：未连 USB 无法锚定选择器，走几何解析——收纳态里"fixed/absolute 且悬在视口底 170px 内的 18-46px 近方圆钮"逐个测底缘与 `safeB()+10` 的差值，差多少 `translateY` 补多少（transform 不挑定位方案）；幂等（rect 反映已应用位移）；行内静态定位的消息操作按钮被 position 过滤器排除不会误伤；命中记 `liftLog` 进诊断卡，下次连 USB 可钉死选择器换静态 CSS
- **⑧ 长按消息快捷菜单（默认开，可关）**：长按 520ms（位移 <10px）出"复制全文 / 引用"动作条。引用 = 唤出输入框 + 原生 value setter 写入 `> 摘录` + 派发 input（React 受控兼容）+ 聚焦；复制走 clipboard API（execCommand 兜底）。与原生长按选择互斥：菜单出现后 420ms 内发生 selectionchange/contextmenu 自动让位收起；落点在 textarea/按钮/代码块时长按有原生语义，直接不触发
- **⑨ 纯黑 AMOLED·实验（默认关）**：注入层 token 全套换纯黑系（`html.zc-amoled`）+ body/timeline 底面强制 `#000`；z.ai 气泡/代码块等具体表面色需实机调色（诊断卡 `feats.amoled` 可查状态）
- 诊断卡新增 `feats` 块（八个特性的开关态 + kbH/kbLift/skShown/readLine/liftLog）；`bundleVer` 56；mock 预览页新增"模拟发送/模拟会话切换/模拟长按/模拟 safeB"钩子 + 假 ↓ 圆钮，九项特性接线回归全过、既有导航/热更/零 jsErrors 回归通过

## [未发布] — v78 工作区（bundleVer 55）

- **输入框过渡质感根修——"中途丑陋椭圆帧"消灭**：三个容器变换（唤出/收纳/全屏切换）旧方案用 `transform: scale` 缩放胶囊——非均匀缩放（sx≠sy）会把圆角与描边粗细压扁拉长，飞行中途就是那帧椭圆。改为**幽灵替身**：真实胶囊全程 `visibility:hidden`，一个复刻其背景/描边/阴影/圆角的空壳 div 用 left/top/width/height **尺寸动画**飞行（几何全程正确），落位瞬间换回真身、内容 0.12s 淡入；morphTok 防飞行叠加
- **垫与滚动补偿时序重排（消除开合时的内容跳变）**：唤出时让位垫不再与飞行同帧写入（真身隐藏中布局变化会穿帮）——挪到落位回调；tl 的 `padding-bottom` 加 0.22s 过渡（仅收纳态），"列表让位"从瞬时跳变变成连续滑动；保底滚动从瞬时 `scrollTop=` 跳变更改为 `scrollTo({behavior:'smooth'})`，与替身飞行同曲线并行同向。收纳时 1s 轮询撞进飞行窗口由 setOverlayPad 的 morph 闸挡住，落位统一补
- **上拉展开手柄（低可视）**：胶囊上内缘（右上角）26×3 半透明小横条（`--zc-text-3` @ opacity 0.18，按压时 0.4），提示可上拉展开半屏输入。挂 dock（fixed 定位锚）的 `::after` 伪元素——样式表注入 React 抹不掉，不碰 z.ai 胶囊本体；上拉展开手势本就由胶囊整体纵向拖动承担，手柄纯提示
- mock 接线回归全过：收纳/唤出双向替身飞行中帧与落位态、垫"落位后 116px"、手柄 ::after 0.18、v77 无焦点、零 jsErrors
