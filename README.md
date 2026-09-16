# geovisor-indices

Geovisor interactivo (Shiny) de los **índices de la temporada de fuego de
Costa Rica** que calcula y publica el pipeline
[anomalias-termicas-costarica](https://github.com/incendios-forestales/anomalias-termicas-costarica):
longitud, inicio y fin de la temporada, concentración diaria, frecuencia y
densidad, intensidad, días extremos, su desagregación por área de
conservación, la comparación entre plataformas, la fase ENSO y las fuentes
estáticas. Es el complemento interactivo de los
[reportes publicados](https://incendios-forestales.github.io/anomalias-termicas-costarica/),
que siguen siendo la referencia.

## Principio de diseño

La app **lee lo publicado y no recalcula nada**. El pipeline expone en
`outputs/` una interfaz estable (sección «Las salidas como interfaz» de su
README): un `manifest.json` por corrida con la versión del contrato, las
plataformas, los pares y cada archivo con su SHA-256, las tablas CSV y las
geometrías en GeoJSON. La app descarga esa instantánea a `data/` con
`actualizar_datos.R`, verifica los hashes y la despliega consigo, de modo
que funciona aunque el sitio del pipeline no esté disponible y cada cifra
que muestra es exactamente la publicada. Si la app necesita un dato que no
está en `outputs/`, se agrega al pipeline; nunca se calcula aquí.

Las plataformas (MODIS, VIIRS Suomi-NPP, VIIRS NOAA-20) se muestran por
separado con un selector global y nunca se mezclan, como en el pipeline.

## Estructura

```
├── app.R                 # interfaz (bslib) y servidor: una pestaña por módulo
├── R/datos.R             # lectura del manifiesto, las tablas y las geometrías
├── R/utils.R             # formato en español, año de fuego, índices y colores
├── R/mod_mapa.R          # pestaña «Mapa»: índices por celda en leaflet
├── R/mod_temporada.R     # temporada anual (se conectará más adelante)
├── actualizar_datos.R    # descarga y verifica la instantánea de data/
├── data/                 # instantánea de outputs/ del pipeline (versionada)
├── tests/testthat/       # pruebas de la carga de datos y los formatos
├── Dockerfile            # rocker/geospatial + plotly, DT, renv, rsconnect
└── docker-compose.yml    # servicios app (puerto 3838) y dev
```

## Ejecución

Todo corre en Docker, como UID 1000:

```bash
docker compose build
docker compose run --rm dev Rscript actualizar_datos.R      # instantánea de datos
docker compose run --rm dev Rscript -e "testthat::test_dir('tests/testthat')"
docker compose up app                                         # http://localhost:3838
```

## Despliegue

En shinyapps.io, cuenta `incendios-forestales`, con rsconnect desde el
servicio `dev` (las credenciales no se versionan). Antes de desplegar,
actualizar la instantánea y correr las pruebas.

## El mapa

La portada es un mapa interactivo (leaflet) de los **índices consolidados
por celda de 0,1°** de la plataforma elegida: longitud, inicio y fin de la
temporada, fracción fuera de diciembre a mayo, concentración, frecuencia,
densidad, intensidad y, en MODIS, la fracción de Aqua. Un selector cambia
el índice; la leyenda, la barra de escala y la ficha por celda (con todos
los índices y sus marcas) acompañan. Capas base sin clave de API (CartoDB,
OpenStreetMap, imágenes de Esri) y el límite nacional como capa.

En pasos siguientes se añadirán, en el mismo mapa, la coropleta por área
de conservación, el acuerdo entre plataformas y las fuentes estáticas, y
después las vistas no cartográficas (temporada anual, ENSO). El módulo de
temporada anual ya existe en `R/mod_temporada.R` y se conectará entonces.

## Fuentes

Los datos son de NASA FIRMS (MODIS y VIIRS) procesados por el pipeline; las
definiciones de cada índice, sus umbrales y su sustento están en el README
del pipeline. Los límites de áreas de conservación son del SINAC y el
límite nacional del IGN vía SNIT.

## Licencia

Código bajo MIT; los datos, según sus fuentes.
