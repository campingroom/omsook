/* ออมสุข — ทำให้ติดตั้งเป็นแอปได้ และเปิดหน้าแอปได้แม้เน็ตหลุด
 * ไฟล์ของแอป: โหลดจากเน็ตก่อนเสมอ (ได้รุ่นใหม่ทันที) ถ้าโหลดไม่ได้จึงใช้ที่เก็บไว้
 * ฟอนต์ และไลบรารีที่ล็อกรุ่นไว้ (React จาก unpkg, supabase-js จาก jsDelivr): ใช้ที่เก็บไว้ก่อน
 * ไม่แตะคำขอไป Supabase (ข้อมูลห้องเรียน/ล็อกอิน) — ต้องออนไลน์เท่านั้น */
const CACHE = 'omsook-v2';
const ASSETS = ['./', 'support.js', 'pwa.js', 'manifest.webmanifest', 'icons/icon.svg', 'icons/icon-192.png', 'icons/favicon-32.png'];
const PINNED = ['fonts.googleapis.com', 'fonts.gstatic.com', 'cdn.jsdelivr.net', 'unpkg.com'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const pinned = PINNED.includes(url.hostname);
  if (url.origin !== self.location.origin && !pinned) return;

  if (pinned) {
    e.respondWith(caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res.ok || res.type === 'opaque') { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
      return res;
    })));
    return;
  }

  e.respondWith(fetch(req).then((res) => {
    if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
    return res;
  }).catch(() => caches.match(req, { ignoreSearch: true })
    .then((hit) => hit || (req.mode === 'navigate' ? caches.match('./') : Response.error()))));
});
