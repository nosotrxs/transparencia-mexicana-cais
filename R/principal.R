# Headline reading (Andrés, 2026-11-08, late): the report's headline figures
# are those of lectura_base (fiscal years 2024 and 2025, each pair within its
# own year; the LEEME summary also splits them by year, to show they hold in
# both years); the tables by year keep the context
# series of lectura_contexto (2019-2026). This file marks the headline inside
# the context tables and builds the headline summary of the LEEME sheet.

# Human label of a period, for the LEEME texts.
etiqueta_periodo <- function(periodo) {
  c(todo = "todo el periodo", "2019_2026" = "2019-2026",
    "2024_2027" = "2024-2027", "2024_2025" = "2024-2025",
    solo_2025 = "2025")[[periodo]]
}

# TRUE for the years the period keeps. filtrar_periodo() stays the single
# definition of a period.
en_periodo <- function(años, periodo) {
  dentro <- filtrar_periodo(tibble::tibble(año_fiscal = unique(años)), periodo)
  años %in% dentro$año_fiscal
}

# Fiscal years a period keeps, among `años`.
años_del_periodo <- function(periodo, años = 2019:2027) {
  años[en_periodo(años, periodo)]
}

# Marks the headline pairs of a federal-vs-state gap table: state x key x year
# in the headline period with the principal indicator on both sides
# (razon_estatal_federal non-NA).
marcar_pares_principal <- function(brecha, periodo = lectura_base$periodo) {
  dplyr::mutate(
    brecha,
    par_principal = en_periodo(año_fiscal, periodo) &
      !is.na(razon_estatal_federal),
    .after = año_fiscal
  )
}

# Adds to a claves_comparadas table of the context series the headline status:
# comparada_mismo_año (and its _mediana version) of the same comparison
# computed with the headline filters. `por` are the join columns.
con_comparada_principal <- function(comparadas, comparadas_principal,
                                    por = "clave_cnis") {
  principal <- dplyr::select(
    comparadas_principal, dplyr::all_of(por),
    comparada_principal = comparada_mismo_año,
    comparada_principal_mediana = comparada_mismo_año_mediana
  )
  comparadas |>
    dplyr::left_join(principal, by = por) |>
    dplyr::mutate(
      comparada_principal = dplyr::coalesce(comparada_principal, FALSE),
      comparada_principal_mediana =
        dplyr::coalesce(comparada_principal_mediana, FALSE)
    ) |>
    dplyr::relocate(comparada_principal, .after = comparada_mismo_año) |>
    dplyr::relocate(comparada_principal_mediana,
                    .after = comparada_mismo_año_mediana)
}

# Why each key of `claves` is not compared in a federal-vs-state reading
# (my label: "motivo"). Checked in this order, first match wins:
# 1. no comparable row of the key in the base, any year or channel;
# 2. no row in the period, any channel (cycle copies count as federal rows);
# 3. rows in the period only outside the reading's channel;
# 4. in the reading's channel: no federal and no state price, no federal
#    price, no state price, or both but never in the same fiscal year.
# A "price" is a non-NA principal indicator. When the missing side has rows of
# another channel in the period, the reason says so.
# `canal` as in calcular_lectura(); the headline uses lectura$solo_ambulatorio.
motivos_no_comparada <- function(base, claves, lectura = lectura_base,
                                 canal = NULL,
                                 columna_precio = config$columna_precio,
                                 indicador = indicador_principal(),
                                 ciclo = lectura_principal$ciclo_bianual_segundo_año) {
  per <- etiqueta_periodo(lectura$periodo)
  en_base <- unique(base$clave_cnis[base$comparable %in% TRUE])
  canales_lectura <- canal %||%
    (if (isTRUE(lectura$solo_ambulatorio)) "ambulatorio" else NULL)
  todos <- filtrar_lectura(
    base, claves, utils::modifyList(lectura, list(solo_ambulatorio = FALSE)),
    columna_precio = columna_precio, arrastre_ciclo = ciclo
  )
  leidas <- filtrar_lectura(base, claves, lectura,
                            columna_precio = columna_precio, canal = canal,
                            arrastre_ciclo = ciclo)
  grupos <- asignar_grupos(leidas, "federal_vs_estatal")
  # No row left (e.g. no non-compared key has annex rows): no price on either
  # side; skipping the medians avoids the warnings of an empty summary.
  con_precio <- if (nrow(grupos) == 0) {
    tibble::tibble(clave_cnis = character(), lado = character())
  } else {
    grupos |>
      mediana_por_grupo(columna_precio) |>
      dplyr::filter(!is.na(.data[[indicador]])) |>
      dplyr::mutate(lado = dplyr::if_else(grupo == etiqueta_federal,
                                          "federal", "estatal"))
  }

  motivo <- purrr::map_chr(claves, function(k) {
    if (!k %in% en_base) {
      return("sin filas comparables en la base (ningún año ni canal)")
    }
    tc <- todos[todos$clave_cnis %in% k, ]
    if (nrow(tc) == 0) return(paste0("sin filas en ", per))
    if (!any(leidas$clave_cnis %in% k)) {
      return(paste0("solo canal ", paste(sort(unique(tc$canal)), collapse = " y "),
                    " en ", per))
    }
    lados <- con_precio[con_precio$clave_cnis %in% k, ]
    falta <- setdiff(c("federal", "estatal"), lados$lado)
    if (length(falta) == 0) {
      return(paste0("precio federal y estatal en ", per,
                    ", nunca en el mismo año fiscal"))
    }
    texto <- if (length(falta) == 2) {
      paste0("sin precio federal ni estatal en ", per)
    } else {
      paste0("sin precio ", falta, " en ", per)
    }
    otros <- tc[!is.null(canales_lectura) & !tc$canal %in% canales_lectura &
                  tc$orden_gobierno %in% falta, ]
    if (nrow(otros) > 0) {
      plural <- c(federal = "federales", estatal = "estatales")
      texto <- paste0(texto, " (hay filas ",
                      paste(plural[sort(unique(otros$orden_gobierno))],
                            collapse = " y "),
                      " de canal ",
                      paste(sort(unique(otros$canal)), collapse = " y "), ")")
    }
    texto
  })
  tibble::tibble(clave_cnis = claves, motivo = motivo)
}

