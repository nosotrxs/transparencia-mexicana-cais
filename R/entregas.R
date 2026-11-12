# Supply orders of the federal consolidated purchase (Secretaría de Salud,
# "Plataforma de monitoreo de medicamentos"): volume requested and delivered
# per key, crossed with the price side of the analysis. The platform has no
# prices. Source: ordenes_suministro.csv (one row per supply order); the
# supplier tab (cumplimiento_proveedores.csv) is only a cross-check.
#
# Conventions (micro-calls settled by dominant convention, see README):
# - estatus maps one-to-one to a category (categorias_estatus); an unknown
#   value stops the run, so the pivot never drops pieces silently.
# - Orders with canceladas_activas == "CANCELADA" are excluded from orders,
#   pieces, procedures and suppliers, and counted apart (canceladas_*).
# - pct_entregado = delivered / requested over active orders; NA (not 0) when
#   nothing was requested.
# - proveedor principal = the supplier with most delivered pieces of the
#   group (active orders); ties go to the first name in alphabetical order;
#   NA when nothing was delivered.

categorias_estatus <- c(
  "COMPLETA" = "completa",
  "INCOMPLETA" = "incompleta",
  "EN TRÁNSITO" = "en_transito",
  "INCUMPLIDA" = "incumplida",
  "VALIDACIÓN ENTREGA" = "en_validacion"
)
valor_cancelada <- "CANCELADA"

columnas_ordenes <- c(
  "clave", "institucion", "licitacion", "estatus", "fecha_solicitud",
  "piezas_solicitadas", "proveedor", "piezas_entregadas", "canceladas_activas"
)

# Reads the orders of the universe keys. NULL (with a message) when the file
# is absent: the analysis also runs on machines without the extraction.
leer_ordenes <- function(ruta, claves) {
  if (!file.exists(ruta)) {
    message("Entregas: no existe ", ruta, "; se omiten las tablas de entregas.")
    return(NULL)
  }
  tipos <- readr::cols(.default = readr::col_character(),
                       piezas_solicitadas = readr::col_double(),
                       piezas_entregadas = readr::col_double())
  ordenes <- readr::read_csv(ruta, col_select = dplyr::all_of(columnas_ordenes),
                             col_types = tipos, progress = FALSE,
                             locale = readr::locale(encoding = "UTF-8"))
  if (nrow(readr::problems(ordenes)) > 0) {
    print(readr::problems(ordenes))
    stop("Entregas: valores que no se pudieron leer en ", ruta, call. = FALSE)
  }
  preparar_ordenes(ordenes, claves)
}

# Keeps the universe keys, validates estatus and cancellation values and adds
# categoria, cancelada and año (year of fecha_solicitud).
preparar_ordenes <- function(ordenes, claves) {
  ordenes <- dplyr::filter(ordenes, clave %in% claves)
  desconocidos <- setdiff(unique(ordenes$estatus), names(categorias_estatus))
  if (length(desconocidos) > 0) {
    stop("Entregas: estatus sin categoría: ",
         paste(desconocidos, collapse = ", "), call. = FALSE)
  }
  cancel <- setdiff(unique(ordenes$canceladas_activas), c("ACTIVA", valor_cancelada))
  if (length(cancel) > 0) {
    stop("Entregas: valores inesperados en canceladas_activas: ",
         paste(cancel, collapse = ", "), call. = FALSE)
  }
  ordenes |>
    dplyr::mutate(
      categoria = unname(categorias_estatus[estatus]),
      cancelada = canceladas_activas == valor_cancelada,
      año = as.integer(substr(fecha_solicitud, 1, 4)),
      dplyr::across(c(piezas_solicitadas, piezas_entregadas),
                    \(x) dplyr::coalesce(x, 0))
    )
}

# Reads the supplier tab (cross-check only). NULL with a message if absent.
leer_cumplimiento <- function(ruta, claves) {
  if (!file.exists(ruta)) {
    message("Entregas: no existe ", ruta, "; se omite entregas_control.")
    return(NULL)
  }
  readr::read_csv(
    ruta, col_select = c(clave, solicitadas, entregadas),
    col_types = readr::cols(.default = readr::col_character(),
                            solicitadas = readr::col_double(),
                            entregadas = readr::col_double()),
    progress = FALSE, locale = readr::locale(encoding = "UTF-8")
  ) |>
    dplyr::filter(clave %in% claves)
}

