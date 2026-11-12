# State context for the report: the headline federal-vs-state ratio per state
# crossed with CONAPO's 2020 marginalisation index and the share of people
# who speak an indigenous language (INEGI, 2020 census), and the coverage of
# state prices across the 32 states. Inputs are read-only files in datos/.

# CONAPO 2020 marginalisation by state (32 rows): cve_ent (two-digit text),
# entidad, im, imn, grado_marginacion.
leer_marginacion <- function(ruta = config$ruta_marginacion) {
  if (!file.exists(ruta)) {
    stop("No existe el archivo de marginación: ", ruta, call. = FALSE)
  }
  datos <- readr::read_csv(ruta, show_col_types = FALSE,
                           locale = readr::locale(encoding = "UTF-8"))
  faltan <- setdiff(c("cve_ent", "entidad", "im", "imn", "grado_marginacion"),
                    names(datos))
  if (length(faltan) > 0) {
    stop("Faltan columnas en marginación: ", paste(faltan, collapse = ", "),
         call. = FALSE)
  }
  datos <- dplyr::transmute(
    datos, cve_ent = sprintf("%02d", as.integer(cve_ent)), entidad,
    im = as.numeric(im), imn = as.numeric(imn), grado_marginacion
  )
  if (nrow(datos) != 32 || anyDuplicated(datos$cve_ent) > 0) {
    stop("El archivo de marginación debe tener las 32 entidades una vez.",
         call. = FALSE)
  }
  datos
}

# INEGI census 2020, tabulation 05 (etnicidad), sheet "02": per state, the
# population aged 3 and over and the people who speak an indigenous language,
# rows with Sexo = Total and age group = Total. State names carry a two-digit
# prefix ("01 Aguascalientes"); the prefix is the state code. The columns are
# found by their header text, not by position.
leer_lengua_indigena <- function(ruta = config$ruta_lengua_indigena, hoja = "02") {
  if (!file.exists(ruta)) {
    stop("No existe el tabulado del censo: ", ruta, call. = FALSE)
  }
  crudo <- readxl::read_excel(ruta, sheet = hoja, col_names = FALSE,
                              col_types = "text", .name_repair = "minimal")
  names(crudo) <- paste0("c", seq_along(crudo))
  encabezado <- utils::head(crudo, 10)
  columna_con <- function(texto) {
    hay <- purrr::map_lgl(encabezado, \(x) any(x %in% texto))
    if (sum(hay) != 1) {
      stop("No se encuentra una sola columna «", texto, "» en el tabulado.",
           call. = FALSE)
    }
    names(crudo)[hay]
  }
  pob <- columna_con("Población de 3 años y más")
  hli <- columna_con("Habla lengua indígena")
  datos <- crudo |>
    dplyr::filter(stringr::str_detect(c1, "^\\d{2} "), c2 %in% "Total",
                  c3 %in% "Total") |>
    dplyr::transmute(
      cve_ent = stringr::str_sub(c1, 1, 2),
      pob_3ymas = as.numeric(.data[[pob]]),
      hablantes_lengua_indigena = as.numeric(.data[[hli]])
    )
  if (nrow(datos) != 32 || anyDuplicated(datos$cve_ent) > 0) {
    stop("El tabulado del censo debe dar las 32 entidades una vez.", call. = FALSE)
  }
  datos
}

# One row per state with headline pairs (par_principal in `brecha`): pairs,
# keys, median ratio, CONAPO 2020 index (im), normalised index (imn) and
# grade, population aged 3+, speakers of an indigenous language and their
# share. States join by name to CONAPO and by code to INEGI.
cruce_marginacion <- function(brecha, marginacion, lengua) {
  por_entidad <- brecha |>
    dplyr::filter(par_principal) |>
    dplyr::summarise(pares = dplyr::n(), claves = dplyr::n_distinct(clave_cnis),
                     brecha_mediana = stats::median(razon_estatal_federal),
                     .by = entidad_federativa) |>
    dplyr::rename(entidad = entidad_federativa)
  faltan <- setdiff(por_entidad$entidad, marginacion$entidad)
  if (length(faltan) > 0) {
    stop("Entidades sin marginación: ", paste(faltan, collapse = ", "),
         call. = FALSE)
  }
  por_entidad |>
    dplyr::left_join(marginacion, by = "entidad") |>
    dplyr::left_join(lengua, by = "cve_ent") |>
    dplyr::transmute(
      entidad, pares, claves,
      brecha_mediana = round(brecha_mediana, 4),
      indice_marginacion_2020 = round(im, 3),
      imn_2020 = round(imn, 4),
      grado_marginacion_2020 = grado_marginacion,
      pob_3ymas, hablantes_lengua_indigena,
      pct_hli = round(100 * hablantes_lengua_indigena / pob_3ymas, 2)
    ) |>
    dplyr::arrange(entidad)
}

niveles_cobertura <- c("Con pares", "Con filas comparables, sin par",
                       "Con filas, ninguna comparable", "Sin filas")
niveles_grado <- c("Muy bajo", "Bajo", "Medio", "Alto", "Muy alto")

# The 32 states with their marginalisation grade and price coverage, first
# category that applies: headline pairs; comparable rows (cobertura_entidad,
# context series) but no pair; state rows in the base, none comparable; no
# state row at all. `base` is the whole base (any row, comparable or not).
cobertura_marginacion <- function(base, cobertura_entidad, cruce, marginacion) {
  filas_total <- base |>
    dplyr::filter(orden_gobierno %in% "estatal") |>
    dplyr::count(entidad = entidad_federativa, name = "filas_total")
  comparables <- cobertura_entidad |>
    dplyr::select(-dplyr::any_of(c("clave_cnis", "componente", "area", "total",
                                   "Federal"))) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), sum)) |>
    tidyr::pivot_longer(dplyr::everything(), names_to = "entidad",
                        values_to = "filas_comparables")
  fuera <- setdiff(c(filas_total$entidad, comparables$entidad, cruce$entidad),
                   marginacion$entidad)
  if (length(fuera) > 0) {
    stop("Entidades que no están en marginación: ", paste(fuera, collapse = ", "),
         call. = FALSE)
  }
  marginacion |>
    dplyr::select(cve_ent, entidad, grado_marginacion_2020 = grado_marginacion) |>
    dplyr::left_join(filas_total, by = "entidad") |>
    dplyr::left_join(comparables, by = "entidad") |>
    dplyr::left_join(dplyr::select(cruce, entidad, pares), by = "entidad") |>
    dplyr::mutate(
      dplyr::across(c(filas_total, filas_comparables, pares),
                    \(x) as.integer(dplyr::coalesce(x, 0))),
      cobertura = dplyr::case_when(
        pares > 0 ~ niveles_cobertura[1],
        filas_comparables > 0 ~ niveles_cobertura[2],
        filas_total > 0 ~ niveles_cobertura[3],
        TRUE ~ niveles_cobertura[4]
      )
    ) |>
    dplyr::arrange(factor(cobertura, levels = niveles_cobertura),
                   dplyr::desc(factor(grado_marginacion_2020, levels = niveles_grado)),
                   entidad)
}
