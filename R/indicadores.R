# Core indicators per clave x grupo x año_fiscal: per-row median, quantity-
# weighted median (principal, see lectura_principal$indicador in config.R) and
# quantity-weighted mean; and the "comparada" rule.

# Quantity that matches the price column, for the weighted mean and median.
columna_cantidad_para <- function(columna_precio) {
  if (columna_precio == "precio_por_unidad_minima_mxn") {
    "cantidad_unidades_minimas"
  } else {
    "cantidad_envases"
  }
}

media_ponderada <- function(precio, cantidad) {
  ok <- !is.na(precio) & !is.na(cantidad) & cantidad > 0
  if (!any(ok)) {
    return(NA_real_)
  }
  sum(precio[ok] * cantidad[ok]) / sum(cantidad[ok])
}

# Rows whose quantity cannot weight: missing or non-positive. Rows without a
# price are not counted (they never enter a median).
sin_cantidad <- function(precio, cantidad) {
  !is.na(precio) & (is.na(cantidad) | cantidad <= 0)
}

# Quantity-weighted median (convention: sort by price; the weighted median is
# the smallest price whose cumulative quantity reaches at least half the total
# quantity). Rows with missing price or missing / non-positive quantity are
# left out; NA when no row is left. A relative tolerance absorbs floating
# point error in the cumulative sum, so an exact half-weight boundary picks
# the lower price.
mediana_ponderada <- function(precio, cantidad) {
  ok <- !is.na(precio) & !is.na(cantidad) & cantidad > 0
  if (!any(ok)) {
    return(NA_real_)
  }
  orden <- order(precio[ok])
  p <- precio[ok][orden]
  acumulada <- cumsum(cantidad[ok][orden])
  mitad <- acumulada[length(acumulada)] / 2
  p[which(acumulada >= mitad * (1 - sqrt(.Machine$double.eps)))[1]]
}

# Indicators the layer can treat as "the" price of a clave x grupo x año. The
# principal one is set in config.R (lectura_principal$indicador).
indicadores_validos <- c("mediana", "mediana_ponderada_cantidad")

indicador_principal <- function(indicador = lectura_principal$indicador) {
  if (!indicador %in% indicadores_validos) {
    stop("Indicador no reconocido: ", indicador, call. = FALSE)
  }
  indicador
}

# Adds .precio (nominal), .cantidad (the quantity matching the price column),
# .real (pesos of the base year), .factor and .meses.
# Rows not passed through deflactar_precios() get NA in the last three, so the
# real columns of every table exist and read NA rather than nominal.
con_precios <- function(datos, columna_precio) {
  real <- columna_real(columna_precio)
  n <- nrow(datos)
  dplyr::mutate(
    datos,
    .precio = .data[[columna_precio]],
    .cantidad = .data[[columna_cantidad_para(columna_precio)]],
    .real = if (real %in% names(datos)) .data[[real]] else rep(NA_real_, n),
    .factor = if ("factor_deflacion" %in% names(datos)) {
      factor_deflacion
    } else {
      rep(NA_real_, n)
    },
    .meses = if ("inpc_meses" %in% names(datos)) inpc_meses else rep(NA_integer_, n)
  )
}

# Summaries of real prices: NA when none is known (e.g. fiscal year 2027),
# otherwise computed on the known ones.
o_na <- function(f) {
  function(x) if (all(is.na(x))) NA_real_ else f(x[!is.na(x)])
}
mediana_o_na <- o_na(stats::median)
minimo_o_na <- o_na(min)
maximo_o_na <- o_na(max)

# Within one clave x grupo x año every row shares the factor, so the real
# median is the nominal one times the factor.
mediana_por_grupo <- function(datos_grupo, columna_precio = config$columna_precio) {
  res <- datos_grupo |>
    con_precios(columna_precio) |>
    dplyr::filter(!is.na(.precio)) |>
    dplyr::group_by(clave_cnis, grupo, año_fiscal) |>
    dplyr::summarise(
      n_filas = dplyr::n(),
      n_sin_cantidad = sum(sin_cantidad(.precio, .cantidad)),
      mediana = stats::median(.precio),
      mediana_ponderada_cantidad = mediana_ponderada(.precio, .cantidad),
      minimo = min(.precio),
      maximo = max(.precio),
      media_ponderada_cantidad = media_ponderada(.precio, .cantidad),
      factor_deflacion = dplyr::first(.factor),
      inpc_meses = dplyr::first(.meses),
      mediana_real = mediana_o_na(.real),
      mediana_ponderada_cantidad_real = mediana_ponderada(.real, .cantidad),
      minimo_real = minimo_o_na(.real),
      maximo_real = maximo_o_na(.real),
      media_ponderada_cantidad_real = media_ponderada(.real, .cantidad),
      .groups = "drop"
    )
  renombrar_real(res)
}