# Volume columns per group (`por`, character vector of column names): active
# orders and pieces, delivered share, requested pieces by estatus category,
# cancelled orders apart, distinct procedures and suppliers, and the main
# supplier. Groups whose rows are all cancelled keep a row with zeros.
volumen_entregas <- function(ordenes, por) {
  activas <- dplyr::filter(ordenes, !cancelada)
  volumen <- ordenes |>
    # summarise() evaluates in order and later expressions see the summarised
    # column, so the cancelled sums come before piezas_* are overwritten.
    dplyr::summarise(
      canceladas_ordenes = sum(cancelada),
      canceladas_piezas_solicitadas = sum(piezas_solicitadas[cancelada]),
      canceladas_piezas_entregadas = sum(piezas_entregadas[cancelada]),
      ordenes = sum(!cancelada),
      piezas_solicitadas = sum(piezas_solicitadas[!cancelada]),
      piezas_entregadas = sum(piezas_entregadas[!cancelada]),
      procedimientos = dplyr::n_distinct(licitacion[!cancelada & !is.na(licitacion)]),
      proveedores = dplyr::n_distinct(proveedor[!cancelada & !is.na(proveedor)]),
      .by = dplyr::all_of(por)
    ) |>
    dplyr::relocate(dplyr::starts_with("canceladas_"), .after = proveedores) |>
    dplyr::mutate(pct_entregado = porcentaje(piezas_entregadas, piezas_solicitadas),
                  .after = piezas_entregadas)
  volumen |>
    dplyr::left_join(pivote_estatus(activas, por), by = por) |>
    dplyr::left_join(proveedor_principal(activas, por), by = por) |>
    dplyr::mutate(dplyr::across(dplyr::starts_with("piezas_solicitadas_"),
                                \(x) dplyr::coalesce(x, 0))) |>
    dplyr::relocate(dplyr::starts_with("piezas_solicitadas_"),
                    .after = pct_entregado)
}

# Share rounded to 4 decimals; NA when the denominator is zero.
porcentaje <- function(x, total) {
  dplyr::if_else(total > 0, round(x / total, 4), NA_real_)
}

# Requested pieces of active orders by estatus category, one column per
# category (piezas_solicitadas_<categoria>), all five always present. They add
# up to piezas_solicitadas.
pivote_estatus <- function(activas, por) {
  columnas <- paste0("piezas_solicitadas_", unname(categorias_estatus))
  ancho <- activas |>
    dplyr::summarise(piezas = sum(piezas_solicitadas),
                     .by = dplyr::all_of(c(por, "categoria"))) |>
    dplyr::mutate(categoria = paste0("piezas_solicitadas_", categoria)) |>
    tidyr::pivot_wider(names_from = categoria, values_from = piezas,
                       values_fill = 0)
  for (columna in setdiff(columnas, names(ancho))) ancho[[columna]] <- 0
  dplyr::select(ancho, dplyr::all_of(c(por, columnas)))
}

# Supplier with most delivered pieces per group and its share of the group's
# delivered pieces. Tie-break: alphabetical order of the supplier name. NA when
# the group delivered nothing.
proveedor_principal <- function(activas, por) {
  activas |>
    dplyr::summarise(entregadas = sum(piezas_entregadas),
                     .by = dplyr::all_of(c(por, "proveedor"))) |>
    dplyr::mutate(total = sum(entregadas), .by = dplyr::all_of(por)) |>
    dplyr::arrange(dplyr::desc(entregadas), proveedor) |>
    dplyr::slice_head(n = 1, by = dplyr::all_of(por)) |>
    dplyr::transmute(
      dplyr::across(dplyr::all_of(por)),
      proveedor_principal = dplyr::if_else(total > 0, proveedor, NA_character_),
      proveedor_principal_parte = porcentaje(entregadas, total)
    )
}

# One row per universe key (all of them): axis, volume columns, en_plataforma
# (the key has at least one order, active or cancelled) and the price side of
# the analysis: headline pairs and median ratio (razon_por_eje_y_clave),
# comparada_principal (claves_comparadas, principal comparison) and state
# spending and overcost (sobrecosto_estatal, nivel clave).
entregas_por_clave <- function(ordenes, universo, razon, sobrecosto, comparadas) {
  volumen <- volumen_entregas(dplyr::rename(ordenes, clave_cnis = clave),
                              "clave_cnis")
  precio_razon <- razon |>
    dplyr::filter(nivel == "clave") |>
    dplyr::select(clave_cnis, pares, razon_estatal_federal_mediana)
  precio_comparada <- comparadas |>
    dplyr::filter(comparacion_principal) |>
    dplyr::select(clave_cnis, comparada_principal)
  precio_sobrecosto <- sobrecosto |>
    dplyr::filter(nivel == "clave") |>
    dplyr::select(clave_cnis = nombre, gasto_estatal_comparado_mxn,
                  sobrecosto_mxn, sobrecosto_parte_del_gasto = parte_del_gasto)
  universo |>
    dplyr::transmute(eje = area, clave_cnis, componente) |>
    dplyr::left_join(volumen, by = "clave_cnis") |>
    dplyr::mutate(
      en_plataforma = !is.na(ordenes),
      dplyr::across(c(ordenes, piezas_solicitadas, piezas_entregadas,
                      dplyr::starts_with("piezas_solicitadas_"),
                      dplyr::starts_with("canceladas_"),
                      procedimientos, proveedores),
                    \(x) dplyr::coalesce(x, 0)),
      .after = componente
    ) |>
    dplyr::left_join(precio_razon, by = "clave_cnis") |>
    dplyr::left_join(precio_comparada, by = "clave_cnis") |>
    dplyr::left_join(precio_sobrecosto, by = "clave_cnis") |>
    # Keys absent from claves_comparadas (no rows in the comparison) are not
    # compared.
    dplyr::mutate(pares = dplyr::coalesce(pares, 0L),
                  comparada_principal = dplyr::coalesce(comparada_principal, FALSE)) |>
    dplyr::arrange(eje, clave_cnis)
}

