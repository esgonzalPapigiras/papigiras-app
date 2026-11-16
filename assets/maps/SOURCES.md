# OpenFreeMap Positron en Papigiras LAB

Revisión: 3 de noviembre de 2026. Prueba local autorizada por Camilo; ninguna conexión a servicios productivos de Papigiras.

- Servicio y condiciones: https://openfreemap.org/ y https://openfreemap.org/tos/
- Integración/atribución: https://openfreemap.org/quick_start/
- Estilo original descargado: https://tiles.openfreemap.org/styles/positron
- Sprites: https://tiles.openfreemap.org/sprites/ofm_f384/ofm.json y ofm.png
- Licencias: archivos LICENSE-openfreemap-styles.md y LICENSE-positron-upstream.md incluidos.
- Dependencias: vector_map_tiles 8.0.0 y vector_tile_renderer 5.2.0, compatibles con flutter_map 7.0.2 existente.

Adaptaciones del estilo: fuentes locales Roboto; eliminación de URLs/glyphs/sprite del JSON; fuentes suministradas por el adaptador; retirada de la capa raster Natural Earth. No se descargan estilos, fuentes o sprites durante la ejecución.

Red de ejecución: solamente GET al endpoint /planet y a las teselas versionadas /planet/YYYYMMDD_HHMMSS_pt/z/x/y.pbf de tiles.openfreemap.org. Se valida TileJSON, rango z0–14 y coordenadas. No se siguen redirecciones ni se transmiten cookies, tokens, cuerpos de solicitud o cabeceras de sesión. La app puede ampliar por encima de14 usando el contenido vectorial disponible. Estilo/sprites se incluyen localmente.

OpenFreeMap declara servicio sin cuenta ni API key y sin SLA. Antes del release oficial acordar continuidad/caché/alternativa de hosting y conservar atribuciones y avisos de licencia. No se creó ninguna cuenta ni servicio con cargos.

Opciones contrastadas: CARTO Basemaps requiere API key según https://www.carto.com/basemaps/ ; Esri Light Gray raster heredado tiene datos sin actualizar desde2021 y retiro anunciado para diciembre2029 según https://www.esri.com/arcgis-blog/products/arcgis-living-atlas/announcements/sunsetting-legacy-basemaps . Se eligió OpenFreeMap para no depender del fondo heredado ni de credenciales nuevas.
