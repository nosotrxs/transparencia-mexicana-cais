# Runs the whole price analysis and writes every table.
# Input:  base_precios.csv and claves_eje_salud_mental_diabetes_40.csv from the
#         tm-precios-salud repo (folder set in R/config.R, overridable with the
#         environment variable TM_PRECIOS_DATA). Read-only.
#         datos/inpc_general_mensual.csv, written once by R/01_preparar_inpc.R.
#         OCAMIS prescriptions (config$ruta_ocamis, sheet "datos"). Read-only.
#         SSA supply orders (config$ruta_entregas, optional). Read-only.
# Output: salidas/<tabla>.csv (UTF-8) and salidas/analisis_precios.xlsx
#         (one sheet per table plus LEEME).
#
# Metric: quantity-weighted median of the unit price per clave x grupo x
#   año_fiscal (principal indicator, lectura_principal$indicador in
#   R/config.R; the per-row median stays as sensitivity), in nominal pesos and
#   in 2025 pesos (general INPC), computed on comparable ambulatory-channel
#   rows of the 43-key universe. Principal reading: federal vs states, same
#   fiscal year, pooled federal group required, a biannual-cycle federal price
#   also read in the cycle's second year. Headline = fiscal years 2024 and
#   2025, each pair within its own year (lectura_base); the tables by year
#   carry the context series 2019-2026 (lectura_contexto) and mark the
#   headline rows. The insulin keys count as ambulatory channel
#   (config$claves_canal_ambulatorio). Hospital-channel rows go to the
#   anexo_canal_hospitalario tables. OCAMIS prescriptions measure how much of
#   what IMSS and ISSSTE prescribe the reading captures. The other definitions are parameters;
#   sensibilidad runs every combination, including with and without menudeo,
#   and medianas_sin_menudeo gives the prices without retail-pharmacy rows.
#
# Run from the "Analisis precios" folder:  Rscript R/00_correr_todo.R

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(stringr)
})

if (!file.exists("R/config.R")) {
  stop("Corre este script desde la carpeta 'Analisis precios'.", call. = FALSE)
}
for (archivo in c("config.R", "cargar.R", "filtrar.R", "deflactar.R",
                  "indicadores.R", "tablas.R", "anexos.R", "principal.R",
                  "ocamis.R", "sobrecosto.R", "marginacion.R",
                  "entregas.R", "exportar.R")) {
  source(file.path("R", archivo), encoding = "UTF-8")
}

# Load and validate --------------------------------------------------------

base <- leer_base(config$ruta_base)
universo <- leer_universo(config$ruta_universo)
validar_base(base)
anclas <- validar_anclas(base, universo, config$anclas,
                         config$etiquetas_entrada_almacen)
message("Anclas: ", sum(anclas$coincide), " de ", nrow(anclas), " coinciden.")

# Channel override (config$claves_canal_ambulatorio), applied here once, on the
# copy in memory, before any channel filter. base_original keeps the base's
# own channel for the LEEME sensitivity without the override.
base_original <- base
if (isTRUE(lectura_principal$reclasificar_canal)) {
  base <- reclasificar_canal(base_original)
}

claves <- universo$clave_cnis
precio <- config$columna_precio
factores <- factores_deflacion(leer_inpc(config$ruta_inpc))

# Medians and compared keys for the five comparisons: context series
# (lectura_contexto, 2019-2026) plus the headline status (lectura_base, 2025)
# ---------------------------------------------------------------------------

filtros <- lectura_principal$filtros
contexto <- lectura_contexto
por_lectura <- function(lectura) {
  map(
    set_names(comparaciones_validas),
    \(comp) calcular_lectura(base, claves, lectura, comp,
                             columna_precio = precio, factores = factores)
  )
}
por_comparacion <- por_lectura(contexto)
comparadas_principal <- map(por_lectura(filtros), "comparadas") |>
  list_rbind(names_to = "comparacion")
medianas <- map(por_comparacion, "medianas") |>
  list_rbind(names_to = "comparacion") |>
  con_componente(universo)
