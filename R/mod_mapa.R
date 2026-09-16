# Pestaña «Mapa»: los índices consolidados de la plataforma elegida, en un
# leaflet a pantalla completa, a dos escalas que comparten selector de
# índice, leyenda, barra de escala y ficha por unidad: las celdas de 0,1°
# (temporada_celdas.csv + grilla_analisis.geojson) y las áreas de
# conservación (temporada_ac_consolidado.csv + areas_conservacion.geojson).
# El pipeline calcula el consolidado por AC con las mismas funciones y
# umbrales que las celdas (README, «Desagregación por área de
# conservación»); aquí nada se recalcula.

# Escalas del mapa: geometría y tabla publicadas, columna llave (también el
# layerId de los polígonos) y columna con el nombre que se muestra al pasar
# el cursor.
ESCALAS <- tibble::tribble(
  ~clave,   ~rotulo,                 ~geometria,           ~tabla,                     ~llave,      ~nombre,
  "celdas", "Celdas de 0,1°",        "grilla",             "temporada_celdas",         "celda_id",  "celda_id",
  "ac",     "Áreas de conservación", "areas_conservacion", "temporada_ac_consolidado", "siglas_ac", "nombre_ac"
)

# Índices que ofrece el mapa. `base` marca los que se calculan sobre el
# periodo base (README del pipeline); `todas` los que cubren todas las
# unidades (el cero es dato); `fecha` los que se rotulan como fechas; `ac`
# los que existen a la escala de AC (no hay FREC por AC: todas arden todos
# los años).
INDICES_MAPA <- tibble::tribble(
  ~columna,  ~rotulo,                                              ~paleta,   ~inversa, ~base, ~todas, ~fecha, ~ac,   ~decimales, ~unidad,
  "lon",     "LON: longitud de la temporada consolidada",          "inferno", TRUE,  FALSE, FALSE, FALSE, TRUE,  0, "días",
  "ini_dia", "INI: inicio de la temporada (10 %)",                  "viridis", FALSE, FALSE, FALSE, TRUE,  TRUE,  0, "",
  "fin_dia", "FIN: fin de la temporada (90 %)",                     "viridis", FALSE, FALSE, FALSE, TRUE,  TRUE,  0, "",
  "fuera",   "FUERA: % de detecciones fuera de diciembre a mayo",   "mako",    TRUE,  FALSE, FALSE, FALSE, TRUE,  0, "%",
  "n50f",    "N50F: concentración (0,5 repartido; hacia 0, en oleadas)", "mako", FALSE, FALSE, FALSE, FALSE, TRUE, 2, "",
  "frec",    "FREC: fracción de años con fuego",                    "viridis", FALSE, TRUE,  TRUE,  FALSE, FALSE, 2, "",
  "dens",    "DENS: detecciones por km² y año",                     "rocket",  TRUE,  TRUE,  TRUE,  FALSE, TRUE,  3, "det./km²/año",
  "frpi",    "FRPI: FRP mediana",                                   "magma",   TRUE,  TRUE,  FALSE, FALSE, TRUE,  1, "MW",
  "aq",      "AQ: fracción de detecciones de Aqua (tarde)",         "cividis", FALSE, TRUE,  FALSE, FALSE, TRUE,  2, ""
)
LON_TOPE <- 180L                 # como RASTER_LON_TOPE del pipeline
COLOR_SIN_ESTACION <- "#6baed6"
COLOR_BAJO_UMBRAL  <- "#d9d9d9"
GRUPOS_BASE <- c("Gris (Esri)", "OpenStreetMap", "Relieve (OpenTopoMap)", "Imágenes (Esri)")

# El módulo tiene dos piezas de interfaz: los controles, que van en el panel
# lateral de la app bajo el selector de plataforma, y el mapa, que ocupa
# todo el resto de la ventana. Comparten el mismo `id`.
mod_mapa_panel_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(ns("escala"), "Escala",
                       choices = stats::setNames(ESCALAS$clave, ESCALAS$rotulo),
                       selected = "celdas"),
    shiny::selectInput(ns("indice"), "Índice",
                       choices = stats::setNames(INDICES_MAPA$columna, INDICES_MAPA$rotulo),
                       selected = "lon"),
    shiny::uiOutput(ns("descripcion")),
    shiny::tags$hr(),
    shiny::uiOutput(ns("ficha"))
  )
}

mod_mapa_ui <- function(id) {
  ns <- shiny::NS(id)
  leaflet::leafletOutput(ns("mapa"), height = "100%")
}

