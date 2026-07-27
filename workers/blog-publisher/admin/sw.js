/* Service worker del gestionale blog Momentum.
 *
 * Obiettivi:
 *  - rendere il pannello installabile come PWA (Android/iOS/desktop);
 *  - far partire subito la shell anche con rete lenta/assente.
 *
 * Regole di sicurezza: NON mette mai in cache le API né le immagini del
 * blog (/api/*, /articles/*, /health, /blog/*) e ignora le richieste
 * cross-origin (es. la CDN di Toast UI): quei contenuti passano sempre
 * dalla rete per non servire dati amministrativi obsoleti.
 */
'use strict';

var CACHE = 'momentum-admin-v1';

// Shell statica dell'app (stesso host).
var SHELL = [
  '/',
  '/index.html',
  '/app.js',
  '/styles.css',
  '/manifest.webmanifest',
  '/icon-192.png',
  '/icon-512.png',
  '/apple-touch-icon.png',
  '/favicon-32.png',
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      return cache.addAll(SHELL);
    }).then(function () {
      return self.skipWaiting();
    }),
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.map(function (key) {
          return key === CACHE ? null : caches.delete(key);
        }),
      );
    }).then(function () {
      return self.clients.claim();
    }),
  );
});

self.addEventListener('fetch', function (event) {
  var request = event.request;

  // Solo GET e solo stesso host: tutto il resto passa dalla rete.
  if (request.method !== 'GET') {
    return;
  }

  var url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  // Contenuti dinamici / amministrativi: mai in cache.
  if (
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/articles/') ||
    url.pathname.startsWith('/blog/') ||
    url.pathname === '/health'
  ) {
    return;
  }

  // Navigazioni (apertura app): rete con fallback alla shell in cache.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(function () {
        return caches.match('/index.html').then(function (cached) {
          return cached || caches.match('/');
        });
      }),
    );
    return;
  }

  // Asset statici: stale-while-revalidate.
  event.respondWith(
    caches.match(request).then(function (cached) {
      var network = fetch(request)
        .then(function (response) {
          if (response && response.ok) {
            var copy = response.clone();
            caches.open(CACHE).then(function (cache) {
              cache.put(request, copy);
            });
          }
          return response;
        })
        .catch(function () {
          return cached;
        });
      return cached || network;
    }),
  );
});
