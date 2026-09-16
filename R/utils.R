# Utilidades de formato en español y constantes de presentación.

MESES_ES <- c("ene", "feb", "mar", "abr", "may", "jun",
              "jul", "ago", "set", "oct", "nov", "dic")
MESES_ES_LARGO <- c("enero", "febrero", "marzo", "abril", "mayo", "junio",
                    "julio", "agosto", "setiembre", "octubre", "noviembre",
                    "diciembre")

# Año de fuego: del 1 de setiembre al 31 de agosto, nombrado por el año en
# que termina (README del pipeline). El año de referencia 2002 (no bisiesto)
# convierte un «día del año de fuego» en una fecha para rotular.
INICIO_ANIO_FUEGO_REF <- as.Date("2001-09-01")

fecha_de_dia <- function(dia) INICIO_ANIO_FUEGO_REF + dia - 1L

num_es <- function(x, decimales = 1) {
  ifelse(is.na(x), "",
         format(round(x, decimales), decimal.mark = ",", big.mark = " ",
                nsmall = decimales, trim = TRUE, scientific = FALSE))
}

fecha_es <- function(x, con_anio = TRUE) {
  x <- as.Date(x)
  dia <- as.integer(format(x, "%d"))
  mes <- MESES_ES_LARGO[as.integer(format(x, "%m"))]
  if (con_anio) paste0(dia, " de ", mes, " de ", format(x, "%Y")) else
    paste0(dia, " de ", mes)
}

# Rótulo corto de una fecha del año de fuego de referencia ("22 ene").
dia_es <- function(dia) {
  f <- fecha_de_dia(dia)
  ifelse(is.na(dia), "", paste(as.integer(format(f, "%d")),
                               MESES_ES[as.integer(format(f, "%m"))]))
}

# Colores: el naranja de las detecciones del pipeline para lo confiable, gris
# para los años con reservas, y una paleta por plataforma para rótulos.
COLOR_DETECCIONES <- "#b35806"
COLOR_RESERVA <- "#9e9e9e"
COLORES_PLATAFORMA <- c(modis = "#b35806", snpp = "#2c7fb8", noaa20 = "#1a9850",
                        noaa21 = "#7b3294")

# Índices anuales que la app ofrece, con rótulo y decimales.
INDICES_ANUALES <- tibble::tribble(
  ~columna,  ~rotulo,                                         ~decimales, ~unidad,
  "dtot",    "DTOT: detecciones del año",                     0, "detecciones",
  "lon",     "LON: longitud de la temporada",                 0, "días",
  "ini_dia", "INI: inicio de la temporada (10 %)",            0, "día del año de fuego",
  "fin_dia", "FIN: fin de la temporada (90 %)",               0, "día del año de fuego",
  "df",      "DF: días con fuego",                            0, "días",
  "n50",     "N50: días que reúnen la mitad de las detecciones", 0, "días",
  "c10",     "C10: % en los 10 días más activos",             1, "%",
  "frpi",    "FRPI: FRP mediana",                             1, "MW",
  "frp95",   "FRP95: percentil 95 de la FRP",                 1, "MW",
  "noc",     "NOC: fracción nocturna",                        2, "fracción",
  "nd95",    "ND95: días extremos",                           0, "días",
  "d95ptot", "D95pTOT: % en días extremos",                   1, "%"
)
