{{flutter_js}}
{{flutter_build_config}}

// AfiCare does not use a service worker. Flutter's default one cached the
// whole app, so after every deploy returning visitors kept getting the old
// build (or a blank page) until they cleared site data. Load the app
// straight from the network instead, and remove any worker a previous
// build installed, with its caches. The worker file that replaces it
// (sw_cleanup.js, copied over flutter_service_worker.js at deploy) does the
// same for visitors whose old worker still serves them the old page.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (registrations) {
    registrations.forEach(function (r) { r.unregister(); });
  });
}
if ('caches' in window) {
  caches.keys().then(function (keys) {
    keys.forEach(function (k) { caches.delete(k); });
  });
}

_flutter.loader.load();
