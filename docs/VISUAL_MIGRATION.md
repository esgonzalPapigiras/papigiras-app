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

### Actividades y perfil del coordinador

- Actividades adopta encabezado, formularios, botones, tarjetas y estados Pilo
  conservando los endpoints existentes de itinerarios y registro.
- El perfil adopta la composición visual del mockup sin perder la carga y
  actualización de foto que ya existía en `main`.
- El cambio de contraseña continúa usando la validación y el endpoint
  productivo actual. No se incorporó el almacenamiento seguro de credenciales
  del mockup porque pertenece a una funcionalidad posterior.

### Programa del coordinador

- Programa adopta las tarjetas Pilo para curso, fechas y actividades, además
  de encabezado compacto y estados de carga, error y ausencia de datos.
- Se conserva `getviewProgram`, el identificador productivo de la gira y el
  menú real del coordinador; también se agregó actualización manual.
- No se importaron el tema paralelo ni los helpers de datos del prototipo. La
  vista usa los tokens visuales compartidos de producción.

### Fichas médicas del coordinador

- Se incorporaron el resumen oscuro, las tarjetas Pilo por pasajero, el orden
  por apellido, recarga mediante gesto y estados de carga/error/vacío.
- Se conservaron la consulta productiva de pasajeros y las acciones reales de
  editar, visualizar, descargar y compartir cada ficha guardada.
- La edición sigue regresando a esta vista y actualizando el listado. No se
  añadieron campos, permisos ni contratos de backend del prototipo.

### Detalle de bitácora del coordinador

- El detalle adopta encabezado compacto, tarjeta Pilo, galería adaptable,
  recarga, errores recuperables y confirmación de eliminación integrada.
- Se preservaron la carga autenticada de fotografías, la vista de imagen
  completa, el borrado productivo y el permiso `canModify` entregado por el
  servidor.
- No se incorporaron edición de hitos, audio ni ubicación/mapa del prototipo:
  son funcionalidades nuevas que requieren una etapa posterior.

### Bitácora del coordinador

- El listado adopta la línea de tiempo, tarjetas Pilo, recarga por gesto y
  estados de carga/error/vacío, manteniendo autor, fecha, hora y ubicación.
- Se conserva `getBinnacle`, el permiso de modificación entregado por cada
  registro y la navegación al detalle productivo.
- No se incorporaron mapa embebido ni creación georreferenciada de hitos; son
  funcionalidades nuevas del prototipo y no simples cambios visuales.

### Pasajeros del coordinador

- El listado adopta buscador, orden A–Z/Z–A, contador de resultados, tarjetas
  Pilo, recarga por gesto y estados de carga/error/vacío.
- Se conserva `getListPassenger`, el RUT y el estado real de ficha médica de
  cada pasajero; la búsqueda y el orden se ejecutan localmente.
- No se incorporaron fotografías, filtros por sexo/rol/dieta ni datos clínicos
  adicionales porque `main` no recibe todavía esos campos y servicios.

### Contador de pasajeros

- El contador adopta resumen oscuro, controles Pilo, estado visible del último
  cambio, tarjetas compactas y un marco claro para el lector QR.
- Se conservan `getListPassenger`, el lector de cámara real, la extracción de
  `tourPassenger` y el conteo manual que ya existían en `main`.
- El reinicio ahora pide confirmación. No se importó la sesión temporal ni el
  contador rápido en hoja del prototipo porque cambian el comportamiento y no
  persisten asistencia en el backend actual.

### Creación de hitos

- El formulario adopta encabezado, grupos, campos, selector fotográfico y
  acción principal Pilo, mostrando ubicación y progreso de publicación.
- Se conservan GPS/geocodificación, permisos reales de cámara y galería,
  `addHito`, `addHitoFoto` y los datos productivos enviados por `RequestHito`.
- No se incorporaron audio, ajuste manual en mapa ni renovación de sesión del
  prototipo porque requieren servicios y contratos adicionales.

### Edición de ficha médica

- El formulario adopta encabezado compacto, tarjeta del pasajero, campos y
  controles Pilo, desplazamiento con teclado y acción principal consistente.
- Se conservaron todos los campos, validaciones, `getMedicalRecord` y
  `sendMedicalDataEdit`; además, la cobertura existente se refleja al cargar.
- Los permisos del coordinador y el modelo de actualización productivo no se
  modificaron.

### Tripulación del apoderado

- Se trasladaron el encabezado, la tarjeta oscura del bus, las tarjetas de
  integrantes y los estados Pilo ya usados en coordinador.
