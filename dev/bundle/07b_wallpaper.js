// ===== 07b_wallpaper.js =====
// ⑩ 会话页自定义背景（壁纸）：html 铺图 + 消息区透明化（结构规则在 CSS_BASE 的 html.zc-wp 段）。
// 压暗由原生侧合成进图里（wpImage 直接是带暗度的 dataURI），JS 端零计算。
// 设置键：wpImage(dataURI 空串=关) / wpDim(备用，压暗已烘焙，仅作元数据透传)。
// 档位=最小 时不运行增强层，壁纸随增强层一起关闭（符合"最小=只装桥"语义）。
function applyWallpaper() {
  var html = document.documentElement;
  var uri = (typeof ZSET.wpImage === 'string') ? ZSET.wpImage : '';
  var on = uri.length > 24; // "data:image/jpeg;base64," 就 23 字符，再短必是坏的
  var st = document.getElementById('zc-wp-style');
  if (!on) {
    if (st && st.parentNode) { st.parentNode.removeChild(st); }
    html.classList.remove('zc-wp');
    return;
  }
  var css = 'html.zc-wp{background-image:url("' + uri + '")!important;' +
    'background-size:cover!important;background-position:center!important;' +
    'background-repeat:no-repeat!important;background-attachment:fixed!important}';
  if (st) { st.textContent = css; }
  else {
    st = document.createElement('style');
    st.id = 'zc-wp-style';
    st.textContent = css;
    (document.head || html).appendChild(st);
  }
  html.classList.add('zc-wp');
}
try { applyWallpaper(); } catch (e) {
  var _werr = window.__zcodeErrors || (window.__zcodeErrors = []);
  _werr.push('wallpaper:' + String(e && e.message || e).slice(0, 140));
}
