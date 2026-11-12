# Readings ("lecturas") and the row filter. A lectura is the set of open
# methodological parameters; every switch can be turned on or off on its own.

nueva_lectura <- function(periodo = "todo",
                          excluir_entrada_almacen_hgm = FALSE,
                          excluir_duplicados_exactos = FALSE,
                          excluir_menudeo = FALSE,
                          solo_ambulatorio = FALSE) {
  periodo <- match.arg(periodo, periodos_validos)
  list(
    periodo = periodo,
    excluir_entrada_almacen_hgm = excluir_entrada_almacen_hgm,
    excluir_duplicados_exactos = excluir_duplicados_exactos,
    excluir_menudeo = excluir_menudeo,
    solo_ambulatorio = solo_ambulatorio
  )
}

# TRUE when any of the bracketed tags appears in the notes; NA notes count as
# untagged.
tiene_etiqueta <- function(notas, etiquetas) {
  marcas <- purrr::map(
    etiquetas,
    \(etiqueta) stringr::str_detect(notas, stringr::fixed(etiqueta))
  )
  dplyr::coalesce(purrr::reduce(marcas, `|`), FALSE)
}

# The ten fields that define an exact duplicate. The price field follows the
# unit of comparison in use.
campos_duplicado <- function(columna_precio) {
  c(
    "clave_cnis", "institucion_compradora", "proveedor", columna_precio,
    "año_fiscal", "id_procedimiento", "cantidad_envases", "id_contrato_fuente",
    "fecha_documento", "monto_partida_mxn"
  )
}

# Keeps the first row (file order) of each group identical on the ten fields.
# Empty values match each other, so two rows with no procedure number and no
# date are still the same group.
colapsar_duplicados <- function(datos, columna_precio) {
  dplyr::distinct(
    datos,
    dplyr::across(dplyr::all_of(campos_duplicado(columna_precio))),
    .keep_all = TRUE
  )
}

filtrar_periodo <- function(datos, periodo) {
  switch(
    periodo,
    todo = datos,
    "2019_2026" = dplyr::filter(datos, año_fiscal >= 2019L, año_fiscal <= 2026L),
    "2024_2027" = dplyr::filter(datos, año_fiscal >= 2024L, año_fiscal <= 2027L),
    "2024_2025" = dplyr::filter(datos, año_fiscal %in% c(2024L, 2025L)),
    solo_2025 = dplyr::filter(datos, año_fiscal == 2025L),
    stop("Periodo no reconocido: ", periodo, call. = FALSE)
  )
}

# Biannual federal cycle (dictionary, rule 1): each award is recorded once,
# imputed to the first year of its cycle and tagged [CICLO_BIANUAL]; the price
# is in force in that year and the next. Returns one copy of every tagged
# federal row moved to año_fiscal + 1, with ciclo_arrastrado = TRUE. Only the
# federal-vs-state reference uses these copies (decision of 2026-11-08); no
# table of prices, quantities or spending sees them.
# The tag segment names the cycle ("El ciclo 25.26 cubre ...") on most rows;
# when it does, its first year must be the row's año_fiscal, otherwise the
# imputation is not the one the copy assumes and the run stops.
copias_segundo_año_ciclo <- function(datos,
                                     etiqueta = config$etiqueta_ciclo_bianual) {
  ciclo <- datos |>
    dplyr::filter(orden_gobierno %in% "federal",
                  tiene_etiqueta(notas_metodologicas, etiqueta))
  tramo <- stringr::str_extract(
    ciclo$notas_metodologicas,
    paste0(stringr::str_escape(etiqueta), "[^|]*")
  )
  inicio <- as.integer(stringr::str_match(tramo, "\\b(\\d{2})\\.\\d{2}\\b")[, 2])
  mal <- !is.na(inicio) & inicio != ciclo$año_fiscal %% 100L
  if (any(mal)) {
    stop("Filas ", etiqueta, " cuyo ciclo no empieza en su año fiscal: ",
         paste(utils::head(ciclo$id_registro[mal], 5), collapse = ", "),
         call. = FALSE)
  }
  dplyr::mutate(ciclo, año_fiscal = año_fiscal + 1L, ciclo_arrastrado = TRUE)
}

# Channel override (Andrés, 2026-11-08): the rows of `claves` read as
# canal = "ambulatorio" whatever the base says. Works on the copy of the base
# in memory, never on the file, and keeps the original value in canal_base so
# the moved rows can be counted (filas_reclasificadas). Run once, right after
# loading, so every reading and every channel filter sees the same channel.
reclasificar_canal <- function(base, claves = config$claves_canal_ambulatorio) {
  dplyr::mutate(
    base,
    canal_base = canal,
    canal = dplyr::if_else(clave_cnis %in% claves, "ambulatorio", canal),
    .after = canal
  )
}

