# Carga de la instantánea de datos (data/), descargada por actualizar_datos.R
# desde las salidas publicadas del pipeline. La app lee y muestra; no
# recalcula ningún índice.

# Lee el manifiesto y devuelve las plataformas de la suite como tibble.
leer_manifiesto <- function(dir = "data") {
  m <- jsonlite::read_json(file.path(dir, "manifest.json"))
  plataformas <- purrr::map(m$plataformas, function(p) {
    tibble::tibble(
      clave = p$clave, etiqueta = p$etiqueta, corta = p$corta,
      en_suite = isTRUE(p$en_suite),
      base_inicio = if (is.null(p$base_inicio)) NA_integer_ else as.integer(p$base_inicio),
      base_fin = if (is.null(p$base_fin)) NA_integer_ else as.integer(p$base_fin),
      satelite_control = if (is.null(p$satelite_control)) NA_character_ else p$satelite_control,
      registro_inicio = as.Date(p$registro_inicio),
      fin_estandar = if (is.null(p$fin_estandar)) as.Date(NA) else as.Date(p$fin_estandar),
      ultimo_dia = as.Date(p$ultimo_dia)
    )
  }) |> purrr::list_rbind()
  pares <- purrr::map(m$pares, tibble::as_tibble) |> purrr::list_rbind()
  list(contrato = m$contrato, corrida = as.Date(m$corrida), generado = m$generado,
       plataformas = plataformas, pares = pares,
       descarga = if (file.exists(file.path(dir, "descarga.txt")))
         as.Date(readLines(file.path(dir, "descarga.txt"), n = 1)) else NA)
}

# Ruta de una tabla publicada de una plataforma (o de la comparación).
ruta_tabla <- function(dir, grupo, nombre) file.path(dir, "tables", grupo, nombre)

# Tabla anual de temporada de una plataforma, con las fechas como Date y las
# marcas como lógicas; tal como la publica el pipeline.
leer_temporada_anual <- function(clave, dir = "data") {
  readr::read_csv(ruta_tabla(dir, clave, "temporada_anual.csv"),
                  show_col_types = FALSE,
                  col_types = readr::cols(ini_fecha = readr::col_date(),
                                          fin_fecha = readr::col_date(),
                                          .default = readr::col_guess())) |>
    dplyr::mutate(
      confiable = !(parcial | provisional | pocas_detecciones) & !is.na(lon),
      nota = purrr::pmap_chr(list(parcial, provisional, pocas_detecciones,
                                  no_comparable), function(pa, pr, po, nc) {
        paste(c(if (pa) "año parcial", if (pr) "provisional",
                if (po) "pocas detecciones",
                if (isTRUE(nc)) "días extremos no comparables"), collapse = "; ")
      })
    )
}

leer_tabla <- function(clave, nombre, dir = "data") {
  readr::read_csv(ruta_tabla(dir, clave, nombre), show_col_types = FALSE)
}

leer_geometria <- function(nombre, dir = "data") {
  solo_poligonos(sf::st_read(file.path(dir, "geometrias", paste0(nombre, ".geojson")), quiet = TRUE))
}

# Deja solo la parte poligonal de cada geometría, como MULTIPOLYGON. El
# recorte al país deja en algunas AC colecciones con líneas o puntos de
# borde que leaflet::addPolygons no sabe dibujar; los atributos y el orden
# no cambian.
solo_poligonos <- function(g) {
  geom <- sf::st_geometry(g)
  es_coleccion <- sf::st_is(geom, "GEOMETRYCOLLECTION")
  if (any(es_coleccion)) {
    geom[es_coleccion] <- sf::st_sfc(lapply(geom[es_coleccion], function(x) {
      sf::st_union(sf::st_sfc(poligonos_de(x)))[[1]]
    }), crs = sf::st_crs(geom))
  }
  sf::st_set_geometry(g, sf::st_cast(geom, "MULTIPOLYGON"))
}

# Lista de los POLYGON y MULTIPOLYGON de una geometría sfg, entrando en las
# colecciones anidadas (las hay en el GeoJSON de las AC).
poligonos_de <- function(x) {
  if (inherits(x, "GEOMETRYCOLLECTION")) return(unlist(lapply(x, poligonos_de), recursive = FALSE))
  if (inherits(x, c("POLYGON", "MULTIPOLYGON"))) list(x) else list()
}

# Todo lo que la app necesita al arrancar, por plataforma de la suite. Las
# tablas se leen una vez; son pequeñas (decenas de KB).
cargar_datos <- function(dir = "data") {
  m <- leer_manifiesto(dir)
  suite <- m$plataformas[m$plataformas$en_suite, ]
  por_plataforma <- purrr::map(stats::setNames(suite$clave, suite$clave), function(k) {
    list(
      temporada_anual = leer_temporada_anual(k, dir),
      temporada_celdas = leer_tabla(k, "temporada_celdas.csv", dir),
      temporada_ac_anual = leer_tabla(k, "temporada_ac_anual.csv", dir),
      temporada_ac_consolidado = leer_tabla(k, "temporada_ac_consolidado.csv", dir),
      enso_anual = leer_tabla(k, "enso_anual.csv", dir),
      enso_resumen = leer_tabla(k, "enso_resumen.csv", dir),
      fuentes_estaticas = leer_tabla(k, "fuentes_estaticas.csv", dir),
      detecciones_por_tipo = leer_tabla(k, "detecciones_por_tipo.csv", dir)
    )
  })
  list(manifiesto = m, plataformas = suite, datos = por_plataforma,
       geometrias = list(pais = leer_geometria("pais", dir),
                         grilla = leer_geometria("grilla_analisis", dir),
                         areas_conservacion = leer_geometria("areas_conservacion", dir)))
}
