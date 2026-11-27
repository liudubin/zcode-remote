      styleRoot().appendChild(fxStyle);
    }
    ensureFxStyle();
    var lastThemeKey = '', lastThemeR = -1, lastThemeG = -1, lastThemeB = -1;
    var replyTrace = [];   // 回复链路埋点（检测/通知每次尝试都记，诊断时随 JSON 上报）

    function hint(text){
      var old = doc.getElementById('zcode-nav-hint');
      if (old && old.parentNode) { old.parentNode.removeChild(old); }
      var h = doc.createElement('div');
      h.id = 'zcode-nav-hint';
      h.textContent = text;
      // 悬浮输入开着时上移，避免和输入胶囊重叠；v70：再叠加底部安全区（边到边后不压手势条）
      var up = ((doc.documentElement.classList.contains('zcode-float-on') && getDock()) ? 128 : 88) + safeB();
      h.style.cssText = 'position:fixed;left:50%;bottom:' + up + 'px;transform:translateX(-50%);' +
        'background:var(--zc-hint-bg);color:var(--zc-text);font-size:13px;line-height:1.4;padding:11px 18px;' +
        'border-radius:999px;z-index:99999;border:1px solid var(--zc-stroke);box-shadow:0 8px 26px rgba(0,0,0,0.4);' +
        'pointer-events:none;max-width:min(84vw,420px);text-align:center;overflow-wrap:break-word;' +
        'animation:zcodeFadeHint 0.18s ease-out;';
      (isShadow ? root : doc.body || doc.documentElement).appendChild(h);
      // 淡出：1600ms 后播 180ms fadeOut，animationend 移除（动画事件兜底 400ms）
      setTimeout(function(){
        if (!h.parentNode) { return; }
        if (ANIM_ON && !REDUCED) {
          h.style.animation = 'zcodeFadeOut 0.18s ease-in';
          var done = function(){ if (h.parentNode) { h.parentNode.removeChild(h); } };
          h.addEventListener('animationend', done, {once: true});
          setTimeout(done, 400);
        } else {
          h.parentNode.removeChild(h);
        }
      }, 1600);
    }
    function vibrate(){
      try { if (navigator.vibrate) { navigator.vibrate(15); } } catch (e) {}
    }
    function styleRoot(){
      return isShadow ? root : (doc.head || doc.documentElement);
    }
    function bridge(){
      return window.zcodeBridge || (window.parent && window.parent.zcodeBridge) || null;
    }

