# Quality comparator (Andrés, 2026-11-08): how much of what IMSS and ISSSTE
# prescribe the price reading captures, with OCAMIS prescription data.
# Quantities in OCAMIS ("prescrito") are boxes (envases), the unit of
# cantidad_envases in the base. OCAMIS years are ISO years (sheet "datos").

columnas_ocamis <- c(
  "año ISO", "semana ISO", "institución", "clave", "prescrito", "entregado",
  "recetas"
)

# Reads the sheet "datos" of the OCAMIS workbook. guess_max is high because
# some columns (estado) are empty in the early rows.
leer_ocamis <- function(ruta = config$ruta_ocamis, hoja = "datos") {
  if (!file.exists(ruta)) {
    stop("No existe el archivo de OCAMIS: ", ruta, call. = FALSE)
  }
  datos <- readxl::read_excel(ruta, sheet = hoja, guess_max = 1e6)
  faltan <- setdiff(columnas_ocamis, names(datos))
  if (length(faltan) > 0) {
    stop("Faltan columnas en OCAMIS: ", paste(faltan, collapse = ", "),
         call. = FALSE)
  }
  tibble::tibble(
    año = as.integer(datos[["año ISO"]]),
    semana = as.integer(datos[["semana ISO"]]),
    institucion = datos[["institución"]],
    clave_cnis = datos[["clave"]],
    prescrito = as.numeric(datos[["prescrito"]]),
    entregado = as.numeric(datos[["entregado"]]),
    recetas = as.numeric(datos[["recetas"]])
  )
}

# Boxes prescribed per ISO year x institution x key (universe keys only), and
# the number of ISO weeks with data in that institution-year.
prescripcion_anual <- function(ocamis, claves_universo) {
  semanas <- dplyr::summarise(ocamis, n_semanas = dplyr::n_distinct(semana),
                              .by = c(año, institucion))
  ocamis |>
    dplyr::filter(clave_cnis %in% claves_universo) |>
    dplyr::summarise(prescrito = sum(prescrito, na.rm = TRUE),
                     .by = c(año, institucion, clave_cnis)) |>
    dplyr::left_join(semanas, by = c("año", "institucion"))
}

# Short column suffix of an institution: the base's tipo_institucion, lower case.
sufijo_institucion <- function(instituciones) tolower(names(instituciones))

# Per universe key: boxes prescribed in `año` by each institution, the key's
# share of the institution's total over the universe, whether the key is
# compared in the headline (comparada_principal) and in each year of
# `años_principal`, and why it is not (motivos: clave_cnis, motivo).
# `comparadas`: one row per key with comparada_principal and años_comparados.
cobertura_prescripcion <- function(prescripcion, universo, comparadas, motivos,
                                   año = config$año_prescripcion,
                                   instituciones = config$instituciones_ocamis,
                                   años_principal = c(2024L, 2025L)) {
  base_tabla <- universo |>
    dplyr::select(clave_cnis, componente, area) |>
    dplyr::left_join(
      dplyr::select(comparadas, clave_cnis, comparada_principal, años_comparados),
      by = "clave_cnis"
    ) |>
    dplyr::mutate(comparada_principal = dplyr::coalesce(comparada_principal, FALSE))
  for (a in años_principal) {
    base_tabla[[paste0("comparada_", a)]] <-
      comparada_en_año(base_tabla$años_comparados, a)
  }
  base_tabla$años_comparados <- NULL
  for (i in seq_along(instituciones)) {
    suf <- sufijo_institucion(instituciones)[i]
    p <- prescripcion |>
      dplyr::filter(año == .env$año, institucion == instituciones[[i]]) |>
      dplyr::select(clave_cnis, prescrito)
    cajas <- dplyr::coalesce(p$prescrito[match(base_tabla$clave_cnis, p$clave_cnis)], 0)
    base_tabla[[paste0("cajas_prescritas_", suf, "_", año)]] <- cajas
    base_tabla[[paste0("parte_", suf)]] <- if (sum(cajas) > 0) cajas / sum(cajas) else NA_real_
  }
  base_tabla |>
    dplyr::left_join(dplyr::rename(motivos, motivo_no_comparada = motivo),
                     by = "clave_cnis") |>
    dplyr::mutate(motivo_no_comparada = dplyr::if_else(
      comparada_principal, NA_character_, motivo_no_comparada
    ))
}

