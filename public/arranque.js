'use strict';

const entrada = document.getElementById('entrada');
const carga = document.getElementById('carga');
const instalar = document.getElementById('instalar');
const ingresar = document.getElementById('ingresar');
const ayuda = document.getElementById('ayuda');
const estado = document.getElementById('estado');
const modoVentana = window.matchMedia('(display-mode: standalone)');
const recordatorio = 'papigiras.entrada-abierta';
let solicitudInstalacion;
let iniciada = false;

function mensaje(texto) {
  ayuda.textContent = texto;
  ayuda.hidden = false;
}

function mostrarPasos() {
  const agente = navigator.userAgent;
  const apple = /iPhone|iPad|iPod/.test(agente) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  let pasos;
  if (apple) {
    pasos = ['En Safari, toca Compartir (el cuadrado con la flecha hacia arriba). Si está oculto, toca el menú Más.',
      'Elige Agregar a inicio. Si aparece Abrir como app, déjalo activado.',
      'Toca Agregar.'];
  } else if (/SamsungBrowser/i.test(agente)) {
    pasos = ['Toca el menú ☰ de Samsung Internet.',
      'Elige Agregar página a y después Pantalla de inicio.', 'Confirma con Agregar.'];
  } else if (/Android/i.test(agente)) {
    pasos = ['Toca el menú de los tres puntos ⋮.',
      'Elige Instalar aplicación o Agregar a la pantalla principal.', 'Confirma con Instalar o Agregar.'];
  } else {
    pasos = ['Abre el menú del navegador.', 'Busca Instalar aplicación o Agregar a la pantalla de inicio.'];
  }
  mensaje('Para dejar el ícono en tu pantalla de inicio');
  const lista = document.createElement('ol');
  for (const paso of pasos) {
    const item = document.createElement('li');
    item.textContent = paso;
    lista.append(item);
  }
  const detalles = document.createElement('details');
  detalles.open = /WhatsApp|FB_IAB|FBAV|Instagram|; wv\)/i.test(agente);
  const titulo = document.createElement('summary');
  titulo.textContent = 'Lo abrí desde WhatsApp';
  const ayudaExterna = document.createElement('p');
  ayudaExterna.textContent = apple
    ? 'En el menú del enlace, elige Abrir en Safari. Luego toca Instalar Papigiras.'
    : 'Si falta la opción de instalar, abre el menú del enlace y elige Abrir en el navegador. Luego toca Instalar Papigiras.';
  detalles.append(titulo, ayudaExterna);
  ayuda.append(lista, detalles);
}

window.addEventListener('beforeinstallprompt', evento => {
  evento.preventDefault();
  solicitudInstalacion = evento;
  if (!ayuda.hidden) mensaje('Tu navegador ya puede instalar Papigiras. Toca Instalar Papigiras para confirmar.');
});
window.addEventListener('appinstalled', () => {
  solicitudInstalacion = undefined;
  instalar.hidden = true;
  ingresar.textContent = 'Ingresar ahora';
  mensaje('Papigiras se instaló. Puedes abrirla desde el ícono de tu pantalla de inicio.');
});

instalar.addEventListener('click', async () => {
  const evento = solicitudInstalacion;
  if (!evento) {
    mostrarPasos();
    return;
  }
  solicitudInstalacion = undefined;
  instalar.disabled = true;
  try {
    // Invoke the system dialog while this trusted tap still has user activation.
    await evento.prompt();
    const decision = await evento.userChoice;
    if (!instalar.hidden) {
      mensaje(decision.outcome === 'accepted'
        ? 'Tu teléfono está preparando el ícono. También puedes ingresar ahora.'
        : 'Puedes instalar Papigiras más tarde o ingresar desde el navegador.');
    }
  } catch {
    mostrarPasos();
  } finally {
    instalar.disabled = false;
  }
});

function abrir() {
  if (iniciada) return;
  iniciada = true;
  entrada.hidden = true;
  carga.hidden = false;
  const lento = setTimeout(() => {
    estado.textContent = 'La carga está tardando. Revisa tu conexión y vuelve a abrir Papigiras.';
  }, 20000);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(lento);
    entrada.remove();
    carga.remove();
  }, {once: true});
  const flutter = document.createElement('script');
  flutter.src = new URL('flutter_bootstrap.js', document.baseURI).href;
  flutter.onerror = () => {
    clearTimeout(lento);
    estado.textContent = 'No pudimos cargar Papigiras. Revisa tu conexión y vuelve a abrir el enlace.';
  };
  document.head.append(flutter);
}

ingresar.addEventListener('click', () => {
  try { sessionStorage.setItem(recordatorio, '1'); } catch { /* Storage is optional. */ }
  abrir();
});

if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register(new URL('familias-sw.js', document.baseURI))
    .catch(() => { /* Login also works when private browsing disables workers. */ });
}
let accesoPrevio = false;
try { accesoPrevio = sessionStorage.getItem(recordatorio) === '1'; } catch { /* Optional. */ }
if (modoVentana.matches || navigator.standalone === true || accesoPrevio) {
  abrir();
} else {
  carga.hidden = true;
  entrada.hidden = false;
}
