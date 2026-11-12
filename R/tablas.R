# Derived tables. Each takes rows already filtered by one lectura, except
# tabla_sensibilidad, which runs the whole grid of lecturas.

# Full grid: comparacion x periodo x the 16 on/off combinations of the four
# switches.
grilla_lecturas <- function() {
  tidyr::expand_grid(
    comparacion = comparaciones_validas,
    periodo = periodos_validos,
    excluir_entrada_almacen_hgm = c(FALSE, TRUE),
    excluir_duplicados_exactos = c(FALSE, TRUE),
    excluir_menudeo = c(FALSE, TRUE),
    solo_ambulatorio = c(FALSE, TRUE)
  )
}

# Counts follow the principal indicator (config: lectura_principal$indicador):
# a group counts when that indicator is non-NA. The *_mediana columns repeat
# the counts on the per-row median, as sensitivity. With excluir_menudeo the
# grid reports the principal reading with and without retail-pharmacy rows.
tabla_sensibilidad <- function(base, claves_universo, grilla = grilla_lecturas(),
                               columna_precio = config$columna_precio,
                               umbral = config$umbral_claves,
                               indicador = indicador_principal()) {
  resumen <- purrr::pmap(grilla, function(comparacion, ...) {
    lectura <- list(...)
    res <- calcular_lectura(base, claves_universo, lectura, comparacion,
                            columna_precio = columna_precio,
                            indicador = indicador)
    con_indicador <- dplyr::filter(res$medianas, !is.na(.data[[indicador]]))
    tibble::tibble(
      grupo_requerido = grupo_requerido_para(comparacion) %||% "",
      indicador = indicador,
      filas_usadas = nrow(res$filas),
      filas_sin_cantidad = sum(res$medianas$n_sin_cantidad),
      claves_con_precio = dplyr::n_distinct(res$medianas$clave_cnis),
      claves_con_indicador = dplyr::n_distinct(con_indicador$clave_cnis),
      n_grupos = dplyr::n_distinct(res$medianas$grupo),
      claves_comparadas_agrupado = sum(res$comparadas$comparada_agrupado),
      claves_comparadas_mismo_año = sum(res$comparadas$comparada_mismo_año),
      claves_comparadas_agrupado_mediana =
        sum(res$comparadas$comparada_agrupado_mediana),
      claves_comparadas_mismo_año_mediana =
        sum(res$comparadas$comparada_mismo_año_mediana)
    )
  }) |>
    purrr::list_rbind()

  # How many parameters differ from the lectura base (0 = the base itself).
  cambios <- purrr::map(
    interruptores, \(x) grilla[[x]] != isTRUE(lectura_base[[x]])
  ) |>
    purrr::reduce(`+`, .init = grilla$periodo != lectura_base$periodo)

  dplyr::bind_cols(grilla, resumen) |>
    dplyr::mutate(
      lectura_principal = comparacion == lectura_principal$comparacion &
        cambios == 0,
      parametros_distintos_a_base = as.integer(cambios),
      alcanza_umbral_agrupado = claves_comparadas_agrupado >= umbral,
      alcanza_umbral_mismo_año = claves_comparadas_mismo_año >= umbral
    )
}

# Per group summary used by the IMSS vs ISSSTE gap: per-row and quantity-
# weighted medians (nominal and real) plus the sets of nominal prices and
# procedure numbers.
resumen_conjuntos <- function(datos_grupo, columna_precio) {
  datos_grupo |>
    con_precios(columna_precio) |>
    dplyr::group_by(clave_cnis, año_fiscal, grupo) |>
    dplyr::summarise(
      factor_deflacion = dplyr::first(.factor),
      inpc_meses = dplyr::first(.meses),
      n_filas = dplyr::n(),
      n_sin_cantidad = sum(sin_cantidad(.precio, .cantidad)),
      mediana = stats::median(.precio),
      mediana_real = mediana_o_na(.real),
      mediana_ponderada_cantidad = mediana_ponderada(.precio, .cantidad),
      mediana_ponderada_cantidad_real = mediana_ponderada(.real, .cantidad),
      precios = list(sort(unique(round(.precio, 4)))),
      procedimientos = list(sort(unique(stats::na.omit(id_procedimiento)))),
      .groups = "drop"
    )
}

