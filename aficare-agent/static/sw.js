/**
 * AfiCare MediLink - Service Worker
 * Enables offline functionality and caching for PWA
 */

const CACHE_NAME = 'aficare-medilink-v1';
const OFFLINE_URL = '/offline.html';

// Assets to cache immediately on install
const PRECACHE_ASSETS = [
  '/',
  '/offline.html',
  '/assets/icon-192x192.png',
  '/assets/icon-512x512.png',
  '/assets/logo.svg',
  '/static/manifest.json'
];

// Install event - cache core assets
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[ServiceWorker] Pre-caching offline assets');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => {
        console.log('[ServiceWorker] Skip waiting');
        return self.skipWaiting();
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[ServiceWorker] Activate');

  event.waitUntil(
    caches.keys().then((keyList) => {
      return Promise.all(keyList.map((key) => {
        if (key !== CACHE_NAME) {
          console.log('[ServiceWorker] Removing old cache', key);
          return caches.delete(key);
        }
      }));
    }).then(() => {
      console.log('[ServiceWorker] Claiming clients');
      return self.clients.claim();
    })
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Skip WebSocket connections (Streamlit uses these)
  if (event.request.url.includes('_stcore') ||
      event.request.url.includes('healthz') ||
      event.request.url.includes('stream')) {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          // Return cached version
          return cachedResponse;
        }

        // Try network
        return fetch(event.request)
          .then((networkResponse) => {
            // Cache successful responses
            if (networkResponse && networkResponse.status === 200) {
              const responseToCache = networkResponse.clone();

              caches.open(CACHE_NAME)
                .then((cache) => {
                  // Only cache same-origin requests
                  if (event.request.url.startsWith(self.location.origin)) {
                    cache.put(event.request, responseToCache);
                  }
                });
            }

            return networkResponse;
          })
          .catch(() => {
            // Network failed, try to return offline page for navigation requests
            if (event.request.mode === 'navigate') {
              return caches.match(OFFLINE_URL);
            }

            // For other requests, return a simple error response
            return new Response('Offline', {
              status: 503,
              statusText: 'Service Unavailable'
            });
          });
      })
  );
});

// Background sync for offline consultations
self.addEventListener('sync', (event) => {
  console.log('[ServiceWorker] Sync event:', event.tag);

  if (event.tag === 'sync-consultations') {
    event.waitUntil(syncConsultations());
  }
});

// Sync offline consultations when back online
async function syncConsultations() {
  try {
    // Get pending consultations from IndexedDB
    const db = await openDB();
    const tx = db.transaction('pending-consultations', 'readonly');
    const store = tx.objectStore('pending-consultations');
    const pendingConsultations = await store.getAll();

    for (const consultation of pendingConsultations) {
      try {
        // Send to server
        const response = await fetch('/api/consultations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(consultation)
        });

        if (response.ok) {
          // Remove from pending
          const deleteTx = db.transaction('pending-consultations', 'readwrite');
          const deleteStore = deleteTx.objectStore('pending-consultations');
          await deleteStore.delete(consultation.id);
        }
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync consultation:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Sync failed:', error);
  }
}

// Push notification support
self.addEventListener('push', (event) => {
  console.log('[ServiceWorker] Push received');

  const options = {
    body: event.data ? event.data.text() : 'New update from AfiCare MediLink',
    icon: '/assets/icon-192x192.png',
    badge: '/assets/icon-72x72.png',
    vibrate: [100, 50, 100],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      { action: 'view', title: 'View' },
      { action: 'dismiss', title: 'Dismiss' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('AfiCare MediLink', options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('[ServiceWorker] Notification click');

  event.notification.close();

  if (event.action === 'view') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

console.log('[ServiceWorker] Service Worker loaded');