# LEEME rows: share of each institution's prescribed boxes that belongs to
# keys compared in the headline.
resumen_cobertura_prescripcion <- function(cobertura,
                                           año = config$año_prescripcion,
                                           instituciones = config$instituciones_ocamis,
                                           seccion = "Cobertura de la prescripción") {
  valores <- purrr::map_chr(sufijo_institucion(instituciones), \(suf) {
    cajas <- cobertura[[paste0("cajas_prescritas_", suf, "_", año)]]
    si <- sum(cajas[cobertura$comparada_principal])
    sprintf("%.1f %% (%s de %s cajas prescritas en %d están en claves comparadas en la lectura principal)",
            100 * si / sum(cajas), format(si, big.mark = ","),
            format(sum(cajas), big.mark = ","), año)
  })
  tibble::tibble(seccion = seccion, campo = unname(instituciones), valor = valores)
}

# Purchases of IMSS and ISSSTE in the base that the coverage checks read:
# comparable rows of universe keys, any channel, not a duplicate of another
# row (duplicado_de empty). institucion carries the OCAMIS name.
compras_institucion <- function(base, claves_universo,
                                instituciones = config$instituciones_ocamis) {
  base |>
    dplyr::filter(comparable %in% TRUE, clave_cnis %in% claves_universo,
                  is.na(duplicado_de),
                  tipo_institucion %in% names(instituciones)) |>
    dplyr::mutate(institucion = unname(instituciones[tipo_institucion]))
}

# Per institution x fiscal year x key: boxes prescribed (universe keys; ISO
# year taken as the fiscal year) against boxes purchased in the base, with the
# minimum quantity (cantidad_envases) and the maximum where an open contract
# has one (cantidad_maxima_envases, else the minimum). Only keys with boxes on
# at least one side. ambas = boxes on both sides; the ratios (purchased /
# prescribed, minimum and maximum) are NA without prescription.
compra_vs_prescripcion_clave <- function(base, claves_universo, prescripcion,
                                         años = 2019:2024,
                                         instituciones = config$instituciones_ocamis) {
  compras <- compras_institucion(base, claves_universo, instituciones) |>
    dplyr::filter(año_fiscal %in% años) |>
    dplyr::summarise(
      comprado = sum(cantidad_envases),
      comprado_max = sum(dplyr::coalesce(cantidad_maxima_envases, cantidad_envases)),
      .by = c(institucion, año_fiscal, clave_cnis)
    ) |>
    dplyr::rename(año = año_fiscal)
  presc <- dplyr::filter(prescripcion, año %in% años,
                         institucion %in% instituciones)
  dplyr::full_join(
    dplyr::select(presc, institucion, año, clave_cnis, prescrito), compras,
    by = c("institucion", "año", "clave_cnis")
  ) |>
    dplyr::mutate(dplyr::across(c(prescrito, comprado, comprado_max),
                                \(x) dplyr::coalesce(x, 0))) |>
    dplyr::filter(prescrito > 0 | comprado > 0 | comprado_max > 0) |>
    dplyr::transmute(
      institucion, año = as.integer(año), clave_cnis,
      cajas_prescritas = prescrito,
      cajas_compradas_minimo = comprado,
      cajas_compradas_maximo = comprado_max,
      ambas = prescrito > 0 & comprado > 0,
      razon_compra_prescripcion_minimo =
        dplyr::if_else(prescrito > 0, comprado / prescrito, NA_real_),
      razon_compra_prescripcion_maximo =
        dplyr::if_else(prescrito > 0, comprado_max / prescrito, NA_real_)
    ) |>
    dplyr::arrange(institucion, año, clave_cnis)
}