# Ratio and difference use the principal indicator (config); the *_mediana
# versions use the per-row median, as sensitivity.
brecha_imss_issste <- function(datos, columna_precio = config$columna_precio,
                               indicador = indicador_principal()) {
  col <- function(lado, real = FALSE) {
    paste0(indicador, if (real) "_real", "_", lado)
  }
  conjuntos <- datos |>
    asignar_grupos("imss_issste") |>
    resumen_conjuntos(columna_precio)
  imss <- dplyr::filter(conjuntos, grupo == "IMSS") |> dplyr::select(-grupo)
  # Same clave-year, same factor: keep it once.
  issste <- dplyr::filter(conjuntos, grupo == "ISSSTE") |>
    dplyr::select(-grupo, -factor_deflacion, -inpc_meses)

  dplyr::inner_join(imss, issste, by = c("clave_cnis", "año_fiscal"),
                    suffix = c("_imss", "_issste")) |>
    dplyr::mutate(
      razon_issste_imss = .data[[col("issste")]] / .data[[col("imss")]],
      diferencia_issste_menos_imss = .data[[col("issste")]] - .data[[col("imss")]],
      diferencia_issste_menos_imss_real =
        .data[[col("issste", TRUE)]] - .data[[col("imss", TRUE)]],
      razon_issste_imss_mediana = mediana_issste / mediana_imss,
      diferencia_issste_menos_imss_mediana = mediana_issste - mediana_imss,
      diferencia_issste_menos_imss_mediana_real =
        mediana_real_issste - mediana_real_imss,
      procedimientos_compartidos = purrr::map2_chr(
        procedimientos_imss, procedimientos_issste,
        \(a, b) paste(intersect(a, b), collapse = "; ")
      ),
      mismo_procedimiento = procedimientos_compartidos != "",
      precio_identico = purrr::map2_lgl(precios_imss, precios_issste, identical)
    ) |>
    dplyr::select(
      clave_cnis, año_fiscal, n_filas_imss, n_filas_issste,
      n_sin_cantidad_imss, n_sin_cantidad_issste,
      mediana_ponderada_cantidad_imss, mediana_ponderada_cantidad_issste,
      mediana_imss, mediana_issste, razon_issste_imss,
      diferencia_issste_menos_imss, razon_issste_imss_mediana,
      diferencia_issste_menos_imss_mediana,
      factor_deflacion, inpc_meses,
      mediana_ponderada_cantidad_imss_real = mediana_ponderada_cantidad_real_imss,
      mediana_ponderada_cantidad_issste_real =
        mediana_ponderada_cantidad_real_issste,
      mediana_imss_real = mediana_real_imss,
      mediana_issste_real = mediana_real_issste,
      diferencia_issste_menos_imss_real,
      diferencia_issste_menos_imss_mediana_real,
      mismo_procedimiento, precio_identico, procedimientos_compartidos
    ) |>
    dplyr::arrange(clave_cnis, año_fiscal) |>
    renombrar_real()
}