# Descripción corta de cada índice para el panel (README del pipeline), por
# escala: las definiciones y los umbrales son los mismos, cambia la unidad.
DESCRIPCION_INDICE <- list(
  celdas = c(
    lon = "Días entre el inicio y el fin de la temporada climatológica de la celda: las detecciones de vegetación de todos los años completos, agrupadas, y el intervalo del 10 % al 90 % acumulado. Celdas con menos de 30 detecciones en gris; sin estación definida (más del 25 % fuera de diciembre a mayo) en azul claro.",
    ini_dia = "Primer día del año de fuego (1 = 1 de setiembre) en que la celda acumula el 10 % de sus detecciones, rotulado como fecha.",
    fin_dia = "Primer día en que la celda acumula el 90 % de sus detecciones.",
    fuera = "Porcentaje de las detecciones de la celda fuera de diciembre a mayo; por encima del 25 % la celda es bimodal o arde todo el año y queda sin INI, FIN ni LON.",
    n50f = "Proporción de los días de fuego de la celda que reúnen la mitad de sus detecciones: 0,5 si el fuego está repartido, hacia 0 si unas pocas fechas concentran casi todo. Exige 100 detecciones.",
    frec = "Fracción de los años del periodo base con al menos una detección en la celda; el cero es dato. Celdas con menos de 10 km² de tierra en gris.",
    dens = "Detecciones por km² de tierra y por año del periodo base. Propia de la plataforma: no se compara entre sensores.",
    frpi = "Mediana de la potencia radiativa (MW) de las detecciones de la celda en el periodo base; exige 30 detecciones.",
    aq = "Fracción de las detecciones del periodo base que son de Aqua, el paso de la tarde: alta donde el fuego se enciende por la mañana y MODIS lo ve crecido; cerca de la mitad donde persiste todo el día."
  ),
  ac = c(
    lon = "Días entre el inicio y el fin de la temporada climatológica del área de conservación (AC): las detecciones de vegetación de todos los años completos, agrupadas, y el intervalo del 10 % al 90 % acumulado. Sin estación definida (más del 25 % fuera de diciembre a mayo) en azul claro.",
    ini_dia = "Primer día del año de fuego (1 = 1 de setiembre) en que el AC acumula el 10 % de sus detecciones, rotulado como fecha.",
    fin_dia = "Primer día en que el AC acumula el 90 % de sus detecciones.",
    fuera = "Porcentaje de las detecciones del AC fuera de diciembre a mayo; por encima del 25 % el AC es bimodal o arde todo el año y queda sin INI, FIN ni LON.",
    n50f = "Proporción de los días de fuego del AC que reúnen la mitad de sus detecciones: 0,5 si el fuego está repartido, hacia 0 si unas pocas fechas concentran casi todo. Exige 100 detecciones.",
    dens = "Detecciones por km² de tierra del AC y por año del periodo base. Propia de la plataforma: no se compara entre sensores.",
    frpi = "Mediana de la potencia radiativa (MW) de las detecciones del AC en el periodo base; exige 30 detecciones.",
    aq = "Fracción de las detecciones del AC en el periodo base que son de Aqua, el paso de la tarde: alta donde el fuego se enciende por la mañana y MODIS lo ve crecido; cerca de la mitad donde persiste todo el día."
  )
)
NOTA_ESCALA_AC <- "Cada AC se consolida como una celda con su superficie terrestre, con las mismas definiciones y umbrales; no hay FREC por AC porque todas arden todos los años. Los índices se comparan entre AC de la misma plataforma."