comparadas <- map(por_comparacion, "comparadas") |>
  list_rbind(names_to = "comparacion") |>
  con_comparada_principal(comparadas_principal,
                          por = c("comparacion", "clave_cnis")) |>
  mutate(
    grupo_requerido = map_chr(comparacion, \(x) grupo_requerido_para(x) %||% ""),
    comparacion_principal = comparacion == lectura_principal$comparacion,
    .after = comparacion
  ) |>
  con_componente(universo)

# One row per award: every table except the federal-vs-state gap.
filas_base <- filtrar_lectura(base, claves, contexto, columna_precio = precio) |>
  deflactar_precios(factores)
# Federal-vs-state gap: adds the second-year copies of the biannual-cycle
# prices to the federal reference (config: ciclo_bianual_segundo_año).
filas_brecha <- filtrar_lectura(
  base, claves, contexto, columna_precio = precio,
  arrastre_ciclo = lectura_principal$ciclo_bianual_segundo_año
) |>
  deflactar_precios(factores)
dispersion <- dispersion_por_clave(filas_base, precio)
cob <- cobertura(filas_base, universo)
anexo <- anexo_canal(base, claves, lectura = contexto, columna_precio = precio,
                     factores = factores)

tablas <- list(
  medianas = medianas,
  medianas_sin_menudeo = medianas_sin_menudeo(
    base, claves, medianas, lectura = contexto, columna_precio = precio,
    factores = factores
  ),
  claves_comparadas = comparadas,
  sensibilidad = tabla_sensibilidad(base, claves, columna_precio = precio),
  brecha_imss_issste = brecha_imss_issste(filas_base, precio) |>
    con_componente(universo),
  brecha_federal_estatal = brecha_federal_estatal(filas_brecha, precio) |>
    marcar_pares_principal(filtros$periodo) |>
    con_componente(universo),
  dispersion_por_clave = con_componente(dispersion$por_clave, universo),
  dispersion_por_clave_año = con_componente(dispersion$por_clave_año, universo),
  serie_real_por_clave = serie_real_por_clave(filas_base, precio) |>
    con_componente(universo),
  cobertura_tipo_institucion = cob$tipo_institucion,
  cobertura_entidad = cob$entidad,
  anexo_canal_hospitalario = con_componente(anexo$brecha, universo),
  anexo_canal_hospitalario_claves = con_componente(anexo$claves, universo)
)
if (isTRUE(lectura_principal$reclasificar_canal)) {
  tablas$reclasificacion_canal <- filas_reclasificadas(base)
}

# Quality comparator: OCAMIS prescriptions of IMSS and ISSSTE ----------------

prescripcion <- prescripcion_anual(leer_ocamis(config$ruta_ocamis), claves)
comparadas_titular <- filter(comparadas, comparacion_principal)
compra_ciclo <- compra_ciclo_vs_prescripcion(base, universo, prescripcion)
tablas$cobertura_prescripcion <- cobertura_prescripcion(
  prescripcion, universo, comparadas_titular,
  motivos_no_comparada(base, claves, lectura = filtros, columna_precio = precio),
  años_principal = años_del_periodo(filtros$periodo)
)
tablas$compra_vs_prescripcion <- compra_vs_prescripcion(base, claves, prescripcion)
tablas$compra_vs_prescripcion_clave <-
  compra_vs_prescripcion_clave(base, claves, prescripcion) |>
  con_componente(universo)
tablas$compra_2025_vs_presc_2023 <- compra_ciclo$por_clave

# Report tables on the headline pairs and rows -------------------------------