# State indicators per clave x entidad x año against the pooled federal ones
# of the same clave-year. con_federal_mismo_año and razon_estatal_federal use
# the principal indicator (config); razon_estatal_federal_mediana uses the
# per-row median, as sensitivity. State rows without a federal principal
# indicator keep NA and con_federal_mismo_año = FALSE: they do not count in
# the principal reading.
# When `datos` comes from filtrar_lectura(arrastre_ciclo = TRUE), the federal
# reference of a year pools the federal rows of that year with the cycle
# prices carried from the year before; n_filas_federal counts both, and
# n_filas_federal_ciclo_arrastrado and federal_con_ciclo_arrastrado mark the
# rows whose reference uses a carried cycle price.
brecha_federal_estatal <- function(datos, columna_precio = config$columna_precio,
                                   indicador = indicador_principal()) {
  real <- paste0("mediana", sufijo_real)
  pond <- "mediana_ponderada_cantidad"
  pond_real <- paste0(pond, sufijo_real)
  # Source columns of mediana_por_grupo, renamed to <name>_<side>[_real].
  lado <- function(sufijo) {
    destino <- c(
      paste0(c("n_filas", "n_sin_cantidad", pond, "mediana"), "_", sufijo),
      paste0(c(pond, "mediana"), "_", sufijo, "_real")
    )
    rlang::set_names(
      c("n_filas", "n_sin_cantidad", pond, "mediana", pond_real, real),
      destino
    )
  }
  grupos <- asignar_grupos(datos, "federal_vs_estatal")
  medianas <- mediana_por_grupo(grupos, columna_precio)
  arrastradas <- grupos |>
    dplyr::mutate(.copia = es_copia_ciclo(grupos)) |>
    dplyr::filter(grupo == etiqueta_federal) |>
    dplyr::summarise(n_filas_federal_ciclo_arrastrado = sum(.copia),
                     .by = c(clave_cnis, año_fiscal))
  federal <- medianas |>
    dplyr::filter(grupo == etiqueta_federal) |>
    dplyr::select(clave_cnis, año_fiscal, dplyr::all_of(lado("federal"))) |>
    dplyr::left_join(arrastradas, by = c("clave_cnis", "año_fiscal"))
  medianas |>
    dplyr::filter(grupo != etiqueta_federal) |>
    dplyr::select(clave_cnis, entidad_federativa = grupo, año_fiscal,
                  factor_deflacion, inpc_meses,
                  dplyr::all_of(lado("estatal"))) |>
    dplyr::left_join(federal, by = c("clave_cnis", "año_fiscal")) |>
    dplyr::mutate(
      con_federal_mismo_año = !is.na(.data[[paste0(indicador, "_federal")]]),
      federal_con_ciclo_arrastrado =
        dplyr::coalesce(n_filas_federal_ciclo_arrastrado, 0L) > 0,
      razon_estatal_federal = .data[[paste0(indicador, "_estatal")]] /
        .data[[paste0(indicador, "_federal")]],
      razon_estatal_federal_mediana = mediana_estatal / mediana_federal
    ) |>
    dplyr::relocate(n_filas_estatal, n_sin_cantidad_estatal,
                    mediana_ponderada_cantidad_estatal, mediana_estatal,
                    n_filas_federal, n_sin_cantidad_federal,
                    mediana_ponderada_cantidad_federal, mediana_federal,
                    con_federal_mismo_año, n_filas_federal_ciclo_arrastrado,
                    federal_con_ciclo_arrastrado, razon_estatal_federal,
                    razon_estatal_federal_mediana, factor_deflacion,
                    inpc_meses, mediana_ponderada_cantidad_estatal_real,
                    mediana_ponderada_cantidad_federal_real,
                    mediana_estatal_real, mediana_federal_real,
                    .after = año_fiscal) |>
    dplyr::arrange(clave_cnis, entidad_federativa, año_fiscal) |>
    renombrar_real()
}

# Per clave x año: pooled federal and pooled state (all entidades together)
# quantity-weighted median (principal indicator) and per-row median
# (sensitivity), nominal and in pesos of the base year, with n rows and rows
# without usable quantity. Keeps clave-years that have only one side.
serie_real_por_clave <- function(datos, columna_precio = config$columna_precio) {
  medianas <- datos |>
    asignar_grupos("federal_vs_estatal") |>
    dplyr::mutate(grupo = dplyr::if_else(grupo == etiqueta_federal,
                                         "federal", "estatal")) |>
    mediana_por_grupo(columna_precio) |>
    dplyr::select(clave_cnis, grupo, año_fiscal, factor_deflacion, inpc_meses,
                  n_filas, n_sin_cantidad, mediana,
                  mediana_real = dplyr::all_of(paste0("mediana", sufijo_real)),
                  pond = mediana_ponderada_cantidad,
                  pond_real = dplyr::all_of(
                    paste0("mediana_ponderada_cantidad", sufijo_real)
                  ))
  valores <- c("n_filas", "n_sin_cantidad", "mediana", "mediana_real", "pond",
               "pond_real")
  ancho <- tidyr::pivot_wider(
    dplyr::select(medianas, -factor_deflacion, -inpc_meses),
    names_from = grupo, values_from = dplyr::all_of(valores),
    names_glue = "{.value}_{grupo}"
  )
  for (col in c(paste0(valores, "_federal"), paste0(valores, "_estatal"))) {
    if (!col %in% names(ancho)) ancho[[col]] <- NA_real_
  }
  factores <- dplyr::distinct(medianas, año_fiscal, factor_deflacion, inpc_meses)
  ancho |>
    dplyr::left_join(factores, by = "año_fiscal") |>
    dplyr::transmute(
      clave_cnis, año_fiscal, factor_deflacion, inpc_meses,
      n_filas_federal, n_sin_cantidad_federal,
      mediana_ponderada_cantidad_federal = pond_federal,
      mediana_federal,
      mediana_ponderada_cantidad_federal_real = pond_real_federal,
      mediana_federal_real = mediana_real_federal,
      n_filas_estatal, n_sin_cantidad_estatal,
      mediana_ponderada_cantidad_estatal = pond_estatal,
      mediana_estatal,
      mediana_ponderada_cantidad_estatal_real = pond_real_estatal,
      mediana_estatal_real = mediana_real_estatal
    ) |>
    dplyr::arrange(clave_cnis, año_fiscal) |>
    renombrar_real()
}

