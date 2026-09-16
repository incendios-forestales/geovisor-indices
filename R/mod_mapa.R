# Pestaña «Mapa»: los índices consolidados por celda de 0,1° de la plataforma
# elegida, en un leaflet a pantalla completa con selector de índice, leyenda,
# barra de escala y ficha por celda. Todo sale de temporada_celdas.csv y de
# grilla_analisis.geojson; nada se recalcula.

# Índices por celda que ofrece el mapa. `base` marca los que se calculan
# sobre el periodo base (README del pipeline); `todas` los que cubren toda la
# grilla (el cero es dato); `fecha` los que se rotulan como fechas.
INDICES_CELDA <- tibble::tribble(
  ~columna,  ~rotulo,                                              ~paleta,   ~inversa, ~base, ~todas, ~fecha, ~decimales, ~unidad,
  "lon",     "LON: longitud de la temporada consolidada",          "inferno", TRUE,  FALSE, FALSE, FALSE, 0, "días",
  "ini_dia", "INI: inicio de la temporada (10 %)",                  "viridis", FALSE, FALSE, FALSE, TRUE,  0, "",
  "fin_dia", "FIN: fin de la temporada (90 %)",                     "viridis", FALSE, FALSE, FALSE, TRUE,  0, "",
  "fuera",   "FUERA: % de detecciones fuera de diciembre a mayo",   "mako",    TRUE,  FALSE, FALSE, FALSE, 0, "%",
  "n50f",    "N50F: concentración (0,5 repartido; hacia 0, en oleadas)", "mako", FALSE, FALSE, FALSE, FALSE, 2, "",
  "frec",    "FREC: fracción de años con fuego",                    "viridis", FALSE, TRUE,  TRUE,  FALSE, 2, "",
  "dens",    "DENS: detecciones por km² y año",                     "rocket",  TRUE,  TRUE,  TRUE,  FALSE, 3, "det./km²/año",
  "frpi",    "FRPI: FRP mediana",                                   "magma",   TRUE,  TRUE,  FALSE, FALSE, 1, "MW",
  "aq",      "AQ: fracción de detecciones de Aqua (tarde)",         "cividis", FALSE, TRUE,  FALSE, FALSE, 2, ""
)
LON_TOPE <- 180L                 # como RASTER_LON_TOPE del pipeline
COLOR_SIN_ESTACION <- "#6baed6"
COLOR_BAJO_UMBRAL  <- "#d9d9d9"

mod_mapa_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    fillable = TRUE,
    sidebar = bslib::sidebar(
      width = 320, open = "always",
      shiny::selectInput(ns("indice"), "Índice por celda",
                         choices = stats::setNames(INDICES_CELDA$columna, INDICES_CELDA$rotulo),
                         selected = "lon"),
      shiny::uiOutput(ns("descripcion")),
      shiny::tags$hr(),
      shiny::uiOutput(ns("ficha"))
    ),
    leaflet::leafletOutput(ns("mapa"), height = "100%")
  )
}

# Descripción corta de cada índice para el panel (README del pipeline).
DESCRIPCION_INDICE <- c(
  lon = "Días entre el inicio y el fin de la temporada climatológica de la celda: las detecciones de vegetación de todos los años completos, agrupadas, y el intervalo del 10 % al 90 % acumulado. Celdas con menos de 30 detecciones en gris; sin estación definida (más del 25 % fuera de diciembre a mayo) en azul claro.",
  ini_dia = "Primer día del año de fuego (1 = 1 de setiembre) en que la celda acumula el 10 % de sus detecciones, rotulado como fecha.",
  fin_dia = "Primer día en que la celda acumula el 90 % de sus detecciones.",
  fuera = "Porcentaje de las detecciones de la celda fuera de diciembre a mayo; por encima del 25 % la celda es bimodal o arde todo el año y queda sin INI, FIN ni LON.",
  n50f = "Proporción de los días de fuego de la celda que reúnen la mitad de sus detecciones: 0,5 si el fuego está repartido, hacia 0 si unas pocas fechas concentran casi todo. Exige 100 detecciones.",
  frec = "Fracción de los años del periodo base con al menos una detección en la celda; el cero es dato. Celdas con menos de 10 km² de tierra en gris.",
  dens = "Detecciones por km² de tierra y por año del periodo base. Propia de la plataforma: no se compara entre sensores.",
  frpi = "Mediana de la potencia radiativa (MW) de las detecciones de la celda en el periodo base; exige 30 detecciones.",
  aq = "Fracción de las detecciones del periodo base que son de Aqua, el paso de la tarde: alta donde el fuego se enciende por la mañana y MODIS lo ve crecido; cerca de la mitad donde persiste todo el día."
)