# Gives the real columns their final suffix (e.g. mediana_real_2025).
renombrar_real <- function(tabla) {
  dplyr::rename_with(tabla, \(x) sub("_real$", sufijo_real, x),
                     dplyr::ends_with("_real"))
}

# A key is "comparada" when it has a median in at least `min_grupos` groups.
# Two readings: pooled over the period, or within one same fiscal year.
# `grupo_requerido` demands that one named group be among them; the principal
# reading requires the pooled federal group (see grupos_requeridos, config.R).
claves_comparadas <- function(medianas, min_grupos = 2, grupo_requerido = NULL) {
  cumple <- function(grupos) {
    length(unique(grupos)) >= min_grupos &&
      (is.null(grupo_requerido) || grupo_requerido %in% grupos)
  }
  agrupado <- medianas |>
    dplyr::group_by(clave_cnis) |>
    dplyr::summarise(
      n_grupos = dplyr::n_distinct(grupo),
      comparada_agrupado = cumple(grupo),
      .groups = "drop"
    )
  mismo_año <- medianas |>
    dplyr::group_by(clave_cnis, año_fiscal) |>
    dplyr::summarise(cumple_año = cumple(grupo), .groups = "drop") |>
    dplyr::group_by(clave_cnis) |>
    dplyr::summarise(
      años_comparados = paste(sort(año_fiscal[cumple_año]), collapse = ", "),
      comparada_mismo_año = any(cumple_año),
      .groups = "drop"
    )
  dplyr::left_join(agrupado, mismo_año, by = "clave_cnis")
}

# Group the comparison requires (config: grupos_requeridos), NULL if none.
grupo_requerido_para <- function(comparacion) {
  grupos_requeridos[[comparacion]]
}

# One lectura x one comparacion: filtered rows, medians and compared keys.
# `factores` (from factores_deflacion) adds the real-price columns; without it
# they are NA. Pass grupo_requerido = NULL to drop the required-group rule.
# A group counts toward "comparada" only when its principal indicator is
# non-NA (a weighted median needs at least one row with usable quantity). The
# same rule on the per-row median is kept as sensitivity: columns with the
# suffix _mediana (n_grupos_mediana, comparada_agrupado_mediana, ...).
# In federal_vs_estatal, with ciclo_bianual = TRUE (config), the rule reads the
# federal reference that also carries each cycle price into its second year
# (copias_segundo_año_ciclo, filtrar.R). `filas` and `medianas` never include
# those copies: one row per award. `canal` restricts the channel (annex).
calcular_lectura <- function(base, claves_universo, lectura, comparacion,
                             columna_precio = config$columna_precio,
                             factores = NULL,
                             grupo_requerido = grupo_requerido_para(comparacion),
                             indicador = indicador_principal(),
                             ciclo_bianual =
                               lectura_principal$ciclo_bianual_segundo_año,
                             canal = NULL) {
  arrastre <- isTRUE(ciclo_bianual) && comparacion == "federal_vs_estatal"
  con_copias <- filtrar_lectura(base, claves_universo, lectura,
                                columna_precio = columna_precio, canal = canal,
                                arrastre_ciclo = arrastre) |>
    deflactar_precios(factores) |>
    asignar_grupos(comparacion)
  filas <- con_copias[!es_copia_ciclo(con_copias), ] |>
    dplyr::select(-dplyr::any_of("ciclo_arrastrado"))
  medianas <- mediana_por_grupo(filas, columna_precio)
  referencia <- if (arrastre) mediana_por_grupo(con_copias, columna_precio) else medianas
  con_indicador <- dplyr::filter(referencia, !is.na(.data[[indicador]]))
  principal <- claves_comparadas(con_indicador, grupo_requerido = grupo_requerido)
  por_fila <- claves_comparadas(referencia, grupo_requerido = grupo_requerido) |>
    dplyr::rename_with(\(x) paste0(x, "_mediana"), -clave_cnis)
  # Keys whose groups all lack quantity are absent from `principal`; they are
  # kept with n_grupos = 0 and comparada = FALSE.
  comparadas <- dplyr::left_join(por_fila, principal, by = "clave_cnis") |>
    dplyr::mutate(
      n_grupos = dplyr::coalesce(n_grupos, 0L),
      comparada_agrupado = dplyr::coalesce(comparada_agrupado, FALSE),
      años_comparados = dplyr::coalesce(años_comparados, ""),
      comparada_mismo_año = dplyr::coalesce(comparada_mismo_año, FALSE)
    ) |>
    dplyr::relocate(n_grupos, comparada_agrupado, años_comparados,
                    comparada_mismo_año, .after = clave_cnis)
  list(
    filas = filas,
    medianas = medianas,
    comparadas = comparadas
  )
}
