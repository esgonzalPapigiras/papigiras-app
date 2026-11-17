# Migración visual Pilo

`main` es la aplicación funcional y `revision/pilo-2026-11-16` se utiliza
únicamente como referencia visual. No se fusionan las ramas ni se reemplazan
los servicios productivos por adaptadores LAB.

## Criterios

- Conservar autenticación, sesiones, FCM, ubicación, proveedores y contratos
  de API de `main`.
- Trasladar colores, jerarquía, espaciado, componentes y estados visuales.
- No inventar datos ni llamadas para funciones que todavía no existen en el
  backend productivo.
- Verificar cada checkpoint con análisis estático y compilación Android.

## Checkpoints

### Base visual, accesos y coordinador

- Tema global, selector de perfil y los tres accesos.
- Selector de gira y dashboard del coordinador.
- Se conservaron FCM, ubicación, sesiones y navegación productiva.
- No se incluyeron mapa embebido, galería, ranking ni estadísticas de aportes
  del mockup porque esas implementaciones no existen aún en `main`.

### Tripulación y documentos del coordinador

- Tripulación adopta encabezado, tarjeta oscura del bus, tarjetas de personas,
  actualización manual y estados de carga/error/vacío del mockup.
- Documentos adopta el listado y acciones visuales Pilo, conservando los
  endpoints existentes para ver y descargar archivos públicos de la gira.
- No se incluyeron documentos internos, vouchers ni carga de archivos. El
  mockup usa repositorios y almacenamiento privado que requieren trabajo de
  backend/Object Storage antes de poder integrarse correctamente.
