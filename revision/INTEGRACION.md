# Integración y configuración pendiente

La rama entrega el código completo de la candidata elegida por Camilo para revisar y probar. No incluye el historial de chats ni exige reaplicar parches PG. Las fuentes funcionales se conservaron respecto de los commits comprobados, salvo espacios finales documentados; ORIGEN.json permite verificarlo. README.md tiene los comandos de cada componente.

## Para probar la experiencia ahora

La app puede conectarse a la API de pruebas compatible, con datos ficticios y cuentas separadas por rol. Camilo dispone de un APK de beta y una conexión HTTPS temporal; compartir host/cuentas de forma privada. No se guardan en Git. La beta temporal requiere que el Mac de Camilo permanezca encendido. El frontend también permite API local en 127.0.0.1:18084 o 8084; Android por USB necesita adb reverse. El panel conserva su API local en 8084.

## Antes de reemplazar la versión oficial

| Parte | Estado probado | Trabajo pendiente para producción |
|---|---|---|
| Transporte/login | `lib/lab/api_http.dart`, `LabSession`, login de pruebas y permisos por rol/gira | Configurar transporte y JWT compatibles con el destino; conservar denegaciones por rol y pertenencia. No basta sustituir una URL. |
| Identidad backend | `LabAccessPolicy`, `LabPassengerTourIdentity`, `LabMedicalPassengerIdentity`, `LabPhotoLikeIdentity` | Adaptar a los tokens y relaciones oficiales; volver a verificar permisos cruzados. |
| Archivos/push | Filesystem privado y notificaciones locales; audio/documentos implementados | Adaptar Spaces/S3 privado y FCM con credenciales del entorno destino; probar acceso autorizado y avisos. |
| Ubicación | Mapa e hitos aprobados; ubicación del bus sintética | Integrar GPS/segundo plano y apagado remoto del bus si se incluirán en el release. |
| QR | Conteo en memoria y QR de pruebas | Confirmar formato QR oficial y resolver persistencia/sincronización si se necesita. |
| Base | Migraciones incluidas y probadas en copia aislada | Revisar esquema real e historial; respaldo y aplicación sólo de migraciones faltantes. Nunca ejecutar seed ni copia de contraseñas LAB sobre producción. |
| Tiendas | Android/iOS compilan en las versiones documentadas | Cámara, voz, QR, permisos y compartir en dispositivos físicos; firma propia, identificadores y configuración de tienda. |

Las migraciones están en `ms-papigiras-app/scripts/migrations/` y se resumen en `ms-papigiras-app/revision/MIGRACIONES.md`. Primero esquema/backend compatibles, después app/panel. No utilizar Hibernate update como migración productiva. No descartar las comprobaciones de seguridad para hacer funcionar endpoints antiguos.

## Alcance del diff

Flutter incluye los destinos iOS/Android probados; los otros targets del proyecto original no forman parte de esta candidata. La configuración actual conserva identificadores de pruebas y no incluye Firebase, firmas ni secretos oficiales. El backend conserva barreras locales que deliberadamente impiden apuntarlo a la base oficial. La beta HTTPS opcional de INT-006 se incluye sin host ni claves.

No hay workflow nuevo de despliegue. El push es para revisión, no merge ni publicación. Las bases y sus verificaciones están en ORIGEN.json. El respaldo LAB y los entornos activos se mantienen intactos.

## Reconciliación con GitHub del 16/11/2026

App y panel siguen sobre las mismas bases oficiales. El backend parte ahora de `947419a`, que Esteban añadió después de la copia inicial. Se conservaron sus fotos HD y miniaturas, nombres únicos, límites de carga, limpieza y texto de notificación. Pilo mantiene fotos completas en `images`, IDs estables en `imageIds`, audio y permisos; se añaden `thumbnails`/`photoIds` y lectura de foto con autorización por gira. La integración productiva de FCM sigue pendiente; se conserva el aviso local de pruebas. No hay migraciones nuevas en esta reconciliación. Suite backend de la rama: **475 pruebas aprobadas**, sin fallos, errores ni omisiones. No se reinició ningún servicio activo.