- Se conservan `getTripulation`, el identificador real de la gira y la foto del
  pasajero usada por el menú del apoderado.
- No se importó `TripCrewView` ni la navegación paralela del prototipo; la vista
  sigue utilizando los servicios y rutas productivos de `main`.

### Documentos del apoderado

- Se incorporaron encabezado, tarjetas, estados, actualización por gesto y
  acciones Pilo para ver y descargar archivos.
- Se conservaron `getDocument`, `viewDocument`, `downloadDocument`, la foto del
  menú y las reglas productivas que excluyen nóminas y archivos no públicos.
- No se importaron repositorios de documentos privados ni adaptadores del
  prototipo.

### Bitácora del apoderado

- El listado adopta la línea de tiempo, tarjetas, actualización y estados Pilo
  manteniendo fecha, hora, título y ubicación de cada hito.
- Se conservan `getBinnacle`, la foto del menú y la navegación al detalle real.
- El mapa embebido del prototipo no se incorporó porque requiere la capa de
  mapas y datos georreferenciados posterior.

### Detalle de bitácora del apoderado

- Se migraron encabezado, tarjeta del hito, galería adaptable, carga y errores
  al estilo Pilo.
- Se conservan `getHitoComplete`, la descarga autenticada de cada fotografía,
  la pantalla completa y la foto del menú familiar.
- La nota de audio del prototipo no se incorporó porque requiere almacenamiento
  y endpoints que aún no forman parte de `main`.

### Programa del apoderado

- Programa adopta tarjeta del pasajero, secciones Pilo de curso, fechas y
  actividades, encabezado compacto y estado recuperable de error.
- Se conservan `getviewProgram`, la gira real y el menú familiar completo con
  contacto y cierre de sesión.
- No se importaron adaptadores de laboratorio del prototipo para imágenes,
  preferencias o contacto.

### Consulta de ficha médica del apoderado

- La ficha guardada adopta tarjeta del pasajero, secciones Pilo para datos
  médicos, emergencia, cobertura y cuidados, además de recarga y edición.
- Se conservan `getMedicalRecord`, todos los campos productivos, la foto del
  menú y la navegación al formulario de edición existente.
- No se incorporó el formulario unificado en hoja del prototipo porque cambia
  el flujo completo de creación/edición y depende de componentes ausentes.

### Edición de ficha médica del apoderado

- El formulario existente adopta encabezado, tarjeta del pasajero, superficies,
  campos y acción principal Pilo, con desplazamiento adaptado al teclado.
- Se preservan todos sus controladores, validaciones, cobertura, antecedentes,
  cuidados especiales y `sendMedicalDataEdit`.
- No se reemplazó por el formulario unificado del prototipo para evitar cambiar
  el contrato y flujo productivos durante la migración visual.

### Creación inicial de ficha médica

- El formulario inicial adopta encabezado, tarjeta del pasajero, superficie y
  acción principal Pilo, manteniendo desplazamiento al primer error.
- Se conservan todos los campos, validaciones, autorización médica previa y
  `createMedicalRecord`, además de la carga de foto usada por el menú.
- No se incorporaron guardado local, exportación ni formulario en hoja del
  prototipo porque implican comportamiento nuevo.

### Dashboard del apoderado

- Inicio adopta tarjetas Pilo para pasajero y gira, accesos en cuadrícula y el
  mapa real dentro de una única superficie desplazable.
- Se eliminó la barra inferior fija sobredimensionada sin quitar accesos:
  bitácora, programa, tripulación, documentos, ficha médica y mapa continúan.
- Se conservan la actualización productiva de foto, `TraceMap`, la pantalla de
  mapa completa y el menú familiar.

### Bienvenida del apoderado

- La bienvenida adopta la composición Pilo, con marca compacta, título amplio,
  tarjeta del pasajero y acción principal adaptable.
- Se conservan la foto obtenida desde el servicio productivo (base64 o URL), la
  validación real de ficha médica y la derivación original al formulario o al
  dashboard.
- Se agregó estado de espera y recuperación ante error sin copiar el adaptador
  local de imágenes del prototipo.

### Mapas familiares

- Las vistas de recorrido y ubicación real adoptan encabezados, bordes,
  superficies, trazado y tarjetas de hito Pilo.
- Se conservan `getBinnacle`, `uniqueID`, permisos de ubicación, marcadores,
  estilos cartográficos y actualización periódica productivos.
- No se copió `LabMap`, ubicación sintética ni la nueva arquitectura de mapas
  del prototipo porque sustituyen integraciones reales y agregan funcionalidad.