mod_mapa_server <- function(id, datos, plataforma) {
  shiny::moduleServer(id, function(input, output, session) {

    info <- shiny::reactive(datos$plataformas[datos$plataformas$clave == plataforma(), ])

    # Sin satélite de control (VIIRS) no hay AQ: se retira del selector.
    shiny::observeEvent(plataforma(), {
      indices <- INDICES_CELDA
      if (is.na(info()$satelite_control)) indices <- indices[indices$columna != "aq", ]
      sel <- if (input$indice %in% indices$columna) input$indice else "lon"
      shiny::updateSelectInput(session, "indice",
                               choices = stats::setNames(indices$columna, indices$rotulo),
                               selected = sel)
    }, ignoreInit = TRUE)

    # Celdas de la grilla con los índices de la plataforma; el orden es el de
    # la grilla, y la unión se hace sin geometría para no depender de sf.
    celdas <- shiny::reactive({
      g <- datos$geometrias$grilla
      t <- datos$datos[[plataforma()]]$temporada_celdas
      atributos <- dplyr::left_join(sf::st_drop_geometry(g)[, "celda_id", drop = FALSE], t,
                                    by = "celda_id")
      sf::st_sf(atributos, geometry = sf::st_geometry(g))
    })

    output$descripcion <- shiny::renderUI({
      f <- INDICES_CELDA[INDICES_CELDA$columna == input$indice, ]
      p <- info()
      periodo <- if (f$base) paste0("Periodo base ", p$base_inicio, "–", p$base_fin, ".") else {
        t <- datos$datos[[plataforma()]]$temporada_celdas
        paste0("Años de fuego completos ", min(t$anio_inicio, na.rm = TRUE), "–",
               max(t$anio_fin, na.rm = TRUE), ".")
      }
      shiny::tags$div(class = "small text-muted",
        shiny::tags$p(DESCRIPCION_INDICE[[input$indice]]),
        shiny::tags$p(periodo, " Detecciones de vegetación de ", p$etiqueta, "."))
    })

    output$mapa <- leaflet::renderLeaflet({
      pais <- datos$geometrias$pais
      leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 7, maxZoom = 12)) |>
        # Capas base sin clave de API: CARTO la exige desde 2026 (sus teselas
        # devuelven «API key required»), así que no se usa.
        leaflet::addProviderTiles(leaflet::providers$Esri.WorldGrayCanvas, group = "Gris (Esri)") |>
        leaflet::addProviderTiles(leaflet::providers$OpenStreetMap, group = "OpenStreetMap") |>
        leaflet::addProviderTiles(leaflet::providers$OpenTopoMap, group = "Relieve (OpenTopoMap)") |>
        leaflet::addProviderTiles(leaflet::providers$Esri.WorldImagery, group = "Imágenes (Esri)") |>
        leaflet::addPolygons(data = pais, fill = FALSE, color = "#333333", weight = 1.2,
                             group = "Límite nacional") |>
        leaflet::addLayersControl(
          baseGroups = c("Gris (Esri)", "OpenStreetMap", "Relieve (OpenTopoMap)", "Imágenes (Esri)"),
          overlayGroups = c("Celdas", "Límite nacional"),
          options = leaflet::layersControlOptions(collapsed = TRUE)) |>
        leaflet::addScaleBar(position = "bottomleft",
                             options = leaflet::scaleBarOptions(imperial = FALSE)) |>
        leaflet::fitBounds(-86.0, 8.0, -82.5, 11.3)
    })

    # Capa de celdas y leyenda: se redibujan al cambiar de índice o plataforma.
    shiny::observe({
      v <- input$indice
      shiny::req(v %in% INDICES_CELDA$columna)
      f <- INDICES_CELDA[INDICES_CELDA$columna == v, ]
      c <- celdas()
      # Las celdas que se dibujan: todas (el cero es dato) o solo con fuego.
      if (!f$todas) c <- c[!is.na(c$dtot) & c$dtot > 0, ]
      valores <- c[[v]]
      if (v == "lon") valores <- pmin(valores, LON_TOPE)
      dominio <- range(valores, na.rm = TRUE)
      if (v == "lon") dominio <- c(0, LON_TOPE)
      if (v %in% c("frec", "n50f", "aq")) dominio <- c(0, if (v == "n50f") 0.5 else 1)
      colores <- viridisLite::viridis(64, option = f$paleta)
      if (f$inversa) colores <- rev(colores)
      paleta <- leaflet::colorNumeric(colores, domain = dominio, na.color = COLOR_BAJO_UMBRAL)
      color_relleno <- paleta(valores)
      sin_estacion <- !is.na(c$sin_estacion) & c$sin_estacion & !f$todas & !f$base
      color_relleno[sin_estacion & is.na(valores)] <- COLOR_SIN_ESTACION
      etiquetas_leyenda <- if (f$fecha) {
        function(type, cuts, p) dia_es(round(cuts))
      } else if (v == "lon") {
        function(type, cuts, p) ifelse(cuts >= LON_TOPE, paste0("≥ ", cuts), as.character(round(cuts)))
      } else {
        function(type, cuts, p) num_es(cuts, f$decimales)
      }
      leaflet::leafletProxy("mapa", session) |>
        leaflet::clearGroup("Celdas") |>
        leaflet::removeControl("leyenda") |>
        leaflet::addPolygons(
          data = c, group = "Celdas", layerId = ~celda_id,
          fillColor = color_relleno, fillOpacity = 0.75, color = "white", weight = 0.6,
          highlightOptions = leaflet::highlightOptions(weight = 2, color = "#333333",
                                                       bringToFront = TRUE),
          label = ~celda_id) |>
        leaflet::addLegend(
          layerId = "leyenda", position = "bottomright", pal = paleta,
          values = valores[!is.na(valores)], title = sub(":.*$", "", f$rotulo),
          labFormat = etiquetas_leyenda, opacity = 0.85, na.label = "sin índice")
    })

    # Ficha de la celda pulsada, en el panel lateral.
    celda_activa <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$mapa_shape_click, {
      celda_activa(input$mapa_shape_click$id)
    })
    shiny::observeEvent(plataforma(), celda_activa(NULL))

    output$ficha <- shiny::renderUI({
      id <- celda_activa()
      if (is.null(id)) {
        return(shiny::tags$p(class = "small text-muted",
                             "Pulse una celda para ver todos sus índices."))
      }
      c <- sf::st_drop_geometry(celdas())
      r <- c[c$celda_id == id, ]
      if (nrow(r) == 0) return(NULL)
      p <- info()
      fila <- function(nombre, valor) shiny::tags$tr(shiny::tags$td(nombre), shiny::tags$td(valor))
      fecha <- function(d) if (is.na(d)) "—" else dia_es(d)
      num <- function(x, d) if (is.na(x)) "—" else num_es(x, d)
      estado <- if (isTRUE(r$sin_estacion)) "Sin estación definida (bimodal o fuego todo el año): sin INI, FIN ni LON" else
        if (!isTRUE(r$valida)) "Bajo el umbral de 30 detecciones: sin índices de temporada" else ""
      shiny::tags$div(class = "small",
        shiny::tags$p(shiny::tags$strong(paste0("Celda ", id)), shiny::tags$br(),
                      paste0(num(r$area_km2, 0), " km² de tierra")),
        if (estado != "") shiny::tags$p(class = "text-muted fst-italic", estado),
        shiny::tags$table(class = "table table-sm mb-2",
          fila(paste0("Detecciones ", r$anio_inicio, "–", r$anio_fin), num(r$dtot, 0)),
          fila("Inicio (10 %)", fecha(r$ini_dia)),
          fila("Fin (90 %)", fecha(r$fin_dia)),
          fila("Longitud (días)", num(r$lon, 0)),
          fila("Fuera de dic–may (%)", num(r$fuera, 0)),
          fila("N50F", num(r$n50f, 2)),
          fila(paste0("FREC (", r$base_inicio, "–", r$base_fin, ")"), num(r$frec, 2)),
          fila("DENS (det./km²/año)", num(r$dens, 3)),
          fila("FRPI (MW)", num(r$frpi, 1)),
          if (!is.na(p$satelite_control)) fila("AQ (fracción de Aqua)", num(r$aq, 2))
        ),
        shiny::actionLink(session$ns("cerrar"), "Cerrar ficha")
      )
    })
    shiny::observeEvent(input$cerrar, celda_activa(NULL))
  })
}
