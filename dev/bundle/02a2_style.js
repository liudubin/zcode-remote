        '.zc-readline{position:relative;height:2px;margin:10px 2px;border-radius:1px;' +
        'background:linear-gradient(90deg,transparent,var(--zc-stroke-strong) 12%,var(--zc-stroke-strong) 88%,transparent);' +
        'opacity:0.7;pointer-events:none;transition:opacity 0.4s ease}' +
        '.zc-readline.zc-rl-out{opacity:0}' +
        '.zc-readline i{position:absolute;right:2px;top:-15px;font-style:normal;font-size:10px;' +
        'color:var(--zc-text-3);opacity:0.75;letter-spacing:1px}' +
        // v79⑨ AMOLED 纯黑（实验开关）：注入层 token 换纯黑系；页面侧 best-effort
        //（body/timeline 底面），z.ai 气泡/代码块等具体表面色需实机调色（HANDOFF 待办）
        'html.zc-amoled{--zc-bg:rgba(0,0,0,0.86);--zc-bg-strong:rgba(0,0,0,0.92);--zc-bg-deep:rgba(0,0,0,0.96);' +
        '--zc-hint-bg:rgba(0,0,0,0.95);--zc-stroke:rgba(255,255,255,0.10);--zc-stroke-faint:rgba(255,255,255,0.05);' +
        '--zc-stroke-strong:rgba(255,255,255,0.16)}' +
        'html.zc-amoled body,html.zc-amoled [data-testid="v4-timeline"],html.zc-amoled [data-testid="v4-timeline-scroll"]' +
        '{background-color:#000!important}' +
        // v82⑩ 自定义背景（壁纸）：html 铺原生合成的图（含压暗），消息区透明让壁纸透出来；
        // 气泡/代码块自带表面色不受影响，可读性由原生压暗滑杆兜底
        'html.zc-wp,html.zc-wp body{background:transparent!important}' +
        'html.zc-wp [data-testid="v4-timeline"],html.zc-wp [data-testid="v4-timeline-scroll"]{background:transparent!important}' +
        // v79③ 键盘跟随·实验已整套删除（v81，用户淘汰）：WebView 恢复 v72 行为——
        // 键盘把 content 垫高、WebView 随之缩放，页面自己坐到键盘上方，注入层零参与
        // 弹窗模式：dock 临时显示为底部容器（不遮挡全屏），输入部分隐藏，弹窗可见可点
        // 容器变换进行中：压掉 float/full 态的入场 animation，几何交给 JS 的 transform 过渡
        '[data-v4-composer-dock="true"].zcode-composer-morph{animation:none!important}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-popup-mode{' +
        'display:block!important;visibility:visible!important;pointer-events:auto!important;' +
        'position:fixed!important;left:50%!important;right:auto!important;bottom:var(--zc-safe-b, 0px)!important;top:auto!important;' +
        'transform:translateX(-50%)!important;width:100%!important;max-width:760px!important;height:auto!important;' +
        'padding:0!important;margin:0!important;background:transparent!important;border:none!important;' +
        'box-shadow:none!important;z-index:99998!important;' +
        'overflow:visible!important;' +
        (ANIM_ON && !REDUCED ? 'animation:zcodeFadeIn 0.18s ease-out;' : '') + '}' +
        // 弹窗模式：只露弹窗——只藏 v4-composer 整棵子树（胶囊/输入框/expand 全在它里面）。
        // 注意：绝不能再用 .rounded-2xl 选择器藏胶囊——ask 弹窗卡片自身也带 rounded-2xl 类
        // （诊断 dockHtml 实锤），会被一起藏掉（v58 修：v57 就是这个坑导致弹窗 display:none）
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-popup-mode [data-testid="v4-composer"]' +
        '{display:none!important}' +
        // 弹窗复活说明（v60）：不再给弹窗节点加 !important 可见性——v46 起 dock 用 display:none 隐藏、
        // popup-mode 用 display:block 显示整棵子树，弹窗节点在打开的 dock 里自然可见。
        // 曾经的 visibility:visible!important 会压制页面自身的关闭样式（弹窗点选后关不掉，v60 修）。
        // .zcode-popup-visible 只作检测标记保留，不干预样式。
        // 注意：悬浮/全屏规则必须带 html.zcode-float-on 前缀提升特异性，否则会被上面的隐藏规则压住
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float{' +
        'display:flex!important;visibility:visible!important;pointer-events:auto!important;position:fixed!important;left:50%!important;right:auto!important;' +
        'bottom:calc(14px + var(--zc-safe-b, 0px))!important;top:auto!important;transform:translateX(-50%)!important;' +
        'width:min(94vw,520px)!important;max-width:none!important;height:auto!important;' +
        'z-index:99998!important;pointer-events:auto!important;' +
        'padding:0!important;background:transparent!important;border:none!important;box-shadow:none!important;' +
        anim('zcodeFadeUp', '0.22s', 'cubic-bezier(0.2,0.8,0.2,1)') +
        '}' +
        // 弹窗存在时（含悬浮输入打开态）不显示 expand 按钮：弹窗与输入按钮不应同时出现
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-popup-present #zcode-composer-expand{display:none!important}' +
        // body 级弹窗让位（v53）：z.ai 的 Radix 下拉/菜单 portal 到 body 根部，z-index 仅 z-50，
        // 远低于我们的遮罩（99995）/dock（99998+）。不让位时遮罩吞掉点击、全屏暗层盖住视觉
        // ——"对话框按钮的二级弹窗被盖住"。检测到 body 弹窗（html.zcode-body-popup）时把注入层
        // 全部压到弹窗之下：z-40 高于页面内容(z-20)、低于页面弹窗(z-50)，logo 让到 45。
        'html.zcode-body-popup #zcode-mask{z-index:40!important}' +
        'html.zcode-body-popup [data-v4-composer-dock="true"].zcode-composer-float,' +
        'html.zcode-body-popup [data-v4-composer-dock="true"].zcode-composer-full,' +
        'html.zcode-body-popup [data-v4-composer-dock="true"].zcode-popup-mode{' +
        'z-index:40!important;' +
        '}' +
        // 全屏暗层会让弹窗"看得见但黑纱罩着"：让位时去掉背景，弹窗完整可见
        'html.zcode-body-popup [data-v4-composer-dock="true"].zcode-composer-full{background:transparent!important}' +
        // 收起态：淡出下移后由 JS 移除类（避免 display:none 瞬间消失，呆板）
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float.zcode-composer-closing{' +
        'pointer-events:none!important;' + anim('zcodeFadeDown', '0.18s', 'ease-in') + '}' +
        // 中和 v4-composer 那层不透明背景块（rgb 22,22,22），否则会和原生气泡叠成双框
        'html.zcode-float-on [data-v4-composer-dock="true"] [data-testid="v4-composer"]{' +
        'background:transparent!important;' +
        '}' +
        // 原生气泡（.rounded-2xl）加一层投影抬起，其余沿用页面自带样式。
        // overflow:visible：胶囊自带 Tailwind overflow-hidden，会把 expand 按钮岔出圆角的外弧裁掉（v52 按钮挂进胶囊后必须放行）
        'html.zcode-float-on [data-v4-composer-dock="true"] [data-testid="v4-composer"] .rounded-2xl{' +
        'box-shadow:0 12px 40px rgba(0,0,0,0.5)!important;overflow:visible!important;' +
        '}' +
        // 全屏态：dock 变全屏遮罩 + 底部居中；气泡放大、加投影。
        // v81：translate:none 与 transform:none 并列——Tailwind v4 的位移工具类走独立
        // translate 属性，只归零 transform 拦不住它（↓钮二次左移的同源教训）
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full{' +
        'display:flex!important;visibility:visible!important;pointer-events:auto!important;position:fixed!important;left:0!important;right:0!important;bottom:0!important;top:0!important;' +
        'transform:none!important;translate:none!important;width:100%!important;max-width:none!important;height:100%!important;' +
        'z-index:99999!important;pointer-events:auto!important;align-items:flex-end!important;justify-content:center!important;' +
        'padding:0 0 calc(20px + var(--zc-safe-b, 0px))!important;background:rgba(0,0,0,0.55)!important;border:none!important;' +
        anim('zcodeFadeIn', '0.18s', 'ease-out') +
        '}' +
        // v81 全屏面板水平居中根修（实机"半屏输入不居中"）：全屏几何在注入层本是对称的
        // （inset 0 + flex 居中 + 面板宽 min(94vw,640px)），偏移来自 z.ai 原生 dock 内层
        // 在全屏态残留的 padding/margin（原生 px-*/ml-* 一类会不对称挤压内容盒）——
        // float/full 两态一并中和（悬浮态真机实测居中，说明真页干扰同样不该存在）；
        // width:100% 对齐真页 w-full（dock 是 flex，缺了它内容层 shrink-to-fit 塌缩），
        // 全屏面板再由 margin-inline:auto 强制居中，不依赖原生内层的自觉
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-float [data-v4-composer-dock-content],' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full [data-v4-composer-dock-content]' +
        '{padding:0!important;margin:0!important;width:100%!important}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full [data-testid="v4-composer"]' +
        '{margin-left:auto!important;margin-right:auto!important}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full.zcode-composer-closing{' +
        'pointer-events:none!important;' + anim('zcodeFadeOut', '0.18s', 'ease-in') + '}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full [data-testid="v4-composer"]{' +
        'width:min(94vw,640px)!important;' +
        '}' +
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full [data-testid="v4-composer"] .rounded-2xl{' +
        'width:min(94vw,640px)!important;box-shadow:0 16px 50px rgba(0,0,0,0.6)!important;' +
        '}' +
        // 全屏关键：输入区放大（页面原生 min-h-10 max-h-40 会把输入框锁死在 40px，
        // 不加这条全屏只是"暗遮罩+底部小输入框"，v37 就是这个坑）。
        // v69（实机"全屏输入框不够大"）：32vh 只占三分之一屏，提到 56vh——输入区是全屏态的主体。
        'html.zcode-float-on [data-v4-composer-dock="true"].zcode-composer-full [data-testid^="v4-composer-input"]{' +
        'min-height:56vh!important;max-height:none!important;height:56vh!important;font-size:16px!important;' +
        '}' +
        // expand：纯 SVG 圆弧双态按钮（Qwen demo 几何）。SVG 根 pointer-events:none → 方块不挡文字，
        // 命中区 = 弧线两侧 14px 透明粗描边（pointer-events:stroke），只有弧环可点；
        // 外弧 R+4（悬浮态）= 扩大，内弧 R−4（全屏态）= 缩小，同圆心同跨角，opacity/visibility 互斥切换。
        // 尺寸由 positionExpand 按胶囊圆角半径动态计算（JS px，跟随界面缩放），这里只兜底。
        '#zcode-composer-expand{position:absolute;top:0.25em;right:0.25em;width:2.75em;height:2.75em;font-size:13px;' +
        'color:var(--zc-text-dim);z-index:99997;pointer-events:none;}' +
        '#zcode-composer-expand:hover{color:var(--zc-text-2);}' +
        '#zcode-composer-expand svg{width:100%;height:100%;overflow:visible;}' +
        '#zcode-composer-expand .zc-hit{fill:none;stroke:transparent;stroke-width:14;pointer-events:stroke;cursor:pointer;}' +
        '#zcode-composer-expand .zc-line{fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;opacity:0.6;' +
        (ANIM_ON && !REDUCED ? 'transition:opacity 0.25s;' : '') + '}' +
        '#zcode-composer-expand:hover .zc-line{opacity:0.9;}' +
        '#zcode-composer-expand .zc-arc{' + (ANIM_ON && !REDUCED ? 'transition:opacity 0.3s,visibility 0.3s;' : '') + '}' +
        // 互斥切换：SVG 的 pointer-events:stroke 写死在 path 上，g 的 visibility:none 都不管用
        // （继承会被 path 自身值覆盖，实测隐藏环仍可命中）→ 必须直接置空隐藏环的命中环；
        // :not(.zc-full) 限定：全屏态下内弧是可见的，命中环必须保留（否则缩回收不回）
        '#zcode-composer-expand .zc-shrink{opacity:0;visibility:hidden;}' +
        '#zcode-composer-expand:not(.zc-full) .zc-shrink .zc-hit{pointer-events:none;}' +
        '#zcode-composer-expand.zc-full .zc-expand{opacity:0;visibility:hidden;}' +
        '#zcode-composer-expand.zc-full .zc-expand .zc-hit{pointer-events:none;}' +
        '#zcode-composer-expand.zc-full .zc-shrink{opacity:1;visibility:visible;}' +
        // 自建导航面板：出现淡入（panel 内联已带 FadePanel），收起淡出下移
        '[aria-label="对话问题导航"].zcode-closing{' + anim('zcodeFadePanelOut', '0.18s', 'ease-in') + '}';
