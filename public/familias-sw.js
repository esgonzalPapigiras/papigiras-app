'use strict';

// Only the public entry navigation has an offline response. API requests,
// account information, maps, photos and medical records bypass this worker.
const entrada = new URL(self.registration.scope);
self.addEventListener('fetch', evento => {
  const peticion = evento.request;
  if (peticion.mode !== 'navigate' || peticion.method !== 'GET') return;
  const url = new URL(peticion.url);
  if (url.origin !== entrada.origin || url.pathname !== entrada.pathname) return;
  evento.respondWith(fetch(peticion).catch(() => new Response(
    '<!doctype html><html lang="es-CL"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Papigiras</title><body style="font:1.1rem/1.5 system-ui;padding:8vw;color:#18332f;background:#f8f6ee"><h1>Papigiras</h1><p>Necesitas conexión para abrir tu gira.</p><p><a href="./">Volver a intentar</a></p></body></html>',
    {status: 503, headers: {'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store'}}
  )));
});
