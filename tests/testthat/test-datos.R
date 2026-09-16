# Pruebas de la carga de datos sobre la instantánea versionada en data/ y de
# los formatos en español.

RAIZ <- normalizePath(testthat::test_path("..", ".."))
for (f in list.files(file.path(RAIZ, "R"), pattern = "[.]R$", full.names = TRUE)) {
  source(f, encoding = "UTF-8")
}
DIR <- file.path(RAIZ, "data")

test_that("el manifiesto trae las plataformas de la suite y los pares", {
  m <- leer_manifiesto(DIR)
  expect_true(m$contrato >= 1)
  expect_s3_class(m$corrida, "Date")
  expect_equal(m$plataformas$clave[m$plataformas$en_suite], c("modis", "snpp", "noaa20"))
  expect_equal(m$plataformas$satelite_control[m$plataformas$clave == "modis"], "Aqua")
  expect_true(is.na(m$plataformas$satelite_control[m$plataformas$clave == "snpp"]))
  expect_equal(nrow(m$pares), 3L)
})

test_that("la tabla anual se lee con fechas y marcas", {
  t <- leer_temporada_anual("modis", DIR)
  expect_s3_class(t$ini_fecha, "Date")
  expect_true(all(c("confiable", "nota", "lon", "dtot", "nd95") %in% names(t)))
  expect_true(any(t$confiable))
  expect_true(t$nota[t$anio_fuego == 2001] != "")      # año parcial
  # Los años completos tienen las fechas dentro del año de fuego.
  ok <- t[t$confiable, ]
  expect_true(all(ok$ini_dia >= 1 & ok$fin_dia <= 366 & ok$lon == ok$fin_dia - ok$ini_dia + 1))
})

test_that("cargar_datos reúne todas las tablas por plataforma", {
  d <- cargar_datos(DIR)
  expect_equal(names(d$datos), c("modis", "snpp", "noaa20"))
  expect_true(all(c("temporada_anual", "temporada_celdas", "temporada_ac_anual",
                    "enso_anual", "fuentes_estaticas") %in% names(d$datos$snpp)))
  expect_s3_class(d$geometrias$pais, "sf")
  # La grilla y la tabla por celda comparten la llave.
  g <- d$geometrias$grilla
  expect_equal(nrow(g), 523L)
  expect_true(all(d$datos$modis$temporada_celdas$celda_id %in% g$celda_id))
  expect_equal(nrow(d$geometrias$areas_conservacion), 10L)
})

test_that("los índices del mapa existen en las tablas de cada escala", {
  source(file.path(RAIZ, "R", "mod_mapa.R"))
  t <- leer_tabla("modis", "temporada_celdas.csv", DIR)
  expect_true(all(INDICES_MAPA$columna %in% names(t)))
  expect_true(all(c("valida", "sin_estacion", "anio_inicio", "base_inicio") %in% names(t)))
  # Escala de AC: los índices marcados `ac` (todos menos FREC), la llave y
  # el nombre están en el consolidado, para las tres plataformas.
  for (k in c("modis", "snpp", "noaa20")) {
    a <- leer_tabla(k, "temporada_ac_consolidado.csv", DIR)
    expect_true(all(INDICES_MAPA$columna[INDICES_MAPA$ac] %in% names(a)), info = k)
    expect_false("frec" %in% names(a), info = k)
    expect_true(all(c("siglas_ac", "nombre_ac", "area_km2", "valida", "sin_estacion") %in% names(a)))
    expect_equal(nrow(a), 10L, info = k)
  }
  expect_false(INDICES_MAPA$ac[INDICES_MAPA$columna == "frec"])
  expect_true(all(setdiff(INDICES_MAPA$columna, "frec") %in% names(DESCRIPCION_INDICE$ac)))
  expect_true(all(INDICES_MAPA$columna %in% names(DESCRIPCION_INDICE$celdas)))
})

test_that("la geometría de las AC y el consolidado comparten la llave", {
  d <- cargar_datos(DIR)
  g <- d$geometrias$areas_conservacion
  a <- d$datos$modis$temporada_ac_consolidado
  expect_setequal(g$siglas_ac, a$siglas_ac)
  # Solo polígonos: leaflet no dibuja colecciones (el GeoJSON publicado
  # trae alguna por el recorte al país).
  expect_true(all(sf::st_is(g, "MULTIPOLYGON")))
  expect_true(all(sf::st_is(d$geometrias$grilla, "MULTIPOLYGON")))
  # El nombre y la superficie de la geometría coinciden con los de la tabla.
  u <- dplyr::left_join(sf::st_drop_geometry(g), a, by = "siglas_ac")
  expect_equal(u$nombre_ac.x, u$nombre_ac.y)
  expect_equal(u$area_km2.x, u$area_km2.y)
})

test_that("los formatos en español funcionan", {
  expect_equal(num_es(1234.567, 1), "1 234,6")
  expect_equal(num_es(NA, 1), "")
  expect_equal(fecha_es(as.Date("2026-05-28")), "28 de mayo de 2026")
  expect_equal(dia_es(123L), "1 ene")
  expect_equal(dia_es(1L), "1 set")
})