# One block of headline figures over the pairs given (each pair = state x key
# x year with the principal indicator on both sides, counted once).
# `n_claves` is the number of compared keys; quantiles use R's default (type 7).
cifras_pares <- function(pares, n_claves, n_universo, seccion, periodo) {
  num <- function(x) if (length(x) == 0 || all(is.na(x))) "sin pares" else
    formatC(x, format = "f", digits = 3)
  parte <- function(k, n) {
    if (n == 0) return("0 de 0")
    sprintf("%d de %d (%.1f %%)", k, n, 100 * k / n)
  }
  q <- function(x, p) if (length(x) == 0) NA_real_ else
    unname(stats::quantile(x, p))
  r <- pares$razon_estatal_federal
  r_fila <- stats::na.omit(pares$razon_estatal_federal_mediana)
  entidades <- sort(unique(pares$entidad_federativa))
  tibble::tibble(
    seccion = seccion,
    campo = c(
      "periodo", "claves_comparadas", "claves_no_comparadas",
      "pares_entidad_clave_año", "entidades_con_pares",
      "razon_estatal_federal_mediana_de_pares",
      "razon_estatal_federal_p25", "razon_estatal_federal_p75",
      "pares_razon_mayor_a_1", "pares_razon_mayor_a_2",
      "pares_razon_mayor_a_5", "pares_razon_mayor_a_10",
      "pares_con_una_fila_estatal",
      "razon_estatal_federal_por_fila_mediana_de_pares",
      "pares_con_ciclo_arrastrado"
    ),
    valor = c(
      periodo,
      sprintf("%d de %d", n_claves, n_universo),
      as.character(n_universo - n_claves),
      as.character(nrow(pares)),
      paste0(length(entidades), ": ", paste(entidades, collapse = ", ")),
      paste0(num(q(r, 0.5)), " (indicador principal, mediana ponderada por cantidad; ",
             length(r), " pares)"),
      num(q(r, 0.25)),
      num(q(r, 0.75)),
      parte(sum(r > 1), length(r)),
      parte(sum(r > 2), length(r)),
      parte(sum(r > 5), length(r)),
      parte(sum(r > 10), length(r)),
      # The state side of the pair rests on a single purchase row.
      parte(sum(pares$n_filas_estatal == 1), nrow(pares)),
      paste0(num(q(r_fila, 0.5)), " (sensibilidad, mediana por fila; ",
             length(r_fila), " pares)"),
      parte(sum(pares$federal_con_ciclo_arrastrado), nrow(pares))
    )
  )
}