# LEEME row of the per-key comparison for one institution and year: keys with
# both figures and the median of their purchased / prescribed ratio (minimum
# quantity).
resumen_compra_prescripcion_clave <- function(por_clave, institucion = "ISSSTE",
                                              año = config$año_prescripcion) {
  ambas <- dplyr::filter(por_clave, .data$institucion == .env$institucion,
                         .data$año == .env$año, ambas)
  tibble::tibble(
    seccion = "Compra contra prescripción por clave",
    campo = paste(institucion, año),
    valor = sprintf(
      "%d claves con compra y prescripción del mismo año; razón compra/prescripción (cantidad mínima), mediana entre claves: %s",
      nrow(ambas),
      if (nrow(ambas) == 0) "sin claves" else
        formatC(stats::median(ambas$razon_compra_prescripcion_minimo),
                format = "f", digits = 2)
    )
  )
}

# Per institution x fiscal year: compra_vs_prescripcion_clave() summed. Shares
# over all prescribed boxes and, on the keys with both, purchased / prescribed.
compra_vs_prescripcion <- function(base, claves_universo, prescripcion,
                                   años = 2019:2024,
                                   instituciones = config$instituciones_ocamis) {
  presc <- dplyr::filter(prescripcion, año %in% años,
                         institucion %in% instituciones)
  semanas <- dplyr::distinct(presc, institucion, año, n_semanas)
  por_clave <- compra_vs_prescripcion_clave(base, claves_universo, prescripcion,
                                            años, instituciones) |>
    dplyr::select(institucion, año, clave_cnis, prescrito = cajas_prescritas,
                  comprado = cajas_compradas_minimo,
                  comprado_max = cajas_compradas_maximo, ambas)
  resumen <- por_clave |>
    dplyr::summarise(
      cajas_prescritas = sum(prescrito),
      cajas_compradas_minimo = sum(comprado),
      cajas_compradas_maximo = sum(comprado_max),
      claves_con_prescripcion = sum(prescrito > 0),
      claves_con_compra = sum(comprado > 0),
      claves_con_ambas = sum(ambas),
      prescritas_claves_con_ambas = sum(prescrito[ambas]),
      compradas_claves_con_ambas = sum(comprado[ambas]),
      .by = c(institucion, año)
    )
  tidyr::expand_grid(institucion = unname(instituciones), año = as.integer(años)) |>
    dplyr::left_join(resumen, by = c("institucion", "año")) |>
    dplyr::left_join(semanas, by = c("institucion", "año")) |>
    dplyr::mutate(
      dplyr::across(c(cajas_prescritas:compradas_claves_con_ambas),
                    \(x) dplyr::coalesce(x, 0)),
      semanas_prescripcion = dplyr::coalesce(n_semanas, 0L),
      razon_compra_prescripcion_claves_con_ambas = dplyr::if_else(
        prescritas_claves_con_ambas > 0,
        compradas_claves_con_ambas / prescritas_claves_con_ambas, NA_real_
      ),
      parte_comprada_minimo = dplyr::if_else(
        cajas_prescritas > 0, cajas_compradas_minimo / cajas_prescritas, NA_real_
      ),
      parte_comprada_maximo = dplyr::if_else(
        cajas_prescritas > 0, cajas_compradas_maximo / cajas_prescritas, NA_real_
      )
    ) |>
    dplyr::select(institucion, año, semanas_prescripcion, cajas_prescritas,
                  cajas_compradas_minimo, cajas_compradas_maximo,
                  claves_con_prescripcion, claves_con_compra, claves_con_ambas,
                  prescritas_claves_con_ambas, compradas_claves_con_ambas,
                  razon_compra_prescripcion_claves_con_ambas,
                  parte_comprada_minimo, parte_comprada_maximo) |>
    dplyr::arrange(institucion, año)
}

