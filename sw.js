/* Locks by Afro — service worker (app shell) */
const CACHE = 'lba-v7';
const ASSETS = ['./', './index.html', './admin.html', './config.js', './manifest.json', './icon-192.png', './icon-512.png', './apple-touch-icon.png', './favicon-32.png', './logo.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  e.respondWith(
    caches.match(req).then(hit => hit || fetch(req).catch(() => {
      if (req.mode === 'navigate') return caches.match('./index.html');
    }))
  );
});