# Volume per key x institution, or per key x year of fecha_solicitud. Only the
# combinations present on the platform.
entregas_por_clave_y <- function(ordenes, universo, columna) {
  ordenes |>
    dplyr::rename(clave_cnis = clave) |>
    volumen_entregas(c("clave_cnis", columna)) |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente),
                     by = "clave_cnis") |>
    dplyr::relocate(componente, .after = clave_cnis) |>
    dplyr::arrange(clave_cnis, .data[[columna]])
}

# Per key (all universe keys): active orders and pieces whose licitacion is
# also an id_procedimiento of the price base (any row of the base, trimmed and
# upper-cased on both sides), as counts and shares.
entregas_cruce_procedimientos <- function(ordenes, base, universo) {
  normalizar <- function(x) toupper(stringr::str_trim(x))
  ids <- unique(normalizar(stats::na.omit(base$id_procedimiento)))
  ids <- ids[ids != ""]
  cruce <- ordenes |>
    dplyr::filter(!cancelada) |>
    dplyr::mutate(con_precio = normalizar(licitacion) %in% ids) |>
    # Matched sums first: summarise() overwrites piezas_* as it goes.
    dplyr::summarise(
      ordenes_con_procedimiento_en_base = sum(con_precio),
      piezas_solicitadas_con_procedimiento_en_base = sum(piezas_solicitadas[con_precio]),
      piezas_entregadas_con_procedimiento_en_base = sum(piezas_entregadas[con_precio]),
      procedimientos_en_base = dplyr::n_distinct(licitacion[con_precio]),
      ordenes = dplyr::n(),
      piezas_solicitadas = sum(piezas_solicitadas),
      piezas_entregadas = sum(piezas_entregadas),
      procedimientos = dplyr::n_distinct(licitacion),
      .by = clave
    ) |>
    dplyr::select(clave, ordenes, ordenes_con_procedimiento_en_base,
                  piezas_solicitadas, piezas_solicitadas_con_procedimiento_en_base,
                  piezas_entregadas, piezas_entregadas_con_procedimiento_en_base,
                  procedimientos, procedimientos_en_base) |>
    dplyr::rename(clave_cnis = clave)
  universo |>
    dplyr::select(eje = area, clave_cnis, componente) |>
    dplyr::left_join(cruce, by = "clave_cnis") |>
    dplyr::mutate(dplyr::across(-c(eje, clave_cnis, componente),
                                \(x) dplyr::coalesce(x, 0))) |>
    dplyr::mutate(
      parte_ordenes = porcentaje(ordenes_con_procedimiento_en_base, ordenes),
      parte_piezas_solicitadas = porcentaje(
        piezas_solicitadas_con_procedimiento_en_base, piezas_solicitadas),
      parte_piezas_entregadas = porcentaje(
        piezas_entregadas_con_procedimiento_en_base, piezas_entregadas)
    ) |>
    dplyr::arrange(eje, clave_cnis)
}

# Cross-check per universe key: totals of ordenes_suministro.csv (every row,
# cancelled included, because the supplier tab has no cancellation flag)
# against cumplimiento_proveedores.csv.
entregas_control <- function(ordenes, cumplimiento, universo) {
  o <- ordenes |>
    dplyr::summarise(filas_ordenes = dplyr::n(),
                     solicitadas_ordenes = sum(piezas_solicitadas),
                     entregadas_ordenes = sum(piezas_entregadas), .by = clave)
  cu <- cumplimiento |>
    dplyr::summarise(filas_cumplimiento = dplyr::n(),
                     solicitadas_cumplimiento = sum(solicitadas, na.rm = TRUE),
                     entregadas_cumplimiento = sum(entregadas, na.rm = TRUE),
                     .by = clave)
  universo |>
    dplyr::select(clave_cnis, componente) |>
    dplyr::left_join(dplyr::rename(o, clave_cnis = clave), by = "clave_cnis") |>
    dplyr::left_join(dplyr::rename(cu, clave_cnis = clave), by = "clave_cnis") |>
    dplyr::mutate(dplyr::across(-c(clave_cnis, componente),
                                \(x) dplyr::coalesce(x, 0))) |>
    dplyr::mutate(
      diferencia_filas = filas_cumplimiento - filas_ordenes,
      diferencia_solicitadas = solicitadas_cumplimiento - solicitadas_ordenes,
      diferencia_entregadas = entregadas_cumplimiento - entregadas_ordenes
    ) |>
    dplyr::select(clave_cnis, componente, filas_ordenes, filas_cumplimiento,
                  diferencia_filas, solicitadas_ordenes, solicitadas_cumplimiento,
                  diferencia_solicitadas, entregadas_ordenes,
                  entregadas_cumplimiento, diferencia_entregadas) |>
    dplyr::arrange(clave_cnis)
}

