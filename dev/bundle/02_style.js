// ===== 02_style.js (67-228) =====
    // ---------- 动效与输入框劫持样式（毛玻璃、去蓝、渐入动画） ----------
    var fxStyle = null;
    // anim() 生成 animation 值：开 = 指定动画；关 = none（动效开关 + 系统减弱动效双门控）
    function anim(name, dur, ease){
      return (ANIM_ON && !REDUCED) ? ('animation:' + name + ' ' + dur + (ease ? ' ' + ease : '') + ';') : '';
    }
    function ensureFxStyle(){
      if (fxStyle && fxStyle.parentNode) { return; }
      fxStyle = doc.createElement('style');
      fxStyle.id = 'zcode-fx';
      fxStyle.textContent =
        // 设计 token：注入 UI 共用一套颜色/圆角（黑灰系，无蓝调；对齐原生 colors-night.xml）
        // z-index 阶梯：999 真导航解锁 / 99995 遮罩 / 99996 原生导航解锁态 / 99997 面板 / 99998 悬浮输入+预览 / 99999 全屏输入+提示+诊断
        ':root, :host{--zc-bg:rgba(30,30,30,0.85);--zc-bg-strong:rgba(26,26,26,0.94);' +
        '--zc-bg-deep:rgba(22,22,22,0.92);--zc-hint-bg:rgba(20,20,20,0.94);' +
        '--zc-stroke:rgba(255,255,255,0.14);--zc-stroke-faint:rgba(255,255,255,0.08);--zc-stroke-strong:rgba(255,255,255,0.20);' +
        '--zc-text:#F2F2F2;--zc-text-2:#FAFAFA;--zc-text-dim:#CFCFCF;--zc-text-3:#909090;' +
        '--zc-hover:rgba(255,255,255,0.08);--zc-hover-strong:rgba(255,255,255,0.12);--zc-outline:rgba(255,255,255,0.85);' +
        '--zc-radius:12px;--zc-radius-lg:16px;--zc-radius-xl:22px;}' +
        // 浅色主题：页面检测为浅色时 JS 给 <html> 挂 zcode-ui-light，整套 token 换白底黑字（04_theme.js reportTheme 驱动）
        'html.zcode-ui-light{' +
        '--zc-bg:rgba(252,253,255,0.92);--zc-bg-strong:rgba(255,255,255,0.97);' +
        '--zc-bg-deep:rgba(255,255,255,0.96);--zc-hint-bg:rgba(255,255,255,0.97);' +
        '--zc-stroke:rgba(10,18,34,0.12);--zc-stroke-faint:rgba(10,18,34,0.06);--zc-stroke-strong:rgba(10,18,34,0.18);' +
        '--zc-text:#1B2230;--zc-text-2:#0F1522;--zc-text-dim:#3A4356;--zc-text-3:#8A93A6;' +
        '--zc-hover:rgba(10,18,34,0.06);--zc-hover-strong:rgba(10,18,34,0.10);--zc-outline:rgba(20,35,60,0.80);' +
        'color-scheme:light;}' +
        '@keyframes zcodeFadeUp{from{opacity:0;transform:translateX(-50%) translateY(16px)}to{opacity:1;transform:translateX(-50%)}}' +
        '@keyframes zcodeFadeUpNoX{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:none}}' +
        '@keyframes zcodeFadeIn{from{opacity:0}to{opacity:1}}' +
        '@keyframes zcodeFadeOut{from{opacity:1}to{opacity:0}}' +
        '@keyframes zcodeFadeDown{from{opacity:1;transform:translateX(-50%) translateY(0)}to{opacity:0;transform:translateX(-50%) translateY(14px)}}' +
        '@keyframes zcodeFadeDownNoX{from{opacity:1;transform:translateY(0)}to{opacity:0;transform:translateY(14px)}}' +
        '@keyframes zcodeFadePanel{from{opacity:0;transform:translateX(-50%) translateY(10px)}to{opacity:1;transform:translateX(-50%)}}' +
        '@keyframes zcodeFadePanelOut{from{opacity:1;transform:translateX(-50%) translateY(0)}to{opacity:0;transform:translateX(-50%) translateY(10px)}}' +
        '@keyframes zcodeFadeHint{from{opacity:0;transform:translateX(-50%) translateY(8px) scale(0.96)}to{opacity:1;transform:translateX(-50%)}}' +
        // 浮动输入（v65 图标化）：有消息未唤出时不再把整个 dock display:none——
        // 新版(3.14.4)页面给 composer 让位的 padding 挂在 timeline 内容列等节点上，
        // dock 一消失让位空间就失去锚点，底部留大块空白（真机实测+线上 bundle 取证）。
        // 改为：只在"未唤出且无弹窗"态收起 v4-composer 子树，由注入的 #zcode-composer-icon
        // （44px 圆钮，左下角）撑起 dock——dock 保持流内 sticky，页面/虚拟列表的预留逻辑照常工作。
        // 悬浮态/全屏态不变：dock 只负责"定位 + 抬起"，页面原生 .rounded-2xl 输入胶囊
        // （自带 bg+border+圆角）作为唯一视觉框架。z.ai 的 ask/确认弹窗渲染在 dock 内 →
        // 弹窗出现时临时显示 dock（zcode-popup-mode），只露弹窗、藏输入与图标，消失后回收纳态。
        'html.zcode-float-on [data-v4-composer-dock="true"]:not(.zcode-composer-float)' +
        ':not(.zcode-composer-full):not(.zcode-popup-mode) [data-testid="v4-composer"]{display:none!important}' +
        // 收纳态零占位（v66）：dock 压到 0 高、content 边距清零——消息列表直接铺到屏幕底部，
        // 不再留 60px 空带；图标改悬浮（见下），页面自己的让位计算随 dock 高度归零。
        // 注意 :not(.zcode-popup-mode)：弹窗态 dock 要正常尺寸
        'html.zcode-float-on [data-v4-composer-dock="true"]:not(.zcode-composer-float)' +
        ':not(.zcode-composer-full):not(.zcode-popup-mode){height:0!important;min-height:0!important;' +
        'padding:0!important;overflow:visible!important}' +
        'html.zcode-float-on [data-v4-composer-dock="true"]:not(.zcode-composer-float)' +
        ':not(.zcode-composer-full):not(.zcode-popup-mode) [data-v4-composer-dock-content]{padding:0!important}' +
        // 收纳图标：悬浮在左下角内容之上（fixed，不属于任何流），黑灰毛玻璃小圆钮。
        // 右滑开导航（配合原生手势豁免）；与输入框的切换走容器变换（morphReveal/morphMinimize）
        // v70：bottom 抬升底部安全区（边到边后不压系统手势条）；
        // touch-action:none——实机右滑/上滑完全没反应的元凶：默认 auto 下浏览器在 ~10px
        // slop 后就把手势流抢去滚动/ overscroll（touchcancel），跟手反馈与 48px 阈值全被掐死；
        // 44px 圆钮自身没有任何可滚动内容，关掉浏览器手势处理零代价
        '#zcode-composer-icon{position:fixed;left:12px;bottom:calc(12px + var(--zc-safe-b, 0px));z-index:99996;margin:0;' +
        'display:flex;align-items:center;justify-content:center;' +
        'width:44px;height:44px;border-radius:22px;background:var(--zc-bg-strong);' +
        '-webkit-backdrop-filter:blur(18px) saturate(1.4);backdrop-filter:blur(18px) saturate(1.4);' +
        'border:1px solid var(--zc-stroke-strong);color:var(--zc-text-2);font-size:19px;line-height:1;' +
        'box-shadow:0 4px 18px rgba(0,0,0,0.35);cursor:pointer;user-select:none;-webkit-user-select:none;' +
        'touch-action:none;' +
        (ANIM_ON && !REDUCED ? 'transition:opacity 0.15s,transform 0.12s;' : '') +
        '}' +
        '#zcode-composer-icon:active{opacity:0.7;' + (ANIM_ON && !REDUCED ? 'transform:scale(0.92);' : '') + '}' +
        // 唤出态/全屏态/弹窗态藏图标（JS 侧同步 display，这里是样式兜底）
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float #zcode-composer-icon,' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full #zcode-composer-icon,' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-popup-mode #zcode-composer-icon,' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-popup-present #zcode-composer-icon{display:none!important}' +
        // 清除底部残留占位（v61）：dock 隐藏后，消息列表 section 的 pb-5 仍留 20px 底部留白。
        // 实测 dock 自身用 display:none 已不占位，但 section 的 padding-bottom 与输入框常驻时
        // 配合是合理的（避免最后一条消息贴着输入框），dock 隐藏后这段就成了多余占位，清除。
        'html.zcode-float-on [data-testid="v4-timeline"] section{padding-bottom:0!important}' +
        // 底部渐隐遮罩摘除（v74，实机 CDP 取证）：z.ai 给时间线内容列挂了跟随滚动的 CSS mask——
        // mask-image: linear-gradient(black 0, black 566px, transparent 590px, …100%);
        // mask-position: 0px <scrollTop>px; mask-size: 100% <视口高>px
        // 可见区底部 ~120px 恒定渐隐成空白；惯性滚动后 mask-position 与 scrollTop 脱同步时
        // 透明带更大（实机照片实测 190px）——这就是"上滚后底部空白占位"的真身。
        // DOM 探针全被它骗过：hit-test/innerText 都无视 mask，probe 报"有内容"但屏幕是白的。
        // 收纳态（float-on）dock 已隐藏，这层渐隐只剩空白，直接摘掉让消息画到底边；
        // 原生 dock 态（float off）保留 z.ai 原设计（渐隐用于和输入框过渡）。
        // [style*="mask-position"] 属性选择器：z.ai 卸掉 mask 时属性串消失即不匹配，自门控。
        'html.zcode-float-on [data-testid="v4-timeline"] [style*="mask-position"],' +
        'html.zcode-float-on [data-testid="v4-timeline-scroll"] [style*="mask-position"]' +
        '{-webkit-mask-image:none!important;mask-image:none!important}' +
        // v80⑦→v81：z.ai 原生"滚动到底部"圆钮避让系统手势条（实机取证：v4-timeline-bottom
        // 挂在 dock 内 back-to-bottom-anchor 锚上，absolute/bottom-full/mb-2 悬在 0 高 dock
        // 上方，收纳态离屏底仅 ~8px 压小白条）。v81 关键教训：它的水平居中是 Tailwind v4 的
        // -translate-x-1/2 → 独立 translate 属性（不是 transform），translate 与 transform
        // 两属性叠加生效——规则里再写 translateX(-50%) 就是二次左移半个钮宽（实机
        // "↓钮不居中"根因）。这里只写 Y 分量：抬高 安全区+6px（原 8px 底距 +
        // 抬升量 ≥ safeB+10 的避让口径）。safeB=0（桌面/旧壳）时只抬 6px，无感
        'html.zcode-float-on [data-testid="v4-timeline-bottom"]' +
        '{transform:translateY(calc(-6px - var(--zc-safe-b, 0px)))!important}' +
        // v78 让位垫过渡：胶囊唤出/收纳时 tl 的 padding-bottom 变化不再是瞬时跳变，
        // 而是短滑过渡——垫的写入时机已挪到 morph 落位之后（06_composer），配合这条
        // 过渡整个"消息列表为胶囊让位"的动作是连续的。仅收纳态生效，不干扰 z.ai
        // 原生模式的任何 padding 行为；过渡期间 scrollHeight 逐帧变化由 v75 静止闸门兜住。
        'html.zcode-float-on [data-testid="v4-timeline"],' +
        'html.zcode-float-on [data-testid="v4-timeline-scroll"]' +
        '{transition:padding-bottom 0.22s cubic-bezier(0.2,0.8,0.2,1)}' +
        // v78 上拉手柄：胶囊上内缘（右上角）低可视小横条——提示"可上拉展开半屏输入"。
        // 挂 dock（fixed=定位锚）的 ::after 伪元素：样式表注入，React 重渲染抹不掉；
        // 不碰 z.ai 的胶囊本体（不改它的 position，零回归面）。点按无感（pointer-events
        // none），拖动展开的手势本来就由胶囊整体的纵向 dockGesture 承担。
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float::after{content:"";' +
        'position:absolute;top:3px;right:10px;width:26px;height:3px;border-radius:2px;' +
        'background:var(--zc-text-3);opacity:0.18;pointer-events:none}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float:active::after{opacity:0.4}' +
        // v78 morph 幽灵替身基样式（动画值由 JS 内联写入）：真实胶囊飞行期间隐藏，
        // 替身用尺寸动画飞行——scale 非均匀缩放会把圆角与描边压成椭圆（"中途丑陋
        // 椭圆帧"的来源），尺寸动画几何全程正确
        '.zcode-morph-ghost{position:fixed;z-index:99999;pointer-events:none;box-sizing:border-box}' +
        // v79⑤ 会话切换骨架屏：路由切换 → 整列表卸载重建（实机 ~1s 主线程冻结），冻结期
        // 铺一层与页面底色一致的微光条，首条 v4-row 渲染即淡出（05_nav route watch 驱动）。
        // 淡入 140ms：快速切换时骨架几乎不可见；pointer-events:none 不挡任何点击
        '#zcode-skeleton{position:fixed;inset:0;z-index:99990;pointer-events:none;opacity:0;transition:opacity 0.14s ease-out}' +
        '#zcode-skeleton.zc-sk-in{opacity:1}' +
        '#zcode-skeleton.zc-sk-out{opacity:0;transition:opacity 0.18s ease-in}' +
        '.zc-sk-bar{position:absolute;height:13px;border-radius:7px;' +
        'background:linear-gradient(90deg,rgba(255,255,255,0.04),rgba(255,255,255,0.10),rgba(255,255,255,0.04));' +
        'background-size:200% 100%;animation:zcodeSkShimmer 1.3s linear infinite}' +
        'html.zcode-ui-light .zc-sk-bar{background:linear-gradient(90deg,rgba(10,18,34,0.05),rgba(10,18,34,0.12),rgba(10,18,34,0.05));background-size:200% 100%}' +
        '@keyframes zcodeSkShimmer{from{background-position:200% 0}to{background-position:-200% 0}}' +
        // v79⑥ 流式阅读位置线：流式中上滑离开底部，在离开时刻的内容底边插一条低可视
        // 细线（"新内容都在线下方"），滚回底部/流式结束淡出。挂在内容流里（行后插节点），
        // 内容只在尾部追加，锚点稳定；行被虚拟化卸载则顺手收线
