# Pestaña «Temporada anual»: los índices por año de fuego de la plataforma
# elegida. Segmentos INI–FIN por año, un índice a elegir en barras, la tabla
# completa y su descarga. Solo muestra lo publicado por el pipeline.

mod_temporada_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      width = 300,
      shiny::selectInput(ns("indice"), "Índice para el gráfico de barras",
                         choices = stats::setNames(INDICES_ANUALES$columna,
                                                   INDICES_ANUALES$rotulo),
                         selected = "lon"),
      shiny::checkboxInput(ns("solo_confiables"),
                           "Solo años completos y no provisionales", value = FALSE),
      shiny::uiOutput(ns("resumen")),
      shiny::downloadButton(ns("descargar"), "Descargar CSV", class = "btn-sm")
    ),
    bslib::card(
      bslib::card_header("Inicio, fin y longitud de la temporada por año de fuego"),
      plotly::plotlyOutput(ns("segmentos"), height = "520px"),
      bslib::card_footer(class = "text-muted small",
        "Del 10 % al 90 % de las detecciones de vegetación acumuladas en cada ",
        "año de fuego (setiembre–agosto, nombrado por el año en que termina). ",
        "En gris, años parciales, provisionales o con pocas detecciones.")
    ),
    bslib::card(
      bslib::card_header(shiny::textOutput(ns("titulo_barras"), inline = TRUE)),
      plotly::plotlyOutput(ns("barras"), height = "320px")
    ),
    bslib::card(
      bslib::card_header("Tabla de índices por año de fuego"),
      DT::DTOutput(ns("tabla"))
    )
  )
}

