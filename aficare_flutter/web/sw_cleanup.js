// Replaces Flutter's caching service worker for visitors who still have it.
//
// Browsers re-check a registered worker's script on each visit. When an old
// AfiCare worker finds this file at flutter_service_worker.js, it installs
// it; this worker then deletes every cache the old one made, unregisters
// itself and reloads open tabs, so they fetch the current build. After
// that, nothing is cached and every deploy shows up on the next visit.
//
// Copied over build/web/flutter_service_worker.js by the deploy workflow
// (see .github/workflows/flutter.yml). Do not register it anywhere.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.registration.unregister(); })
      .then(function () { return self.clients.matchAll({ type: 'window' }); })
      .then(function (clients) {
        clients.forEach(function (c) { c.navigate(c.url); });
      })
  );
});