# Rows above 2x and 5x the clave-year median are counted, not labelled: they
# can be overprice or unit errors. Counted twice: against the per-row median
# (filas_sobre_*_mediana_año) and against the quantity-weighted median of the
# clave-year (filas_sobre_*_mediana_ponderada_año; clave-years without a
# weighted median add no rows there). Real columns: within a clave-year they are
# the nominal ones times the factor; pooled over years they are computed on
# the rows with INPC (n_filas_con_inpc), so fiscal year 2027 is left out.
dispersion_por_clave <- function(datos, columna_precio = config$columna_precio) {
  p10_o_na <- o_na(\(x) unname(stats::quantile(x, 0.10)))
  p90_o_na <- o_na(\(x) unname(stats::quantile(x, 0.90)))
  marcados <- datos |>
    con_precios(columna_precio) |>
    dplyr::filter(!is.na(.precio)) |>
    dplyr::group_by(clave_cnis, año_fiscal) |>
    dplyr::mutate(
      .mediana_año = stats::median(.precio),
      .sobre_2x = .precio > 2 * .mediana_año,
      .sobre_5x = .precio > 5 * .mediana_año,
      .pond_año = mediana_ponderada(.precio, .cantidad),
      .sobre_2x_pond = dplyr::coalesce(.precio > 2 * .pond_año, FALSE),
      .sobre_5x_pond = dplyr::coalesce(.precio > 5 * .pond_año, FALSE)
    ) |>
    dplyr::ungroup()

  resumir <- function(x, ..., por_año = FALSE) {
    res <- x |>
      dplyr::group_by(...) |>
      dplyr::summarise(
        n_filas = dplyr::n(),
        n_sin_cantidad = sum(sin_cantidad(.precio, .cantidad)),
        mediana_ponderada_cantidad = mediana_ponderada(.precio, .cantidad),
        mediana = stats::median(.precio),
        p10 = unname(stats::quantile(.precio, 0.10)),
        p90 = unname(stats::quantile(.precio, 0.90)),
        minimo = min(.precio),
        maximo = max(.precio),
        razon_max_min = maximo / minimo,
        n_tipos_institucion = dplyr::n_distinct(tipo_institucion),
        n_entidades = dplyr::n_distinct(entidad_federativa),
        filas_sobre_2x_mediana_año = sum(.sobre_2x),
        filas_sobre_5x_mediana_año = sum(.sobre_5x),
        filas_sobre_2x_mediana_ponderada_año = sum(.sobre_2x_pond),
        filas_sobre_5x_mediana_ponderada_año = sum(.sobre_5x_pond),
        factor_deflacion = dplyr::first(.factor),
        inpc_meses = dplyr::first(.meses),
        n_filas_con_inpc = sum(!is.na(.real)),
        mediana_ponderada_cantidad_real = mediana_ponderada(.real, .cantidad),
        mediana_real = mediana_o_na(.real),
        p10_real = p10_o_na(.real),
        p90_real = p90_o_na(.real),
        minimo_real = minimo_o_na(.real),
        maximo_real = maximo_o_na(.real),
        razon_max_min_real = maximo_real / minimo_real,
        .groups = "drop"
      )
    if (!por_año) {
      # The factor varies across years; it only means something per year.
      res <- dplyr::select(res, -factor_deflacion, -inpc_meses)
    }
    renombrar_real(res)
  }
  list(
    por_clave = resumir(marcados, clave_cnis),
    por_clave_año = resumir(marcados, clave_cnis, año_fiscal, por_año = TRUE)
  )
}

