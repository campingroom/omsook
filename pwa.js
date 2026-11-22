/* ออมสุข — ติดตั้งเป็นแอปบนมือถือ/คอม
 * 1) ลงทะเบียน sw.js (เปิดหน้าแอปได้แม้เน็ตหลุด และทำให้เบราว์เซอร์ยอมให้ติดตั้ง)
 * 2) แถบ "ติดตั้งออมสุขลงเครื่อง" ด้านบนหน้า
 *    - Chrome / Edge / Android: กดแล้วขึ้นหน้าต่างติดตั้งของเบราว์เซอร์
 *    - iPhone / iPad / Safari บน Mac: กดแล้วขึ้นวิธีติดตั้งทีละขั้น (เบราว์เซอร์ไม่มีปุ่มให้เรียกเอง)
 *    กดปิด ✕ แล้วจะไม่ขึ้นอีก 30 วัน · เปิดจากแอปที่ติดตั้งแล้วจะไม่ขึ้น */
(function () {
  'use strict';

  if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
    window.addEventListener('load', function () { navigator.serviceWorker.register('./sw.js').catch(function () {}); });
  }

  var KEY = 'omsook.install.hiddenUntil';
  var ua = navigator.userAgent || '';
  var isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isMacSafari = !isIOS && /Macintosh/.test(ua) && /Safari/.test(ua) && !/Chrome|Chromium|CriOS|Edg|OPR|Firefox|FxiOS/.test(ua);
  var isIOSSafari = isIOS && !/CriOS|FxiOS|EdgiOS|OPiOS|GSA|Line|FBAN|FBAV|Instagram/.test(ua);

  function standalone() {
    return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || window.navigator.standalone === true;
  }
  function snoozed() {
    try { return Number(localStorage.getItem(KEY) || 0) > Date.now(); } catch (e) { return false; }
  }
  function snooze() {
    try { localStorage.setItem(KEY, String(Date.now() + 30 * 864e5)); } catch (e) { /* ไม่มีที่เก็บก็ข้าม */ }
  }

  var deferred = null;
  var bar = null;

  var CSS = '' +
    '.osInstall{font-family:"IBM Plex Sans Thai",system-ui,sans-serif;display:flex;align-items:center;gap:10px;margin:10px auto 0;max-width:720px;width:calc(100% - 24px);padding:10px 10px 10px 12px;background:#fff;border:1px solid #c8ecdc;border-radius:18px;box-shadow:0 6px 18px rgba(19,78,58,.08);color:#134e3a;position:relative;z-index:5}' +
    '.osInstall img{width:40px;height:40px;border-radius:10px;flex:none}' +
    '.osInstall .osTxt{flex:1;min-width:0;line-height:1.35}' +
    '.osInstall .osTxt b{display:block;font-size:15px;font-weight:600}' +
    '.osInstall .osTxt span{display:block;font-size:13px;color:#4f7d6a}' +
    '.osBtn{font:inherit;font-size:14px;font-weight:600;border:0;border-radius:999px;padding:9px 16px;cursor:pointer;color:#fff;background:linear-gradient(135deg,#34d399,#2dd4bf);box-shadow:0 4px 12px rgba(45,212,191,.35);flex:none}' +
    '.osBtn:hover{filter:brightness(.96)}' +
    '.osX{font:inherit;font-size:18px;line-height:1;border:0;background:transparent;color:#4f7d6a;width:34px;height:34px;border-radius:50%;cursor:pointer;flex:none}' +
    '.osX:hover{background:#eef8f3}' +
    '.osBtn:focus-visible,.osX:focus-visible{outline:3px solid #134e3a;outline-offset:2px}' +
    '.osModal{position:fixed;inset:0;background:rgba(8,40,30,.42);display:flex;align-items:center;justify-content:center;padding:20px;z-index:1000;font-family:"IBM Plex Sans Thai",system-ui,sans-serif}' +
    '.osCard{background:#fff;border-radius:24px;max-width:380px;width:100%;padding:22px 20px 18px;color:#134e3a;box-shadow:0 20px 50px rgba(8,40,30,.25)}' +
    '.osCard h2{margin:0 0 4px;font-size:19px;font-weight:700;display:flex;align-items:center;gap:10px}' +
    '.osCard h2 img{width:36px;height:36px;border-radius:9px}' +
    '.osCard p{margin:0 0 12px;font-size:14px;color:#4f7d6a}' +
    '.osCard ol{margin:0 0 16px;padding:0;list-style:none;counter-reset:s}' +
    '.osCard li{counter-increment:s;display:flex;gap:10px;align-items:flex-start;padding:9px 0;border-top:1px solid #eaf3ee;font-size:15px;line-height:1.45}' +
    '.osCard li:before{content:counter(s);flex:none;width:24px;height:24px;border-radius:50%;background:#d1fae5;color:#134e3a;font-weight:700;font-size:13px;display:flex;align-items:center;justify-content:center;margin-top:1px}' +
    '.osCard svg{vertical-align:-4px}' +
    '.osCard .osBtn{width:100%}' +
    '@media (max-width:480px){.osInstall .osTxt span{display:none}}' +
    '@media print{.osInstall,.osModal{display:none!important}}';

  function shareIcon() {
    return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#0a84ff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12M8 7l4-4 4 4"/><path d="M6 11H5a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-8a1 1 0 0 0-1-1h-1"/></svg>';
  }

  function guide() {
    var steps = isMacSafari
      ? ['เปิดเมนู <b>ไฟล์</b> (File) ที่แถบด้านบนของจอ', 'เลือก <b>เพิ่มไปยัง Dock…</b> (Add to Dock)', 'กด <b>เพิ่ม</b> — ไอคอนหมูออมสุขจะอยู่ใน Dock']
      : ['กดปุ่ม <b>แชร์</b> ' + shareIcon() + ' ที่แถบล่างหรือแถบบนของ Safari', 'เลื่อนลงแล้วเลือก <b>เพิ่มไปยังหน้าจอโฮม</b>', 'กด <b>เพิ่ม</b> — ไอคอนหมูออมสุขจะอยู่บนหน้าจอ'];
    var m = document.createElement('div');
    m.className = 'osModal';
    m.innerHTML = '<div class="osCard" role="dialog" aria-modal="true" aria-labelledby="osGuideTitle">' +
      '<h2 id="osGuideTitle"><img src="./icons/icon.svg" alt="">ติดตั้งออมสุขลงเครื่อง</h2>' +
      '<p>' + (isMacSafari ? 'ทำใน Safari บน Mac' : (isIOSSafari ? 'ทำใน Safari บน iPhone / iPad' : 'ถ้าหาเมนูไม่เจอ ให้เปิดลิงก์นี้ใน Safari ก่อน แล้วทำตามนี้')) + '</p>' +
      '<ol>' + steps.map(function (s) { return '<li><span>' + s + '</span></li>'; }).join('') + '</ol>' +
      '<button type="button" class="osBtn" data-os-close>เข้าใจแล้ว</button></div>';
    function close() { document.removeEventListener('keydown', onKey); m.remove(); }
    function onKey(e) { if (e.key === 'Escape') close(); }
    m.addEventListener('click', function (e) { if (e.target === m || e.target.hasAttribute('data-os-close')) close(); });
    document.addEventListener('keydown', onKey);
    document.body.appendChild(m);
    m.querySelector('[data-os-close]').focus();
  }

  function hide() { if (bar) { bar.remove(); bar = null; } }

  function show() {
    if (bar || standalone() || snoozed() || !document.body) return;
    if (!document.getElementById('osInstallCss')) {
      var st = document.createElement('style');
      st.id = 'osInstallCss';
      st.textContent = CSS;
      document.head.appendChild(st);
    }
    bar = document.createElement('div');
    bar.className = 'osInstall';
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', 'ติดตั้งแอป');
    bar.innerHTML = '<img src="./icons/icon.svg" alt="">' +
      '<div class="osTxt"><b>ติดตั้งออมสุขลงเครื่อง</b><span>เปิดจากไอคอนบนหน้าจอได้ทันทีเหมือนแอป ไม่ต้องพิมพ์ลิงก์</span></div>' +
      '<button type="button" class="osBtn" data-os-install>' + (deferred ? 'ติดตั้ง' : 'วิธีติดตั้ง') + '</button>' +
      '<button type="button" class="osX" data-os-dismiss aria-label="ปิด ไม่ต้องติดตั้งตอนนี้">✕</button>';
    bar.querySelector('[data-os-install]').addEventListener('click', function () {
      if (deferred) {
        var d = deferred;
        deferred = null;
        d.prompt();
        Promise.resolve(d.userChoice).then(function (c) { if (c && c.outcome === 'accepted') hide(); }).catch(function () {});
      } else {
        guide();
      }
    });
    bar.querySelector('[data-os-dismiss]').addEventListener('click', function () { snooze(); hide(); });
    document.body.insertBefore(bar, document.body.firstChild);
  }

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    deferred = e;
    hide();
    show();
  });
  window.addEventListener('appinstalled', function () { deferred = null; hide(); });

  if (isIOS || isMacSafari) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', show);
    else show();
  }
})();