# Headline summary for the LEEME sheet, rows seccion / campo / valor.
# `brecha` carries par_principal (marcar_pares_principal) and `comparadas` one
# row per key with comparada_principal. First the block over the whole
# headline period; when the period spans several fiscal years, the same block
# for each year alone (section "<seccion>: <año>"; a key is compared in a year
# when it has at least one pair that year); then each key not compared, with
# its reason.
resumen_principal <- function(base, universo, brecha, comparadas,
                              lectura = lectura_base, canal = NULL,
                              seccion = "Resumen lectura principal",
                              columna_precio = config$columna_precio) {
  pares <- dplyr::filter(brecha, par_principal)
  si <- comparadas$clave_cnis[comparadas$comparada_principal]
  no <- setdiff(universo$clave_cnis, si)
  motivos <- motivos_no_comparada(base, no, lectura = lectura, canal = canal,
                                  columna_precio = columna_precio) |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente),
                     by = "clave_cnis")
  canal_txt <- canal %||% (if (isTRUE(lectura$solo_ambulatorio))
    "ambulatorio" else "todos")
  total <- cifras_pares(
    pares, length(si), nrow(universo), seccion,
    paste0(lectura$periodo, " (año fiscal ", etiqueta_periodo(lectura$periodo),
           "); canal ", canal_txt)
  )
  años <- años_del_periodo(lectura$periodo)
  por_año <- if (length(años) > 1) {
    purrr::map(años, \(a) {
      p <- dplyr::filter(pares, año_fiscal == a)
      cifras_pares(p, dplyr::n_distinct(p$clave_cnis), nrow(universo),
                   paste0(seccion, ": ", a),
                   paste0("año fiscal ", a, "; canal ", canal_txt))
    }) |>
      purrr::list_rbind()
  }
  no_comparadas <- tibble::tibble(
    seccion = paste0(seccion, ": clave no comparada"),
    campo = motivos$clave_cnis,
    valor = paste0(motivos$componente, ": ", motivos$motivo)
  )
  dplyr::bind_rows(total, por_año, no_comparadas)
}

# The headline summary computed from a base alone (federal vs states, the
# headline filters, cycle rule and indicator). The LEEME sheet uses it for the
# headline without the channel override (reclasificar_canal = FALSE).
resumen_desde_base <- function(base, universo, lectura = lectura_base,
                               seccion = "Resumen lectura principal",
                               columna_precio = config$columna_precio) {
  claves <- universo$clave_cnis
  brecha <- filtrar_lectura(
    base, claves, lectura, columna_precio = columna_precio,
    arrastre_ciclo = lectura_principal$ciclo_bianual_segundo_año
  ) |>
    brecha_federal_estatal(columna_precio) |>
    marcar_pares_principal(lectura$periodo)
  comparadas <- calcular_lectura(base, claves, lectura, "federal_vs_estatal",
                                 columna_precio = columna_precio)$comparadas |>
    dplyr::mutate(comparada_principal = comparada_mismo_año)
  resumen_principal(base, universo, brecha, comparadas, lectura = lectura,
                    seccion = seccion, columna_precio = columna_precio)
}

# TRUE where the key is compared (same-year rule) in fiscal year `año`, read
# from años_comparados of a context claves_comparadas table.
comparada_en_año <- function(años_comparados, año) {
  purrr::map_lgl(strsplit(dplyr::coalesce(años_comparados, ""), ",\\s*"),
                 \(x) as.character(año) %in% x)
}

# LEEME rows of the channel override: which keys and how many rows moved, per
# key x orden_gobierno (table from filas_reclasificadas(), filtrar.R).
resumen_reclasificacion <- function(tabla, periodo = lectura_base$periodo) {
  tibble::tibble(
    seccion = "Reclasificación de canal",
    campo = paste(tabla$clave_cnis, tabla$orden_gobierno),
    valor = sprintf(
      "%s: %d filas comparables de canal %s leídas como ambulatorio (%d en %s); %d filas en total, comparables o no",
      tabla$componente, tabla$filas_comparables,
      dplyr::if_else(tabla$canal_base == "", "hospitalario", tabla$canal_base),
      tabla$filas_comparables_periodo_principal, etiqueta_periodo(periodo),
      tabla$filas
    )
  )
}

# Median headline ratio per axis (area of the universe: salud mental,
# diabetes) and per key, over the headline pairs of `brecha` (par_principal),
# each pair counted once. nivel = "eje" or "clave"; keys sorted by area, then
# by median ratio, highest first.
razon_por_eje_y_clave <- function(brecha, universo) {
  pares <- brecha |>
    dplyr::filter(par_principal) |>
    dplyr::select(clave_cnis, razon_estatal_federal) |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente, area),
                     by = "clave_cnis")
  resumir <- function(...) {
    dplyr::summarise(pares, pares = dplyr::n(),
                     razon_estatal_federal_mediana = stats::median(razon_estatal_federal),
                     .by = c(...))
  }
  ejes <- resumir(area) |>
    dplyr::mutate(nivel = "eje", clave_cnis = "", componente = "") |>
    dplyr::arrange(area)
  claves <- resumir(area, clave_cnis, componente) |>
    dplyr::mutate(nivel = "clave") |>
    dplyr::arrange(area, dplyr::desc(razon_estatal_federal_mediana), clave_cnis)
  dplyr::bind_rows(ejes, claves) |>
    dplyr::select(nivel, area, clave_cnis, componente, pares,
                  razon_estatal_federal_mediana)
}
