# Deflation to constant pesos of the base year (config$año_base_deflacion)
# with the general INPC. Annual INPC = mean of the months available for that
# calendar year; factor = INPC_base / INPC_año; real price = nominal x factor.
# Fiscal years without INPC (2027, or a missing año_fiscal) get NA, never the
# nominal price.

sufijo_real <- paste0("_real_", config$año_base_deflacion)

columna_real <- function(columna_precio) paste0(columna_precio, sufijo_real)

leer_inpc <- function(ruta) {
  if (!file.exists(ruta)) {
    stop("No existe la serie del INPC: ", ruta,
         ". Corre primero R/01_preparar_inpc.R.", call. = FALSE)
  }
  readr::read_csv(
    ruta,
    col_types = readr::cols(
      fecha = readr::col_date(), año = readr::col_integer(),
      mes = readr::col_integer(), inpc = readr::col_double()
    ),
    progress = FALSE
  )
}

inpc_anual <- function(inpc_mensual) {
  inpc_mensual |>
    dplyr::filter(!is.na(inpc)) |>
    dplyr::group_by(año) |>
    dplyr::summarise(
      inpc_anual = mean(inpc),
      inpc_meses = dplyr::n_distinct(mes),
      .groups = "drop"
    )
}

factores_deflacion <- function(inpc_mensual,
                               año_base = config$año_base_deflacion) {
  anual <- inpc_anual(inpc_mensual)
  base <- dplyr::filter(anual, año == año_base)
  if (nrow(base) != 1 || base$inpc_meses != 12) {
    stop("El año base ", año_base, " necesita los 12 meses del INPC.",
         call. = FALSE)
  }
  dplyr::mutate(anual, factor_deflacion = base$inpc_anual / inpc_anual)
}

# Adds factor_deflacion, inpc_meses and one real column per price column
# (suffix sufijo_real). With factores = NULL the rows are returned unchanged.
deflactar_precios <- function(datos, factores = NULL,
                              columnas_precio = c("precio_unitario_envase_mxn",
                                                  "precio_por_unidad_minima_mxn")) {
  if (is.null(factores)) {
    return(datos)
  }
  factores <- dplyr::select(factores, año_fiscal = año, factor_deflacion,
                            inpc_meses)
  datos <- dplyr::left_join(datos, factores, by = "año_fiscal")
  for (col in intersect(columnas_precio, names(datos))) {
    datos[[columna_real(col)]] <- datos[[col]] * datos$factor_deflacion
  }
  datos
}