# Approximation, per institution x key: the purchase of fiscal `año_compra`
# (a federal biannual cycle) per year against the boxes prescribed in
# `año_prescripcion`. Only rows tagged [CICLO_BIANUAL] are annualised (boxes
# / 2); untagged rows count as they are. Returns the table by key and a
# summary per institution with the tagged / untagged rows and boxes.
compra_ciclo_vs_prescripcion <- function(base, universo, prescripcion,
                                         año_compra = 2025L,
                                         año_prescripcion = config$año_prescripcion,
                                         instituciones = config$instituciones_ocamis,
                                         etiqueta = config$etiqueta_ciclo_bianual) {
  compras <- compras_institucion(base, universo$clave_cnis, instituciones) |>
    dplyr::filter(año_fiscal == año_compra) |>
    dplyr::mutate(ciclo = tiene_etiqueta(notas_metodologicas, etiqueta))
  por_clave_compra <- compras |>
    dplyr::summarise(
      filas_ciclo = sum(ciclo),
      filas_sin_etiqueta = sum(!ciclo),
      cajas_ciclo = sum(cantidad_envases[ciclo]),
      cajas_sin_etiqueta = sum(cantidad_envases[!ciclo]),
      .by = c(institucion, clave_cnis)
    )
  presc <- prescripcion |>
    dplyr::filter(año == año_prescripcion, institucion %in% instituciones) |>
    dplyr::select(institucion, clave_cnis, cajas_prescritas = prescrito)
  por_clave <- tidyr::expand_grid(institucion = unname(instituciones),
                                  clave_cnis = universo$clave_cnis) |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente),
                     by = "clave_cnis") |>
    dplyr::left_join(por_clave_compra, by = c("institucion", "clave_cnis")) |>
    dplyr::left_join(presc, by = c("institucion", "clave_cnis")) |>
    dplyr::mutate(
      dplyr::across(c(filas_ciclo, filas_sin_etiqueta), \(x) dplyr::coalesce(x, 0L)),
      dplyr::across(c(cajas_ciclo, cajas_sin_etiqueta, cajas_prescritas),
                    \(x) dplyr::coalesce(x, 0)),
      cajas_anuales = cajas_ciclo / 2 + cajas_sin_etiqueta,
      diferencia_anual_menos_prescrito = cajas_anuales - cajas_prescritas,
      razon_anual_prescrito = dplyr::if_else(
        cajas_prescritas > 0, cajas_anuales / cajas_prescritas, NA_real_
      )
    ) |>
    dplyr::filter(cajas_anuales > 0 | cajas_prescritas > 0) |>
    dplyr::arrange(institucion, clave_cnis)
  resumen <- por_clave |>
    dplyr::summarise(
      filas_ciclo = sum(filas_ciclo),
      filas_sin_etiqueta = sum(filas_sin_etiqueta),
      cajas_ciclo = sum(cajas_ciclo),
      cajas_sin_etiqueta = sum(cajas_sin_etiqueta),
      cajas_anuales = sum(cajas_anuales),
      cajas_prescritas = sum(cajas_prescritas),
      claves_con_compra = sum(cajas_anuales > 0),
      claves_con_prescripcion = sum(cajas_prescritas > 0),
      .by = institucion
    ) |>
    dplyr::mutate(razon_anual_prescrito = cajas_anuales / cajas_prescritas)
  list(por_clave = por_clave, resumen = resumen)
}

# LEEME rows of the approximation, one per institution.
resumen_compra_ciclo <- function(resumen, año_compra = 2025L,
                                 año_prescripcion = config$año_prescripcion) {
  fmt <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
  tibble::tibble(
    seccion = paste0("Aproximación: compra ", año_compra, " contra prescripción ",
                     año_prescripcion),
    campo = resumen$institucion,
    valor = sprintf(
      "%s cajas al año contra %s prescritas (razón %.2f). Filas %d: %d con [CICLO_BIANUAL] (%s cajas, divididas entre 2) y %d sin etiqueta (%s cajas, sin dividir)",
      fmt(resumen$cajas_anuales), fmt(resumen$cajas_prescritas),
      resumen$razon_anual_prescrito,
      as.integer(resumen$filas_ciclo + resumen$filas_sin_etiqueta),
      as.integer(resumen$filas_ciclo), fmt(resumen$cajas_ciclo),
      as.integer(resumen$filas_sin_etiqueta), fmt(resumen$cajas_sin_etiqueta)
    )
  )
}
