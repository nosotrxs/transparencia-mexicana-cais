# Loading and validation of the price base and the 43-key universe.

columnas_base <- c(
  "id_registro", "fuente", "id_contrato_fuente", "id_procedimiento",
  "duplicado_de", "url_documento", "orden_gobierno", "entidad_federativa",
  "institucion_compradora", "tipo_institucion", "proveedor", "rfc_proveedor",
  "clave_cnis", "componente", "area", "presentacion", "unidades_por_envase",
  "unidad_minima", "canal", "descripcion_original", "cantidad_envases",
  "cantidad_maxima_envases", "cantidad_unidades_minimas",
  "precio_unitario_envase_mxn", "precio_por_unidad_minima_mxn",
  "monto_partida_mxn", "iva", "tipo_compra", "mecanismo_procedimiento",
  "año_fiscal", "fecha_documento", "comparable", "notas_metodologicas",
  "fecha_carga"
)

columnas_numericas <- c(
  "unidades_por_envase", "cantidad_envases", "cantidad_maxima_envases",
  "cantidad_unidades_minimas", "precio_unitario_envase_mxn",
  "precio_por_unidad_minima_mxn", "monto_partida_mxn"
)

# Explicit types: keys and identifiers stay character so leading zeros survive;
# dates stay character because fecha_documento is empty in most rows and is
# only used as an equality field.
tipos_base <- function() {
  tipos <- rlang::set_names(
    rep(list(readr::col_character()), length(columnas_base)),
    columnas_base
  )
  tipos[columnas_numericas] <- list(readr::col_double())
  tipos[["año_fiscal"]] <- readr::col_integer()
  tipos[["comparable"]] <- readr::col_logical()
  do.call(readr::cols_only, tipos)
}

leer_base <- function(ruta) {
  if (!file.exists(ruta)) {
    stop("No existe la base de precios: ", ruta,
         ". Define TM_PRECIOS_DATA con la carpeta que la contiene.", call. = FALSE)
  }
  encabezado <- names(readr::read_csv(ruta, n_max = 0, show_col_types = FALSE))
  faltan <- setdiff(columnas_base, encabezado)
  if (length(faltan) > 0) {
    stop("Faltan columnas en la base: ", paste(faltan, collapse = ", "),
         call. = FALSE)
  }
  base <- readr::read_csv(
    ruta,
    col_types = tipos_base(),
    locale = readr::locale(encoding = "UTF-8"),
    progress = FALSE
  )
  problemas <- readr::problems(base)
  if (nrow(problemas) > 0) {
    print(problemas)
    stop(nrow(problemas), " valores no se pudieron leer con el tipo esperado.",
         call. = FALSE)
  }
  base
}

leer_universo <- function(ruta) {
  universo <- readr::read_csv(
    ruta,
    col_types = readr::cols(.default = readr::col_character()),
    progress = FALSE
  ) |>
    dplyr::transmute(
      clave_cnis = key,
      componente = component_name,
      area
    )
  if (anyDuplicated(universo$clave_cnis) > 0) {
    stop("El universo tiene claves repetidas.", call. = FALSE)
  }
  universo
}

# Structural rules from the dictionary ("Regla de comparable"). They hold for
# any version of the base.
validar_base <- function(base) {
  errores <- character()
  if (anyNA(base$comparable)) {
    errores <- c(errores, "hay filas con comparable vacío")
  }
  comparables <- dplyr::filter(base, comparable %in% TRUE)
  obligatorias <- c(
    "clave_cnis", "cantidad_envases", "precio_unitario_envase_mxn",
    "monto_partida_mxn", "año_fiscal"
  )
  for (col in obligatorias) {
    n_vacias <- sum(is.na(comparables[[col]]))
    if (n_vacias > 0) {
      errores <- c(errores, paste0(n_vacias, " filas comparables sin ", col))
    }
  }
  formato <- "^\\d{3}\\.\\d{3}\\.\\d{4}\\.\\d{2}$"
  n_mal <- sum(!stringr::str_detect(comparables$clave_cnis, formato))
  if (n_mal > 0) {
    errores <- c(errores, paste0(n_mal, " claves comparables con formato inválido"))
  }
  if (length(errores) > 0) {
    stop("La base no pasa la validación: ", paste(errores, collapse = "; "),
         call. = FALSE)
  }
  invisible(base)
}

# Measures the anchors on the base and stops if one does not match.
medir_anclas <- function(base, universo, etiquetas_almacen) {
  comp <- dplyr::filter(base, comparable %in% TRUE)
  comp_univ <- dplyr::filter(comp, clave_cnis %in% universo$clave_cnis)
  claves_presentes <- unique(comp_univ$clave_cnis)

  ii <- comp_univ |>
    dplyr::filter(tipo_institucion %in% c("IMSS", "ISSSTE")) |>
    dplyr::distinct(clave_cnis, tipo_institucion, año_fiscal)
  ambas <- function(x) {
    x |>
      dplyr::distinct(clave_cnis, tipo_institucion) |>
      dplyr::count(clave_cnis) |>
      dplyr::filter(n == 2) |>
      nrow()
  }

  list(
    filas = nrow(base),
    filas_comparables = nrow(comp),
    claves_con_precio = length(claves_presentes),
    claves_sin_precio = paste(
      sort(setdiff(universo$clave_cnis, claves_presentes)), collapse = ", "
    ),
    claves_imss_issste = ambas(ii),
    claves_imss_issste_2025 = ambas(dplyr::filter(ii, año_fiscal == 2025L)),
    entidades_estatales = comp |>
      dplyr::filter(orden_gobierno == "estatal") |>
      dplyr::distinct(entidad_federativa) |>
      nrow(),
    filas_entrada_almacen = sum(
      tiene_etiqueta(comp$notas_metodologicas, etiquetas_almacen)
    )
  )
}

validar_anclas <- function(base, universo, anclas, etiquetas_almacen) {
  medidas <- medir_anclas(base, universo, etiquetas_almacen)
  revision <- tibble::tibble(
    ancla = names(anclas),
    esperado = vapply(anclas, as.character, character(1)),
    medido = vapply(medidas[names(anclas)], as.character, character(1))
  ) |>
    dplyr::mutate(coincide = esperado == medido)
  if (!all(revision$coincide)) {
    print(revision)
    stop("La base no reproduce las anclas de config.R. Revisa la tabla de arriba ",
         "antes de seguir; no ajustes las definiciones para que cuadren.",
         call. = FALSE)
  }
  revision
}

sha256_archivo <- function(ruta) {
  unname(tools::sha256sum(ruta))
}