# Presence matrix: n comparable rows per clave x a column, every universe key
# listed even when absent.
matriz_presencia <- function(datos, universo, columna) {
  conteo <- datos |>
    dplyr::count(clave_cnis, .data[[columna]], name = "n") |>
    tidyr::pivot_wider(names_from = dplyr::all_of(columna), values_from = n,
                       values_fill = 0L, names_sort = TRUE)
  universo |>
    dplyr::select(clave_cnis, componente, area) |>
    dplyr::left_join(conteo, by = "clave_cnis") |>
    dplyr::mutate(dplyr::across(-c(clave_cnis, componente, area),
                                \(x) dplyr::coalesce(x, 0L))) |>
    dplyr::mutate(total = rowSums(dplyr::pick(-c(clave_cnis, componente, area)))) |>
    dplyr::arrange(area, componente, clave_cnis)
}

cobertura <- function(datos, universo) {
  list(
    tipo_institucion = matriz_presencia(datos, universo, "tipo_institucion"),
    entidad = matriz_presencia(datos, universo, "entidad_federativa")
  )
}

# Adds the component name next to the key, for reading.
con_componente <- function(tabla, universo) {
  tabla |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente),
                     by = "clave_cnis") |>
    dplyr::relocate(componente, .after = clave_cnis)
}

# Retail-pharmacy sensitivity on prices: the medianas table recomputed with
# the same row filters but excluir_menudeo = TRUE, on exactly the rows
# (comparacion x clave x grupo x año) of `medianas_con`. Groups whose rows were
# all retail keep their row with n_filas = 0 and NA prices, so the reader sees
# which groups are retail-only. The deflation factor depends only on the year,
# so those rows take it from `medianas_con`. mediana_ponderada_cantidad_con_
# menudeo is the principal value from `medianas_con`, and razon_sin_entre_con
# = sin / con (NA when either side is missing).
medianas_sin_menudeo <- function(base, claves_universo, medianas_con,
                                 lectura = lectura_contexto,
                                 columna_precio = config$columna_precio,
                                 factores = NULL) {
  lectura$excluir_menudeo <- TRUE
  llaves <- c("comparacion", "clave_cnis", "grupo", "año_fiscal")
  sin <- purrr::map(
    rlang::set_names(unique(medianas_con$comparacion)),
    \(comp) calcular_lectura(base, claves_universo, lectura, comp,
                             columna_precio = columna_precio,
                             factores = factores)$medianas
  ) |>
    purrr::list_rbind(names_to = "comparacion") |>
    dplyr::select(-factor_deflacion, -inpc_meses)
  con <- dplyr::select(
    medianas_con, dplyr::any_of(c(llaves, "componente", "factor_deflacion",
                                  "inpc_meses")),
    mediana_ponderada_cantidad_con_menudeo = mediana_ponderada_cantidad
  )
  dplyr::left_join(con, sin, by = llaves) |>
    dplyr::mutate(
      n_filas = dplyr::coalesce(n_filas, 0L),
      n_sin_cantidad = dplyr::coalesce(n_sin_cantidad, 0L),
      razon_sin_entre_con =
        mediana_ponderada_cantidad / mediana_ponderada_cantidad_con_menudeo
    ) |>
    # Same column order as medianas, the two comparison columns after the
    # principal value.
    dplyr::select(dplyr::all_of(names(medianas_con)),
                  mediana_ponderada_cantidad_con_menudeo,
                  razon_sin_entre_con) |>
    dplyr::relocate(mediana_ponderada_cantidad_con_menudeo, razon_sin_entre_con,
                    .after = mediana_ponderada_cantidad)
}
