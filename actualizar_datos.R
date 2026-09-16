# Descarga a data/ la instantánea de las salidas publicadas por el pipeline
# anomalias-termicas-costarica que la app necesita: el manifiesto, las tablas
# CSV y las geometrías GeoJSON (no las figuras ni los rásteres). Verifica el
# SHA-256 de cada archivo contra el manifiesto. Ejecutar antes de desplegar:
#
#   docker compose run --rm dev Rscript actualizar_datos.R
#
# La app nunca recalcula: muestra exactamente lo publicado (README).

BASE <- "https://incendios-forestales.github.io/anomalias-termicas-costarica/"
TIPOS <- c("tables", "geometrias")

descargar <- function(ruta, dest) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  # Codificación de la ruta por segmentos: los nombres publicados pueden
  # llevar caracteres fuera de ASCII.
  url <- paste0(BASE, paste(utils::URLencode(strsplit(ruta, "/")[[1]], reserved = TRUE),
                            collapse = "/"))
  tryCatch(
    httr2::request(url) |> httr2::req_retry(max_tries = 3) |> httr2::req_perform(path = dest),
    error = function(e) stop("No se pudo descargar ", url, ": ", conditionMessage(e), call. = FALSE)
  )
  dest
}

sha256_hex <- function(ruta) {
  con <- file(ruta, "rb"); on.exit(close(con))
  paste(sprintf("%02x", as.integer(unclass(openssl::sha256(con)))), collapse = "")
}

manifiesto_dest <- "data/manifest.json"
descargar("outputs/manifest.json", manifiesto_dest)
m <- jsonlite::read_json(manifiesto_dest)
cat("Manifiesto: contrato", m$contrato, "| corrida", m$corrida, "|",
    length(m$archivos), "archivos publicados\n")

# Solo los datos: tablas CSV y geometrías GeoJSON. Las carpetas *_files de
# los widgets HTML del pipeline no forman parte del contrato.
archivos <- Filter(function(a) a$tipo %in% TIPOS && grepl("\\.(csv|geojson)$", a$ruta),
                   m$archivos)
malos <- character()
for (a in archivos) {
  dest <- file.path("data", sub("^outputs/", "", a$ruta))
  descargar(a$ruta, dest)
  if (!identical(sha256_hex(dest), a$sha256)) malos <- c(malos, a$ruta)
}
cat("Descargados", length(archivos), "archivos en data/\n")
if (length(malos)) {
  stop("SHA-256 distinto del manifiesto en: ", paste(malos, collapse = ", "))
}
writeLines(as.character(Sys.Date()), "data/descarga.txt")
cat("Instantánea verificada el", as.character(Sys.Date()), "\n")