mod_mapa_server <- function(id, datos, plataforma) {
  shiny::moduleServer(id, function(input, output, session) {

    info <- shiny::reactive(datos$plataformas[datos$plataformas$clave == plataforma(), ])
    escala <- shiny::reactive({
      shiny::req(input$escala %in% ESCALAS$clave)
      ESCALAS[ESCALAS$clave == input$escala, ]
    })

    # Índices disponibles: sin FREC a la escala de AC y sin AQ en las
    # plataformas sin satélite de control (VIIRS).
    shiny::observeEvent(list(plataforma(), input$escala), {
      indices <- INDICES_MAPA
      if (identical(input$escala, "ac")) indices <- indices[indices$ac, ]
      if (is.na(info()$satelite_control)) indices <- indices[indices$columna != "aq", ]
      sel <- if (isTRUE(input$indice %in% indices$columna)) input$indice else "lon"
      shiny::updateSelectInput(session, "indice",
                               choices = stats::setNames(indices$columna, indices$rotulo),
                               selected = sel)
    }, ignoreInit = TRUE)

    # Unidades de la escala (celdas o AC) con los índices de la plataforma;
    # el orden es el de la geometría, y la unión se hace sin geometría para
    # no depender de sf. Solo entra la llave de la geometría: la tabla ya
    # trae nombre y superficie.
    unidades <- shiny::reactive({
      e <- escala()
      g <- datos$geometrias[[e$geometria]]
      t <- datos$datos[[plataforma()]][[e$tabla]]
      llaves <- sf::st_drop_geometry(g)[, e$llave, drop = FALSE]
      atributos <- dplyr::left_join(llaves, t, by = e$llave)
      sf::st_sf(atributos, geometry = sf::st_geometry(g))
    })

    output$descripcion <- shiny::renderUI({
      e <- escala()
      shiny::req(input$indice %in% names(DESCRIPCION_INDICE[[e$clave]]))
      f <- INDICES_MAPA[INDICES_MAPA$columna == input$indice, ]
      p <- info()
      periodo <- if (f$base) paste0("Periodo base ", p$base_inicio, "–", p$base_fin, ".") else {
        t <- datos$datos[[plataforma()]][[e$tabla]]
        paste0("Años de fuego completos ", min(t$anio_inicio, na.rm = TRUE), "–",
               max(t$anio_fin, na.rm = TRUE), ".")
      }
      shiny::tags$div(class = "small text-muted",
        shiny::tags$p(DESCRIPCION_INDICE[[e$clave]][[input$indice]]),
        if (e$clave == "ac") shiny::tags$p(NOTA_ESCALA_AC),
        shiny::tags$p(periodo, " Detecciones de vegetación de ", p$etiqueta, "."))
    })

    output$mapa <- leaflet::renderLeaflet({
      pais <- datos$geometrias$pais
      leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 7, maxZoom = 12)) |>
        # Capas base sin clave de API: CARTO la exige desde 2026 (sus teselas
        # devuelven «API key required»), así que no se usa.
        leaflet::addProviderTiles(leaflet::providers$Esri.WorldGrayCanvas, group = GRUPOS_BASE[1]) |>
        leaflet::addProviderTiles(leaflet::providers$OpenStreetMap, group = GRUPOS_BASE[2]) |>
        leaflet::addProviderTiles(leaflet::providers$OpenTopoMap, group = GRUPOS_BASE[3]) |>
        leaflet::addProviderTiles(leaflet::providers$Esri.WorldImagery, group = GRUPOS_BASE[4]) |>
        leaflet::addPolygons(data = pais, fill = FALSE, color = "#333333", weight = 1.2,
                             group = "Límite nacional") |>
        leaflet::addLayersControl(
          baseGroups = GRUPOS_BASE,
          overlayGroups = c(ESCALAS$rotulo[1], "Límite nacional"),
          options = leaflet::layersControlOptions(collapsed = TRUE)) |>
        leaflet::addScaleBar(position = "bottomleft",
                             options = leaflet::scaleBarOptions(imperial = FALSE)) |>
        leaflet::fitBounds(-86.0, 8.0, -82.5, 11.3)
    })

    # Capa de unidades, leyenda y control de capas: se redibujan al cambiar
    # de índice, escala o plataforma. Mientras el selector de índice se
    # actualiza tras un cambio de escala puede traer un índice que no existe
    # en ella (FREC en AC): se espera al siguiente valor.
    shiny::observe({
      v <- input$indice
      e <- escala()
      shiny::req(v %in% INDICES_MAPA$columna)
      f <- INDICES_MAPA[INDICES_MAPA$columna == v, ]
      shiny::req(e$clave == "celdas" || f$ac)
      u <- unidades()
      shiny::req(v %in% names(u))
      # Las unidades que se dibujan: todas (el cero es dato) o solo con fuego.
      if (!f$todas) u <- u[!is.na(u$dtot) & u$dtot > 0, ]
      valores <- u[[v]]
      if (v == "lon") valores <- pmin(valores, LON_TOPE)
      dominio <- range(valores, na.rm = TRUE)
      if (v == "lon") dominio <- c(0, LON_TOPE)
      if (v %in% c("frec", "n50f", "aq")) dominio <- c(0, if (v == "n50f") 0.5 else 1)
      colores <- viridisLite::viridis(64, option = f$paleta)
      if (f$inversa) colores <- rev(colores)
      paleta <- leaflet::colorNumeric(colores, domain = dominio, na.color = COLOR_BAJO_UMBRAL)
      color_relleno <- paleta(valores)
      sin_estacion <- !is.na(u$sin_estacion) & u$sin_estacion & !f$todas & !f$base
      color_relleno[sin_estacion & is.na(valores)] <- COLOR_SIN_ESTACION
      etiquetas_leyenda <- if (f$fecha) {
        function(type, cuts, p) dia_es(round(cuts))
      } else if (v == "lon") {
        function(type, cuts, p) ifelse(cuts >= LON_TOPE, paste0("≥ ", cuts), as.character(round(cuts)))
      } else {
        function(type, cuts, p) num_es(cuts, f$decimales)
      }
      es_ac <- e$clave == "ac"
      etiquetas <- if (es_ac) paste0(u$nombre_ac, " (", u$siglas_ac, ")") else u[[e$nombre]]
      proxy <- leaflet::leafletProxy("mapa", session)
      for (g in ESCALAS$rotulo) proxy <- leaflet::clearGroup(proxy, g)
      proxy |>
        leaflet::removeControl("leyenda") |>
        leaflet::addPolygons(
          data = u, group = e$rotulo, layerId = u[[e$llave]],
          fillColor = color_relleno, fillOpacity = 0.75, color = "white",
          weight = if (es_ac) 1.5 else 0.6,
          highlightOptions = leaflet::highlightOptions(weight = 2.5, color = "#333333",
                                                       bringToFront = TRUE),
          label = etiquetas) |>
        leaflet::addLayersControl(
          baseGroups = GRUPOS_BASE,
          overlayGroups = c(e$rotulo, "Límite nacional"),
          options = leaflet::layersControlOptions(collapsed = TRUE)) |>
        leaflet::addLegend(
          layerId = "leyenda", position = "bottomright", pal = paleta,
          values = valores[!is.na(valores)], title = sub(":.*$", "", f$rotulo),
          labFormat = etiquetas_leyenda, opacity = 0.85, na.label = "sin índice")
    })

    # Ficha de la unidad pulsada (celda o AC), en el panel lateral.
    unidad_activa <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$mapa_shape_click, {
      unidad_activa(input$mapa_shape_click$id)
    })
    shiny::observeEvent(list(plataforma(), input$escala), unidad_activa(NULL))

    output$ficha <- shiny::renderUI({
      id <- unidad_activa()
      e <- escala()
      es_ac <- e$clave == "ac"
      if (is.null(id)) {
        return(shiny::tags$p(class = "small text-muted",
                             if (es_ac) "Pulse un área de conservación para ver todos sus índices."
                             else "Pulse una celda para ver todos sus índices."))
      }
      u <- sf::st_drop_geometry(unidades())
      r <- u[u[[e$llave]] == id, ]
      if (nrow(r) == 0) return(NULL)
      p <- info()
      fila <- function(nombre, valor) shiny::tags$tr(shiny::tags$td(nombre), shiny::tags$td(valor))
      fecha <- function(d) if (is.na(d)) "—" else dia_es(d)
      num <- function(x, d) if (is.na(x)) "—" else num_es(x, d)
      titulo <- if (es_ac) paste0(r$nombre_ac, " (", id, ")") else paste0("Celda ", id)
      estado <- if (isTRUE(r$sin_estacion)) "Sin estación definida (bimodal o fuego todo el año): sin INI, FIN ni LON" else
        if (!isTRUE(r$valida)) "Bajo el umbral de 30 detecciones: sin índices de temporada" else ""
      shiny::tags$div(class = "small",
        shiny::tags$p(shiny::tags$strong(titulo), shiny::tags$br(),
                      paste0(num(r$area_km2, 0), " km² de tierra")),
        if (estado != "") shiny::tags$p(class = "text-muted fst-italic", estado),
        shiny::tags$table(class = "table table-sm mb-2",
          fila(paste0("Detecciones ", r$anio_inicio, "–", r$anio_fin), num(r$dtot, 0)),
          fila("Inicio (10 %)", fecha(r$ini_dia)),
          fila("Fin (90 %)", fecha(r$fin_dia)),
          fila("Longitud (días)", num(r$lon, 0)),
          fila("Fuera de dic–may (%)", num(r$fuera, 0)),
          fila("N50F", num(r$n50f, 2)),
          if (!es_ac) fila(paste0("FREC (", r$base_inicio, "–", r$base_fin, ")"), num(r$frec, 2)),
          fila(paste0("DENS (det./km²/año, ", r$base_inicio, "–", r$base_fin, ")"), num(r$dens, 3)),
          fila("FRPI (MW)", num(r$frpi, 1)),
          if (!is.na(p$satelite_control)) fila("AQ (fracción de Aqua)", num(r$aq, 2))
        ),
        shiny::actionLink(session$ns("cerrar"), "Cerrar ficha")
      )
    })
    shiny::observeEvent(input$cerrar, unidad_activa(NULL))
  })
}
