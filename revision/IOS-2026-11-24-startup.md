# iOS 27: corrección de arranque para revisión

Base: `488faa2` de `origin/main`. Revisión de Apple: **1.1.4 (5)**,
iPad Air de 11 pulgadas (M3), iPadOS 27.0, envío
`fdbf3ed2-f330-4736-9146-8a35ea081988`.

## Diagnóstico y alcance

El proyecto no declaraba `UIApplicationSceneManifest` y registraba los plugins
y el canal de credenciales desde `didFinishLaunchingWithOptions`, accediendo a
`window.rootViewController`. La [guía oficial de Flutter](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
indica que las aplicaciones compiladas con Xcode 27 necesitan el ciclo de vida
UIScene para arrancar. **La causa queda confirmada por los cuatro crash logs
recibidos el 25/11/2026:** UIKit detiene la aplicación por no adoptar ese ciclo
de vida. La validación nativa de la corrección sigue pendiente.

### Evidencia de los crash logs

Los cuatro archivos corresponden a `com.papigiras`, versión **1.1.4 (5)**,
OS **27.0 (24A437)**, y al mismo ejecutable Runner arm64 con UUID
`e2f7a8c5-6051-358b-a378-7fc53520c849`.

| Incidente | Dispositivo registrado | Resultado |
|---|---|---|
| `73727496-514F-4B01-9D8A-31555E08627B` | `iPad15,3` | Mismo trap de UIScene |
| `7A7D9ABD-AF9B-429C-8EE8-EA94C318D971` | `iPad15,3` | Mismo trap de UIScene |
| `DCD8FC7E-8B73-492B-BF48-E0BDF8ECECF2` | `iPad15,3` | Mismo trap de UIScene |
| `5A426AF1-5D9F-4AEC-B115-5491A8E30CD3` | `iPhone18,2` | Mismo trap de UIScene |

En todos: excepción `EXC_BREAKPOINT`, señal `SIGTRAP`, hilo 0
(`com.apple.main-thread`), terminación `SIGNAL / Trace/BPT trap: 5`.
Primer frame, ya simbolicado en los archivos:

```text
UIKitCore: ___UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke
libdispatch: _dispatch_client_callout
libdispatch: _dispatch_once_callout
UIKitCore: -[UIApplication workspace:didCreateScene:withTransitionContext:completion:]
UIKitCore: -[UIApplicationSceneClientAgent scene:didInitializeWithEvent:completion:]
```

Es una detención de UIKit durante la creación de la escena. Los logs no muestran
una caída por una petición al backend ni por la lógica Dart del GPS. Hay un
frame Runner sin símbolo, desplazamiento `22080` (`0x5640`); para simbolicarlo
se necesitarían los dSYM del UUID anterior. **No se realizó una simbolicación
completa**, pero el símbolo del punto de fallo del sistema identifica la causa
sin necesitar ese frame adicional. Los archivos originales se mantienen fuera
del repositorio, sin copiar identificadores del dispositivo ni registros crudos.

Se revisó y aplicó `arranque-ios.patch`, aportado por el usuario:

- `Info.plist` declara una escena `FlutterSceneDelegate`, con el storyboard
  existente `Main` y sin habilitar múltiples escenas.
- `AppDelegate` implementa `FlutterImplicitEngineDelegate`; registra plugins y
  conecta el canal de credenciales al messenger del motor ya inicializado.
- El callback del motor GPS sin interfaz se instala antes de crear la escena.
  Se conserva el código de Keychain, los permisos, Firebase y los modos de fondo.
- `RunnerTests` comprueba la conexión de la escena, el controlador Flutter,
  el registro del plugin GPS y el primer frame. Se añadió una espera para la
  conexión de la escena, evitando depender de cuándo arranca el bundle de tests.

Flutter 3.38.10 ya incluye las APIs utilizadas. Su implementación de
`FlutterPluginAppLifeCycleDelegate` conserva callbacks de compatibilidad para
plugins que aún usan eventos de aplicación. No se actualizó Flutter ni se
modificó el plugin GPS en esta corrección; sus flujos de fondo requieren la
comprobación funcional posterior a la migración.

## Verificación disponible

- Plists analizados correctamente; storyboard de la escena existente;
  permisos de ubicación/notificaciones y proxy Firebase conservados.
- `git diff --check` sin errores.
- Los cuatro informes de Apple se analizaron y compararon: misma causa de
  terminación, versión y UUID de Runner; tres iPad y un iPhone.
- **35 regresiones Dart aprobadas**: credenciales guardadas, recuperación GPS e identidad de la
  aplicación conectada. Registro local: `build/ios-startup-regressions.log`.
  Estas pruebas usan dobles de prueba y no verifican UIKit ni Keychain nativo.
- **Pendiente:** compilar Swift con Xcode 27, ejecutar `RunnerTests` en iPadOS 27
  y probar el archivo Release en un dispositivo. El equipo de trabajo es Windows
  y no hay un Mac remoto conectado. El resultado comunicado por el autor del
  parche en simuladores 26.5 no se presenta como una ejecución realizada aquí.

## Validación en Mac / Xcode Cloud antes de volver a enviar

1. Diagnóstico de los cuatro informes completado arriba. Conservar los dSYM del
   build 5 si se necesita simbolicar el frame Runner restante y los del nuevo
   archivo para cualquier incidencia posterior. No usar dSYM de otro build.
2. En un Mac con Flutter 3.38.10 y Xcode 27, preparar las dependencias mediante
   `flutter pub get --enforce-lockfile`. Seleccionar un simulador iPad Air M3
   con iPadOS 27 desde `xcrun simctl list devices available`.
3. Desde la raíz del repositorio, configurar la app y ejecutar el test hospedado
   (asignar `PAPIGIRAS_IPAD_UDID` al identificador real del simulador):

   ```sh
   flutter build ios --simulator --debug \
     --dart-define=PAPIGIRAS_API_URL=https://stingray-app-9tqd9-djh6d.ondigitalocean.app
   xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
     -destination "platform=iOS Simulator,id=$PAPIGIRAS_IPAD_UDID" \
     -only-testing:RunnerTests/RunnerTests/testLaunchDisplaysFlutterInAnApplicationScene \
     -resultBundlePath build/ios27-launch.xcresult
   ```

4. Repetir en iPhone iOS 27 y comprobar visualmente que aparece la selección de
   perfil. Probar credenciales con cuentas de prueba, segundo plano/primer plano,
   GPS del coordinador y apertura de notificaciones. No usar datos reales en QA.
5. En Xcode Cloud, construir este cambio con Xcode 27 y añadir una acción Test
   de la suite `RunnerTests` para iPadOS 27. Archivar la configuración Release
   para **1.1.4 con un build nuevo mayor que 5**. El script existente utiliza
   `CI_BUILD_NUMBER` y mantiene el número iOS separado del Android **16**.
6. Instalar el nuevo build desde TestFlight y verificar un arranque limpio en
   iPad antes de adjuntarlo a la revisión. Una compilación o un test Dart exitoso
   no acredita que el cierre de Apple esté resuelto.

No se ha subido ni reenviado un build iOS con este cambio.