# Median ratio per axis and per key (headline pairs).
tablas$razon_por_eje_y_clave <- razon_por_eje_y_clave(
  tablas$brecha_federal_estatal, universo
)
# State overcost against the federal reference: headline rows (fiscal
# 2024-2025) with the biannual-cycle copies, as brecha_federal_estatal reads them.
filas_titulares <- filtrar_lectura(
  base, claves, filtros, columna_precio = precio,
  arrastre_ciclo = lectura_principal$ciclo_bianual_segundo_año
)
tablas$sobrecosto_estatal <- tabla_sobrecosto_estatal(
  sobrecosto_estatal_filas(filas_titulares, precio), universo
)
variantes_sobrecosto <- sobrecosto_variantes(filas_titulares, precio)
# State context: marginalisation and indigenous language (cruce), and the
# coverage of the 32 states (figure 6).
marginacion <- leer_marginacion(config$ruta_marginacion)
tablas$cruce_marginacion_entidad <- cruce_marginacion(
  tablas$brecha_federal_estatal, marginacion,
  leer_lengua_indigena(config$ruta_lengua_indigena)
)
tablas$cobertura_marginacion_entidad <- cobertura_marginacion(
  base, tablas$cobertura_entidad, tablas$cruce_marginacion_entidad, marginacion
)

# Supply orders of the federal consolidated purchase (SSA platform): volume
# requested and delivered per key, crossed with the price-side tables above
# (in-memory objects). Skipped with a message when the file is absent.
tablas <- c(tablas, calcular_entregas(
  config$ruta_entregas, config$ruta_cumplimiento_proveedores, universo, base,
  razon = tablas$razon_por_eje_y_clave, sobrecosto = tablas$sobrecosto_estatal,
  comparadas = comparadas_titular
))

# Headline summary (fiscal 2024-2025, and each year) for LEEME: principal
# reading, the same without (or with) the channel override, the annex, the
# rows the override moved and the prescription comparator.
reclasifica <- isTRUE(lectura_principal$reclasificar_canal)
resumen <- bind_rows(
  resumen_principal(
    base, universo, tablas$brecha_federal_estatal, comparadas_titular,
    lectura = filtros, seccion = "Resumen lectura principal",
    columna_precio = precio
  ),
  resumen_desde_base(
    if (reclasifica) base_original else reclasificar_canal(base_original),
    universo, lectura = filtros, columna_precio = precio,
    seccion = paste("Sensibilidad: lectura principal",
                    if (reclasifica) "sin" else "con",
                    "reclasificar el canal de las insulinas")
  ),
  resumen_principal(
    base, universo, tablas$anexo_canal_hospitalario,
    tablas$anexo_canal_hospitalario_claves,
    lectura = modifyList(filtros, list(solo_ambulatorio = FALSE)),
    canal = config$canal_anexo, seccion = "Resumen anexo hospitalario",
    columna_precio = precio
  ),
  if (reclasifica) resumen_reclasificacion(tablas$reclasificacion_canal),
  resumen_cobertura_prescripcion(tablas$cobertura_prescripcion),
  resumen_compra_prescripcion_clave(tablas$compra_vs_prescripcion_clave),
  resumen_compra_ciclo(compra_ciclo$resumen),
  resumen_sobrecosto(tablas$sobrecosto_estatal, variantes_sobrecosto),
  resumen_entregas(tablas, config$ruta_entregas)
)

# Write --------------------------------------------------------------------

dir.create(config$dir_salidas, showWarnings = FALSE)
leeme <- tabla_leeme(
  tablas,
  lectura = filtros,
  contexto = contexto,
  resumen = resumen,
  columna_precio = precio,
  ruta_base = config$ruta_base,
  sha256 = sha256_archivo(config$ruta_base),
  fecha_corrida = format(Sys.time(), "%Y-%m-%d %H:%M %Z", tz = "America/Mexico_City"),
  anclas = anclas,
  factores = filter(factores, año %in% filas_base$año_fiscal),
  ruta_inpc = config$ruta_inpc,
  sha256_inpc = sha256_archivo(config$ruta_inpc)
)
escribir_csvs(c(list(LEEME = leeme), tablas), config$dir_salidas)
escribir_xlsx(tablas, leeme, file.path(config$dir_salidas, "analisis_precios.xlsx"))

walk2(names(tablas), tablas, \(nombre, tabla) {
  message(sprintf("%-28s %6d filas", nombre, nrow(tabla)))
})
message("Salidas en ", normalizePath(config$dir_salidas))