mod_temporada_server <- function(id, datos, plataforma) {
  shiny::moduleServer(id, function(input, output, session) {

    tabla <- shiny::reactive({
      t <- datos$datos[[plataforma()]]$temporada_anual
      if (isTRUE(input$solo_confiables)) t <- t[t$confiable, ]
      t
    })
    info <- shiny::reactive(datos$plataformas[datos$plataformas$clave == plataforma(), ])

    output$resumen <- shiny::renderUI({
      t <- datos$datos[[plataforma()]]$temporada_anual
      ok <- t[t$confiable, ]
      p <- info()
      shiny::tags$div(class = "small",
        shiny::tags$p(shiny::tags$strong(p$etiqueta), shiny::tags$br(),
                      "Registro desde ", fecha_es(p$registro_inicio), "; ",
                      "estándar hasta ", fecha_es(p$fin_estandar), "."),
        shiny::tags$p(nrow(ok), " años completos (", min(ok$anio_fuego), "–",
                      max(ok$anio_fuego), "). Longitud media ",
                      num_es(mean(ok$lon), 0), " días; inicio mediano el ",
                      dia_es(stats::median(ok$ini_dia)), " y fin mediano el ",
                      dia_es(stats::median(ok$fin_dia)), "."),
        shiny::tags$p("Periodo base de los índices de conteo: ",
                      p$base_inicio, "–", p$base_fin, ".")
      )
    })

    output$segmentos <- plotly::renderPlotly({
      t <- tabla()
      t <- t[!is.na(t$lon), ]
      t$x0 <- fecha_de_dia(t$ini_dia); t$x1 <- fecha_de_dia(t$fin_dia)
      t$color <- ifelse(t$confiable, COLOR_DETECCIONES, COLOR_RESERVA)
      t$texto <- paste0("<b>", t$anio_fuego, "</b><br>Inicio: ", fecha_es(t$ini_fecha),
                        "<br>Fin: ", fecha_es(t$fin_fecha), "<br>Longitud: ", t$lon,
                        " días<br>Detecciones: ", num_es(t$dtot, 0),
                        ifelse(t$nota == "", "", paste0("<br><i>", t$nota, "</i>")))
      p <- plotly::plot_ly()
      for (i in seq_len(nrow(t))) {
        p <- plotly::add_segments(p, x = t$x0[i], xend = t$x1[i], y = t$anio_fuego[i],
                                  yend = t$anio_fuego[i],
                                  line = list(color = t$color[i], width = 8),
                                  hoverinfo = "text", text = t$texto[i],
                                  showlegend = FALSE)
      }
      bandas <- list(
        list(x0 = as.Date("2001-12-01"), x1 = as.Date("2002-04-30"), color = "#fdd49e"),
        list(x0 = as.Date("2002-01-01"), x1 = as.Date("2002-05-31"), color = "#a6bddb"))
      formas <- lapply(bandas, function(b) list(type = "rect", xref = "x", yref = "paper",
                                                x0 = b$x0, x1 = b$x1, y0 = 0, y1 = 1,
                                                fillcolor = b$color, opacity = 0.18,
                                                line = list(width = 0), layer = "below"))
      plotly::layout(
        p,
        shapes = formas,
        xaxis = list(title = "", tickformat = "%d %b", range = c(as.Date("2001-11-15"),
                                                                 as.Date("2002-07-15"))),
        yaxis = list(title = "Año de fuego", autorange = "reversed", dtick = 1),
        annotations = list(
          list(x = as.Date("2002-02-15"), y = 1.02, yref = "paper", showarrow = FALSE,
               text = "Bandas: época seca del IMN (dic–abr) y temporada del SINAC (ene–may)",
               font = list(size = 11, color = "grey40"))),
        margin = list(l = 60, r = 20, t = 30, b = 40)
      ) |> plotly::config(displaylogo = FALSE, locale = "es")
    })

    output$titulo_barras <- shiny::renderText({
      INDICES_ANUALES$rotulo[INDICES_ANUALES$columna == input$indice]
    })

    output$barras <- plotly::renderPlotly({
      t <- tabla(); v <- input$indice
      fila <- INDICES_ANUALES[INDICES_ANUALES$columna == v, ]
      t <- t[!is.na(t[[v]]) & t$dtot > 0, ]
      valor <- t[[v]]
      texto <- if (v %in% c("ini_dia", "fin_dia")) dia_es(valor) else num_es(valor, fila$decimales)
      plotly::plot_ly(
        x = t$anio_fuego, y = valor, type = "bar",
        marker = list(color = ifelse(t$confiable, COLOR_DETECCIONES, COLOR_RESERVA)),
        hoverinfo = "text",
        text = paste0("<b>", t$anio_fuego, "</b><br>", fila$rotulo, ": ", texto,
                      ifelse(t$nota == "", "", paste0("<br><i>", t$nota, "</i>")))
      ) |>
        plotly::layout(xaxis = list(title = "Año de fuego", dtick = 1),
                       yaxis = list(title = fila$unidad),
                       margin = list(l = 60, r = 20, t = 10, b = 60)) |>
        plotly::config(displaylogo = FALSE, locale = "es")
    })

    output$tabla <- DT::renderDT({
      t <- tabla()
      d <- data.frame(
        `Año de fuego` = t$anio_fuego, Detecciones = t$dtot,
        Inicio = ifelse(is.na(t$ini_fecha), "", fecha_es(t$ini_fecha, con_anio = FALSE)),
        Fin = ifelse(is.na(t$fin_fecha), "", fecha_es(t$fin_fecha, con_anio = FALSE)),
        `Longitud (días)` = t$lon, `Días de fuego` = t$df, N50 = t$n50,
        `C10 (%)` = t$c10, `FRPI (MW)` = t$frpi, `FRP95 (MW)` = t$frp95,
        ND95 = t$nd95, `D95pTOT (%)` = t$d95ptot, Nota = t$nota,
        check.names = FALSE)
      DT::datatable(d, rownames = FALSE, options = list(pageLength = 30, dom = "t",
                                                        scrollX = TRUE))
    })

    output$descargar <- shiny::downloadHandler(
      filename = function() paste0("temporada_anual_", plataforma(), ".csv"),
      content = function(file) {
        readr::write_csv(datos$datos[[plataforma()]]$temporada_anual, file)
      }
    )
  })
}
