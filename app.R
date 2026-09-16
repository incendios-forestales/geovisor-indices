# Geovisor de los índices de la temporada de fuego de Costa Rica.
#
# Muestra, de forma interactiva, los índices y resúmenes que publica el
# pipeline anomalias-termicas-costarica (README). La app lee la instantánea
# de data/ (descargada con actualizar_datos.R) y nunca recalcula: cada cifra
# es la publicada. Un selector global elige la plataforma; las plataformas
# nunca se mezclan.

library(shiny)
library(bslib)

for (f in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(f, encoding = "UTF-8")

DATOS <- cargar_datos("data")
SITIO <- "https://incendios-forestales.github.io/anomalias-termicas-costarica/"

ui <- bslib::page_navbar(
  title = "Temporada de fuego en Costa Rica: índices",
  # Relleno vertical: el mapa ocupa toda la altura de la ventana.
  fillable = TRUE,
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly", primary = COLOR_DETECCIONES),
  sidebar = bslib::sidebar(
    width = 260, open = "always",
    shiny::selectInput("plataforma", "Plataforma",
                       choices = stats::setNames(DATOS$plataformas$clave,
                                                 DATOS$plataformas$etiqueta)),
    shiny::tags$p(class = "small text-muted",
      "Las plataformas se muestran por separado y nunca se suman: cada sensor ",
      "ve el fuego con su píxel y sus horas de paso."),
    shiny::tags$hr(),
    shiny::tags$p(class = "small text-muted",
      "Datos: corrida del ", fecha_es(DATOS$manifiesto$corrida), " del ",
      shiny::tags$a(href = SITIO, target = "_blank", "pipeline anomalias-termicas-costarica"),
      " (contrato ", DATOS$manifiesto$contrato, "). Índices de vegetación de NASA FIRMS; ",
      "definiciones en el ",
      shiny::tags$a(href = "https://github.com/incendios-forestales/anomalias-termicas-costarica#año-de-fuego-e-índices-anuales",
                    target = "_blank", "README"), "."),
    shiny::tags$p(class = "small text-muted",
      "Escuela de Geografía, Universidad de Costa Rica.")
  ),
  bslib::nav_panel("Mapa", mod_mapa_ui("mapa")),
  bslib::nav_spacer(),
  bslib::nav_item(shiny::tags$a(href = SITIO, target = "_blank", "Reportes"))
)

server <- function(input, output, session) {
  plataforma <- shiny::reactive(input$plataforma)
  mod_mapa_server("mapa", DATOS, plataforma)
}

shiny::shinyApp(ui, server)
