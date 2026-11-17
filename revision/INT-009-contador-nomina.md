# INT-009 · Contador y nómina por HTTPS — 17/11/2026

Corrección móvil: la consulta de pasajeros enviaba un POST JSON sin cuerpo. Funcionaba localmente (HTTP 200), pero la conexión HTTPS de pruebas lo rechazaba (HTTP 400). El Contador y la nómina comparten esta consulta. La rama entregada el 16/11 contenía el mismo código que el APK afectado.

`LabApiClient` envía ahora `{}` cuando un POST JSON no tiene contenido. Conserva cuerpos existentes, GET, otros formatos y cargas multipart. No cambian backend, base, permisos ni contratos. Esteban sólo necesita incorporar este commit y recompilar la app; no hay migración ni reinicio de API.

Validación: 68 pruebas focalizadas locales; 4 con configuración HTTPS; consulta real desde el provider Flutter por el túnel vigente con 114, 49 y 47 pasajeros ficticios. Comprobación de aislamiento y `git diff --check` aprobadas. Los scripts HTTP anteriores añadían `{}` automáticamente y no reproducían el POST vacío de Flutter; se añadió regresión con el provider real y prueba del transporte.

Archivos: `lib/lab/api_http.dart`, `test/passenger_loading_transport_test.dart`.

El APK remoto v3 usa la misma firma e identificador y se instala sobre v2. La comprobación física final en Android corresponde al probador; no se ha efectuado desde este Mac. No se modificó producción, web ni LAB original. Reversión: revertir este commit y recompilar; no hay cambios de datos que revertir.
