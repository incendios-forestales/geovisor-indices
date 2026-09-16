# geovisor-indices

App Shiny (bslib + módulos) que muestra los índices de la temporada de
fuego publicados por el pipeline `../anomalias-termicas-costarica`. Leer su
README y el de este repositorio antes de tocar el diseño.

## Principio

La app **lee lo publicado y no recalcula nada**: `outputs/manifest.json`,
las tablas CSV y las geometrías GeoJSON del pipeline (su README, «Las
salidas como interfaz»). Si hace falta un dato que no está en `outputs/`,
se agrega al pipeline (README primero); nunca se calcula aquí. Las
plataformas nunca se mezclan.

## Ejecución

No hay R en la máquina: todo corre en Docker como UID 1000.

```bash
docker compose build
docker compose run --rm dev Rscript actualizar_datos.R      # instantánea data/ (versionada)
docker compose run --rm dev Rscript -e "testthat::test_dir('tests/testthat')"
docker compose up app        # http://127.0.0.1:3838 (no localhost: Chrome guarda un zoom raro)
docker compose down
```

Tras cambiar código: `docker compose restart app`.

## Decisiones

- Portada = un solo mapa leaflet a pantalla completa (mapas primero; Escuela
  de Geografía de la UCR). Un solo panel lateral: plataforma, controles del
  módulo (`mod_mapa_panel_ui`) y créditos. `page_navbar(fillable = TRUE)`.
- Capas base sin clave de API: Esri gris, OSM, OpenTopoMap, Esri imágenes.
  CARTO exige clave desde 2026 (teselas «API key required»).
- `R/mod_temporada.R` existe pero no está conectado; se conectará como
  vista no cartográfica más adelante.
- El mapa tiene dos escalas (`ESCALAS` en R/mod_mapa.R): celdas de 0,1° y
  áreas de conservación, con el mismo selector de índice, leyenda y ficha;
  la llave de cada escala es el `layerId` de los polígonos. Los índices
  disponibles se filtran por escala (sin FREC en AC) y por plataforma (sin
  AQ en VIIRS); el observador que dibuja espera con `req()` mientras el
  selector se actualiza.
- Orden previsto en el mismo mapa: acuerdo entre plataformas → fuentes
  estáticas; luego vistas anuales y ENSO; al final renv.lock y despliegue a
  shinyapps.io (cuenta incendios-forestales).
- Para verificar en Chrome, `javascript_tool` (dispatchEvent click,
  `$('#mapa-indice')[0].selectize.setValue(...)`) es más fiable que las
  capturas, que a veces se congelan tras un clic en el mapa.
