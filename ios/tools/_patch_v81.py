#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v81 composer 修复补丁（幂等）：对 dev/bundle/06_composer.js 做 4 处精确替换。
CI 在 build_bundle.py 之前跑本脚本；本地已应用过时自动跳过。"""
import sys

P = 'dev/bundle/06_composer.js'
src = open(P, 'rb').read().decode('utf-8')
NL = '\r\n' if '\r\n' in src else '\n'
def q(*lines):
    s = NL.join(lines)
    # triple-quoted 元素内部可能残留 LF，统一转成目标行尾
    return s.replace('\n', NL)

PATCHES = [
    # tag, old, new
    ('arm-observe',
     q('''      if (tg.closest('textarea, input, select, button, a, [contenteditable], [role="button"], #zcode-composer-expand')) { return null; }
      return { x: x, y: y, t0: Date.now(), done: false, pill: dk.querySelector('.rounded-2xl') };'''),
     q('''      // v81「输入框弹出来了打不了字」：起点落在页面输入框（Lexical contenteditable/原生
      // textarea 及其容器）上时挂"纯观察"track——不排除不拦截、滑动收纳不触发，
      // 只在 dockGestureEnd 里补 focus（防 6px 即 preventDefault 连带取消合成 tap）
      if (tg.closest('[data-testid^="v4-composer-input"], textarea, input, [contenteditable="true"]')) {
        return { x: x, y: y, t0: Date.now(), done: false, observe: true };
      }
      if (tg.closest('textarea, input, select, button, a, [contenteditable], [role="button"], #zcode-composer-expand')) { return null; }
      return { x: x, y: y, t0: Date.now(), done: false, pill: dk.querySelector('.rounded-2xl') };''')),
    ('move-observe',
     q('''    function dockGestureMove(e){
      if (!dockTrack || dockTrack.done) { return; }'''),
     q('''    function dockGestureMove(e){
      if (!dockTrack || dockTrack.done) { return; }
      if (dockTrack.observe) { return; }   // v81 纯观察 track：起点在输入框上，不拦不触发''')),
    ('end-focus',
     q('''    function dockGestureEnd(){
      if (dockTrack && !dockTrack.done && dockTrack.pill && dockDragTy) {
        // 未越阈：带过渡回弹，和触发路径在观感上明确区分
        dockTrack.pill.style.transition = 'transform 0.18s ease';
        dockTrack.pill.style.transform = '';
      }
      dockTrack = null;
      dockDragTy = 0;
    }'''),
     q('''    function dockGestureEnd(e){
      if (dockTrack && !dockTrack.done && dockTrack.pill && dockDragTy) {
        // 未越阈：带过渡回弹，和触发路径在观感上明确区分
        dockTrack.pill.style.transition = 'transform 0.18s ease';
        dockTrack.pill.style.transform = '';
      }
      var track = dockTrack;
      dockTrack = null;
      dockDragTy = 0;
      // v81 补 focus：轻点输入框（未滑成、起点在输入框上）时合成 tap 已被 preventDefault
      // 连带取消 → 页面输入框收不到 tap 不聚焦、键盘不起 → 这里手动补 focus。
      // focus() 必须在触摸手势调用栈内才合法（touchend handler 正是），iOS WKWebView 有效。
      if (track && !track.done && track.observe && e && e.changedTouches && e.changedTouches.length) {
        try {
          var t = e.changedTouches[0];
          var el = doc.elementFromPoint(t.clientX, t.clientY);
          var hit = el && el.closest('[data-testid^="v4-composer-input"], textarea, input, [contenteditable="true"]');
          if (hit && hit.focus) { hit.focus(); }
        } catch (eF) {}
      }
    }''')),
    ('morph-transform',
     q('''      var ease = ' cubic-bezier(0.2,0.8,0.2,1)';
      g.style.transition = 'left ' + dur + 'ms' + ease + ',top ' + dur + 'ms' + ease +
        ',width ' + dur + 'ms' + ease + ',height ' + dur + 'ms' + ease +
        ',border-radius ' + dur + 'ms ease';
      g.style.left = to.x + 'px';
      g.style.top = to.y + 'px';
      g.style.width = Math.max(1, to.w) + 'px';
      g.style.height = Math.max(1, to.h) + 'px';
      g.style.borderRadius = radiusEnd || '22px';'''),
     q('''      var ease = ' cubic-bezier(0.2,0.8,0.2,1)';
      // v81「动画没有连贯性」：飞行改 transform（GPU 合成零回流）——left/top/width/height
      // 五属性插值在 iOS WKWebView 上逐帧 layout，z.ai 主线程一忙就掉帧。
      // translate+scale 一步到位，圆角仍插值（只 paint 不 layout）；非均匀 scale 压扁
      // 描边/阴影在 280ms 飞行中段难辨，连贯性优先。
      g.style.transformOrigin = 'top left';
      g.style.willChange = 'transform';
      g.style.transition = 'transform ' + dur + 'ms' + ease +
        ',border-radius ' + dur + 'ms ease';
      g.style.transform = 'translate(' + (to.x - from.x).toFixed(1) + 'px,' + (to.y - from.y).toFixed(1) + 'px)' +
        ' scale(' + (Math.max(1, to.w) / Math.max(1, from.w)).toFixed(4) + ',' +
        (Math.max(1, to.h) / Math.max(1, from.h)).toFixed(4) + ')';
      g.style.borderRadius = radiusEnd || '22px';''')),
]

applied = skipped = 0
for tag, old, new in PATCHES:
    co, cn = src.count(old), src.count(new)
    if cn and not co:
        print(f'skip {tag} (already applied)')
        skipped += 1
    elif co == 1:
        src = src.replace(old, new)
        print(f'apply {tag}')
        applied += 1
    else:
        print(f'FAIL {tag}: old={co} new={cn}')
        sys.exit(1)

open(P, 'wb').write(src.encode('utf-8'))
print(f'done: applied={applied} skipped={skipped}')