# Every delivery table, or an empty list (with a message) when the orders file
# is missing. entregas_control is left out when only the supplier tab is.
calcular_entregas <- function(ruta_ordenes, ruta_cumplimiento, universo, base,
                              razon, sobrecosto, comparadas) {
  claves <- universo$clave_cnis
  ordenes <- leer_ordenes(ruta_ordenes, claves)
  if (is.null(ordenes)) return(list())
  tablas <- list(
    entregas_por_clave = entregas_por_clave(ordenes, universo, razon,
                                            sobrecosto, comparadas),
    entregas_por_clave_institucion = entregas_por_clave_y(ordenes, universo,
                                                          "institucion"),
    entregas_por_clave_año = entregas_por_clave_y(ordenes, universo, "año"),
    entregas_cruce_procedimientos = entregas_cruce_procedimientos(ordenes, base,
                                                                  universo)
  )
  cumplimiento <- leer_cumplimiento(ruta_cumplimiento, claves)
  if (!is.null(cumplimiento)) {
    tablas$entregas_control <- entregas_control(ordenes, cumplimiento, universo)
  }
  tablas
}

# LEEME rows: source, treatment of cancelled orders and the headline totals
# over the universe keys. One line saying the step was skipped if `tablas`
# has no delivery table.
resumen_entregas <- function(tablas, ruta_ordenes, seccion = "Entregas (plataforma SSA)") {
  t <- tablas$entregas_por_clave
  if (is.null(t)) {
    return(tibble::tibble(seccion = seccion, campo = "estado",
                          valor = paste("Omitido: no existe", ruta_ordenes)))
  }
  fmt <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
  pct <- function(x) sprintf("%.1f %%", 100 * x)
  sol <- sum(t$piezas_solicitadas)
  ent <- sum(t$piezas_entregadas)
  cruce <- tablas$entregas_cruce_procedimientos
  control <- tablas$entregas_control
  tibble::tibble(
    seccion = seccion,
    campo = c("fuente", "canceladas", "claves_en_plataforma", "ordenes_activas",
              "piezas", "canceladas_totales", "procedimiento_en_base",
              if (!is.null(control)) "control"),
    valor = c(
      paste0(ruta_ordenes, " (Plataforma de monitoreo de medicamentos de la Secretaría de Salud, compra consolidada federal; sin precios)"),
      "Las órdenes con canceladas_activas = CANCELADA no entran en órdenes, piezas, procedimientos ni proveedores; se cuentan aparte en las columnas canceladas_*.",
      sprintf("%d de %d", sum(t$en_plataforma), nrow(t)),
      fmt(sum(t$ordenes)),
      sprintf("%s entregadas de %s solicitadas (%s)", fmt(ent), fmt(sol), pct(ent / sol)),
      sprintf("%s órdenes; %s piezas solicitadas, %s entregadas",
              fmt(sum(t$canceladas_ordenes)),
              fmt(sum(t$canceladas_piezas_solicitadas)),
              fmt(sum(t$canceladas_piezas_entregadas))),
      sprintf("%s de %s piezas entregadas (%s) en órdenes cuyo procedimiento está en la base de precios",
              fmt(sum(cruce$piezas_entregadas_con_procedimiento_en_base)),
              fmt(sum(cruce$piezas_entregadas)),
              pct(sum(cruce$piezas_entregadas_con_procedimiento_en_base) /
                    sum(cruce$piezas_entregadas))),
      if (!is.null(control)) {
        sprintf("cumplimiento_proveedores.csv menos ordenes_suministro.csv (todas las filas): %s filas, %s piezas solicitadas, %s entregadas; claves con alguna diferencia: %d",
                fmt(sum(control$diferencia_filas)),
                fmt(sum(control$diferencia_solicitadas)),
                fmt(sum(control$diferencia_entregadas)),
                sum(control$diferencia_filas != 0 |
                      control$diferencia_solicitadas != 0 |
                      control$diferencia_entregadas != 0))
      }
    )
  )
}