# Rows the override moved to the ambulatory channel, per key x orden_gobierno:
# all rows, comparable rows and comparable rows in `periodo` (headline).
# canal_base names the channels they came from.
filas_reclasificadas <- function(base_reclasificada,
                                 claves = config$claves_canal_ambulatorio,
                                 periodo = lectura_base$periodo) {
  movidas <- base_reclasificada |>
    dplyr::filter(clave_cnis %in% claves, !canal_base %in% "ambulatorio")
  comparables <- dplyr::filter(movidas, comparable %in% TRUE)
  en_periodo <- filtrar_periodo(comparables, periodo)
  conteo <- function(datos, nombre) {
    dplyr::count(datos, clave_cnis, orden_gobierno, name = nombre)
  }
  por <- c("clave_cnis", "orden_gobierno")
  tidyr::expand_grid(clave_cnis = unname(claves),
                     orden_gobierno = c("federal", "estatal")) |>
    dplyr::mutate(componente = names(claves)[match(clave_cnis, claves)],
                  .after = clave_cnis) |>
    dplyr::left_join(
      dplyr::summarise(movidas,
                       canal_base = paste(sort(unique(canal_base)), collapse = ", "),
                       .by = dplyr::all_of(por)),
      by = por
    ) |>
    dplyr::left_join(conteo(movidas, "filas"), by = por) |>
    dplyr::left_join(conteo(comparables, "filas_comparables"), by = por) |>
    dplyr::left_join(conteo(en_periodo, "filas_comparables_periodo_principal"),
                     by = por) |>
    dplyr::mutate(
      canal_base = dplyr::coalesce(canal_base, ""),
      canal_lectura = "ambulatorio",
      dplyr::across(dplyr::starts_with("filas"), \(x) dplyr::coalesce(x, 0L)),
      .after = orden_gobierno
    )
}

# TRUE for the rows that are second-year copies of a cycle price.
es_copia_ciclo <- function(datos) {
  if ("ciclo_arrastrado" %in% names(datos)) {
    dplyr::coalesce(datos$ciclo_arrastrado, FALSE)
  } else {
    rep(FALSE, nrow(datos))
  }
}

# Returns the analysis rows for one lectura. Always starts from comparable rows
# whose key is in the universe. The duplicate collapse runs after the other
# switches, so it only merges rows that survived them.
# `canal` (outside the lectura) keeps only those channels; the hospital-channel
# annex uses it. With `arrastre_ciclo = TRUE` the second-year copies of the
# biannual cycle prices are added (column ciclo_arrastrado); only the
# federal-vs-state reference asks for them. The period filter runs last, on
# the year each row is read in, so a cycle price imputed to 2024 still counts
# in a 2025-only period and copies beyond the period drop out. Every other
# filter works row by row, and duplicates share año_fiscal, so filtering the
# period last changes nothing for rows without copies.
filtrar_lectura <- function(base,
                            claves_universo,
                            lectura,
                            columna_precio = config$columna_precio,
                            etiquetas_almacen = config$etiquetas_entrada_almacen,
                            etiqueta_menudeo = config$etiqueta_menudeo,
                            canal = NULL,
                            arrastre_ciclo = FALSE) {
  lectura <- do.call(nueva_lectura, as.list(lectura))

  datos <- base |>
    dplyr::filter(comparable %in% TRUE, clave_cnis %in% claves_universo)

  if (isTRUE(lectura$excluir_entrada_almacen_hgm)) {
    datos <- dplyr::filter(
      datos, !tiene_etiqueta(notas_metodologicas, etiquetas_almacen)
    )
  }
  if (isTRUE(lectura$excluir_menudeo)) {
    datos <- dplyr::filter(
      datos, !tiene_etiqueta(notas_metodologicas, etiqueta_menudeo)
    )
  }
  if (isTRUE(lectura$solo_ambulatorio)) {
    datos <- dplyr::filter(datos, canal %in% "ambulatorio")
  }
  if (!is.null(canal)) {
    datos <- dplyr::filter(datos, .data$canal %in% .env$canal)
  }
  if (isTRUE(lectura$excluir_duplicados_exactos)) {
    datos <- colapsar_duplicados(datos, columna_precio)
  }
  if (isTRUE(arrastre_ciclo)) {
    datos <- dplyr::bind_rows(
      dplyr::mutate(datos, ciclo_arrastrado = FALSE),
      copias_segundo_año_ciclo(datos)
    )
  }
  filtrar_periodo(datos, lectura$periodo)
}

# Keeps the rows that enter a comparison and labels the group each row belongs
# to. Rows outside the comparison are dropped. etiqueta_federal is in config.R.
asignar_grupos <- function(datos, comparacion) {
  comparacion <- match.arg(comparacion, comparaciones_validas)
  switch(
    comparacion,
    imss_issste = datos |>
      dplyr::filter(tipo_institucion %in% c("IMSS", "ISSSTE")) |>
      dplyr::mutate(grupo = tipo_institucion),
    tres_federales = datos |>
      dplyr::filter(tipo_institucion %in% c("IMSS", "ISSSTE", "IMSS-Bienestar")) |>
      dplyr::mutate(grupo = tipo_institucion),
    federal_todas = datos |>
      dplyr::filter(orden_gobierno %in% "federal") |>
      dplyr::mutate(grupo = tipo_institucion),
    entidades = datos |>
      dplyr::filter(orden_gobierno %in% "estatal") |>
      dplyr::mutate(grupo = entidad_federativa),
    federal_vs_estatal = datos |>
      dplyr::filter(orden_gobierno %in% c("federal", "estatal")) |>
      dplyr::mutate(
        grupo = dplyr::if_else(
          orden_gobierno == "federal", etiqueta_federal, entidad_federativa
        )
      )
  )
}
