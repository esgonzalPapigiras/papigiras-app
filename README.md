# Pilo · entrega para revisión de Esteban

> **Estado de este checkout, 20/11/2026:** la rama `codex/pilo-integration-2026` contiene la integración local en curso. Conserva la interfaz Pilo y ya incorpora identidad oficial `com.papigiras`, Firebase/APNs, GPS nativo y contratos privados de la API. Las secciones originales de entrega que siguen describen la referencia del 16/11, no el estado completo de esta integración. No se ha desplegado ni verificado entrega de notificaciones en teléfonos.

Para probar en Windows desde este checkout, usar `powershell -ExecutionPolicy Bypass -File .\scripts\run_connected.ps1`. El lanzador selecciona Flutter **3.38.10** del directorio de herramientas del backend y añade la URL oficial. Acepta `-Device ID`, `-FlutterSdk RUTA` y `-CheckOnly` (sólo comprueba configuración, sin compilar ni instalar). VS Code también tiene una configuración `PapiGiras - connected Android/iOS` con ese SDK y URL; requiere ambos repositorios como carpetas hermanas. Esto no cambia el Flutter global del equipo. Un `flutter run` escrito directamente en una terminal ya abierta puede seguir usando el SDK global y además omite el destino conectado.

Para compilar el candidato conectado con Flutter **3.38.10**, después de preparar el backend compatible:

```sh
flutter build apk --debug --dart-define=PAPIGIRAS_API_URL=https://stingray-app-9tqd9-djh6d.ondigitalocean.app
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`. Sin ese define se conserva el entorno de referencia LAB. La rama backend necesita sus migraciones aditivas V8–V15 y los servicios correspondientes; cambiar sólo la URL no instala esas dependencias. V15 conserva un registro de limpieza de fotos para que un fallo de base de datos no elimine archivos de un hito todavía visible. El QR oficial y los contactos están integrados y probados localmente. La app iOS y sus Pods requieren iOS/iPadOS 15.0 o posterior para compilar con Xcode 27.2. Xcode Cloud usa `ios/ci_scripts/ci_post_clone.sh` y por defecto el mismo origen HTTPS indicado arriba; `PAPIGIRAS_API_URL` es una sustitución opcional. Para iOS toma `CI_BUILD_NUMBER` automáticamente y acepta desde 2 porque ya existe `1.1.3 (1)` en App Store Connect. Esto no altera el `+17` compartido ni la validación de Android y de las compilaciones conectadas locales. La versión de iOS en Xcode Cloud es `1.1.4` por defecto (definida en `ci_post_clone.sh`), independiente de Android (`1.1.3+17` en `pubspec.yaml`). `PAPIGIRAS_BUILD_NAME` permite sustituirla si hace falta; si reutilizas otra versión que ya tiene builds en App Store Connect, verifica primero que el próximo número de Xcode Cloud sea mayor que todos los de esa versión. La compilación iOS y la aceptación visual/en dispositivos siguen pendientes. No es aún un candidato de release verificado.

También se compiló el AAB conectado con `flutter build appbundle --release --dart-define=PAPIGIRAS_API_URL=https://stingray-app-9tqd9-djh6d.ondigitalocean.app`. Está en `build/app/outputs/bundle/release/app-release.aab`, **sin firma** porque este equipo no tiene `android/key.properties`. Se restauró el contrato oficial de ese archivo ignorado por Git (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); cuando esté disponible debe usar la clave original, nunca una clave de prueba. El APK debug tampoco puede actualizar una instalación firmada por Play. Los hashes, comandos y límites están en `../ms-papigiras-app/docs/pilo-integration/ANDROID-ARTIFACT-EVIDENCE.md`.

En este checkout la primera compilación release con `--no-pub` encontró un registrador generado que aún incluía `integration_test`. La compilación normal regeneró correctamente la lista y pasó sin modificar el lockfile. No copiar ni editar manualmente `GeneratedPluginRegistrant.java`; conservar el paso normal de preparación de Flutter.

Verificación local actual: 996 pruebas Flutter aprobadas, 32 omisiones dependientes de configuración; 22 pruebas GPS/QR conectadas y una de identidad visual aprobadas por separado con destino simulado; compilación Android debug conectada correcta. Once pantallas de fixtures comparadas contra Pilo en variantes Android/iOS: 42/44 capturas idénticas, con diferencias sólo dentro del QR oficial del alumno. No son capturas de teléfonos ni aceptación completa. El análisis de `lib test integration_test tool` no tiene errores y mantiene ocho avisos heredados. El análisis global también incluye errores antiguos del ejemplo del plugin GPS vendorizado, que no forma parte del APK. El registro completo y los límites están en `../ms-papigiras-app/docs/pilo-integration/CHECKPOINT.md`, `VISUAL-MEDIA-EVIDENCE.md`, `GPS-SHARING.md` y `QR-CONTACT-BUILDS.md`.

