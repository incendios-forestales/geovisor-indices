FROM rocker/geospatial:4.5.3

# La misma base que el pipeline anomalias-termicas-costarica: trae shiny,
# bslib, leaflet, sf, readr, jsonlite y testthat. Se agregan los paquetes de
# la app que faltan y renv/rsconnect para reproducir y desplegar.
RUN bash -lc "echo \"options(Ncpus = max(1L, parallel::detectCores()-1L))\" \
    >> /usr/local/lib/R/etc/Rprofile.site"

RUN R -q -e "install.packages(c('renv', 'rsconnect', 'plotly', 'DT', 'leafgl', \
    'shinytest2', 'httr2'))"

RUN mkdir -p /home/rstudio/.cache/R/renv && chown -R rstudio:rstudio /home/rstudio/.cache

EXPOSE 3838
