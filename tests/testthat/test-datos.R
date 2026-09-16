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
})

test_that("los formatos en español funcionan", {
  expect_equal(num_es(1234.567, 1), "1 234,6")
  expect_equal(num_es(NA, 1), "")
  expect_equal(fecha_es(as.Date("2026-05-28")), "28 de mayo de 2026")
  expect_equal(dia_es(123L), "1 ene")
  expect_equal(dia_es(1L), "1 set")
})