Esta rama contiene la versión renovada elegida por Camilo. Es una candidata de pruebas, con frontend y backend compatibles; **no reemplazar producción ni fusionar directamente a main**. La interfaz corresponde a la versión probada en simulador y a la beta Android. No se incluyen datos de pasajeros, contraseñas reales, firmas, bases de datos ni el túnel temporal.

## Qué cambió

- Interfaz Pilo, navegación uniforme por perfil e inicio con mapa para familias.
- Mapa, selección de hitos, bitácora, fotos, galería y notas de voz de hasta 60 segundos.
- Nómina con buscador, filtros, dietas, fotos y acceso a fichas; contador QR.
- Ficha médica consistente, lectura bloqueada, edición por apoderado con nueva aceptación y PDF vigente sin marca, nombrado por alumno y RUT.
- Documentos internos/vouchers, tripulación y varios coordinadores por gira; permisos por rol, pasajero y gira.

## Repositorios de esta entrega

Usar la rama `revision/pilo-2026-11-16` de los tres repositorios de `esgonzalPapigiras`: `papigiras-app` (Flutter), `ms-papigiras-app` (API) y `papigiras-dashboard` (Angular). Cada repositorio tiene su commit y manifiesto `revision/ORIGEN.json`. No aplicar además los parches PG históricos: estas fuentes ya los contienen.

## Lo imprescindible antes de integrar a producción

La revisión distingue la experiencia aprobada de los adaptadores de pruebas. Autenticación/JWT, filesystem privado en lugar de Spaces, notificaciones locales en lugar de FCM y bloqueo a API local son parte del entorno de prueba. **No son únicamente variables de entorno: todavía requieren adaptación y pruebas para usar los servicios oficiales.** GPS del bus es sintético; contador QR está en memoria y falta confirmar el QR oficial. No se presentan como funciones productivas terminadas.

Primero probar esta candidata aislada; después resolver esos adaptadores, revisar migraciones sobre copia de base y validar cámara/micrófono/QR/PDF en teléfonos. Sólo entonces preparar despliegue y tiendas. `revision/INTEGRACION.md` identifica los puntos concretos y los límites. La rama no publica ni despliega automáticamente.

## Evidencia disponible

La candidata base pasó 468 pruebas backend, 138 comprobaciones HTTP con datos ficticios, 959 pruebas Flutter más 46 pruebas focalizadas de PDF y 87 comprobaciones del panel con compilación. La variante beta posterior verificó transporte HTTPS, permisos, audio/fotos/PDF y firma APK; la prueba física Android/iPhone sigue pendiente. Estos resultados pertenecen a las fuentes identificadas en el manifiesto, no certifican producción. Las comprobaciones de empaquetado de esta rama se registran en `revision/VERIFICACION.json`.

## Probar la app

Requisitos: Flutter 3.38.10 / Dart 3.10.9, SDK Android; para iOS, macOS con Xcode y CocoaPods. La dependencia QR modificada está incluida en `third_party/`.

```sh
flutter pub get
python3 scripts/check_isolation.py
flutter run --dart-define=PAPIGIRAS_LOCAL_API_PORT=18084 --dart-define=PILO_HIDE_LAB_BANNER=true
```

Ese comando necesita la API compatible en el mismo equipo, puerto 18084. Android conectado por USB requiere `adb reverse tcp:18084 tcp:18084`. Para usar la beta remota ya preparada, compilar con `--dart-define=PAPIGIRAS_PREVIEW_HOST=HOST_TEMPORAL` en lugar del puerto; solicitar a Camilo el host vigente y las cuentas ficticias por canal privado. El host se fija al compilar y sólo admite el túnel de pruebas previsto. No cambiarlo por producción.

Los IDs siguen separados de la app oficial. La firma release de pruebas requiere una clave propia externa al repositorio; `flutter run` usa desarrollo. No se incluyen claves ni se ha preparado firma de tienda. Para repetir pruebas: `python3 revision/validar.py`; las pruebas HTTP/native se ejecutan aparte contra fixtures.

## Reconciliación con GitHub del 16/11/2026

App y panel siguen sobre las mismas bases oficiales. El backend parte ahora de `947419a`, que Esteban añadió después de la copia inicial. Se conservaron sus fotos HD y miniaturas, nombres únicos, límites de carga, limpieza y texto de notificación. Pilo mantiene fotos completas en `images`, IDs estables en `imageIds`, audio y permisos; se añaden `thumbnails`/`photoIds` y lectura de foto con autorización por gira. La integración productiva de FCM sigue pendiente; se conserva el aviso local de pruebas. No hay migraciones nuevas en esta reconciliación. Suite backend de la rama: **475 pruebas aprobadas**, sin fallos, errores ni omisiones. No se reinició ningún servicio activo.

## Corrección del 17/11/2026

Contador y nómina: corregido el POST vacío que fallaba por HTTPS. Sólo móvil; sin migraciones ni cambios backend. [Detalle breve y pruebas](revision/INT-009-contador-nomina.md).
