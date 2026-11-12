# Hospital-channel annex (decision of 2026-11-08): the principal reading uses
# only canal == "ambulatorio"; the hospital rows are compared apart, with the
# same comparison (federal vs each state), the same indicator, the same
# biannual-cycle rule and the other filters of the principal reading. Never
# mixed into the principal tables. Like them, it covers the context series
# (lectura_contexto, 2019-2026) and marks the headline period (fiscal 2025):
# par_principal in brecha, comparada_principal in claves (principal.R).

# Returns two tables:
# - brecha: brecha_federal_estatal() on the rows of `canal` only.
# - claves: one row per key with rows in that channel: federal and state rows,
#   state-year pairs with a federal reference, and the "comparada" rule of
#   calcular_lectura() (pooled and same year, principal indicator and, with
#   suffix _mediana, the per-row median), plus that rule in the headline period
#   (comparada_principal).
anexo_canal <- function(base, claves_universo,
                        lectura = lectura_contexto,
                        canal = config$canal_anexo,
                        columna_precio = config$columna_precio,
                        factores = NULL,
                        periodo_principal = lectura_base$periodo) {
  # The channel switch of the principal reading would leave no hospital row.
  lectura$solo_ambulatorio <- FALSE
  ciclo <- lectura_principal$ciclo_bianual_segundo_año
  filas <- filtrar_lectura(base, claves_universo, lectura,
                           columna_precio = columna_precio, canal = canal,
                           arrastre_ciclo = ciclo) |>
    deflactar_precios(factores)
  brecha <- brecha_federal_estatal(filas, columna_precio) |>
    marcar_pares_principal(periodo_principal)

  lectura_anexo <- function(periodo) {
    calcular_lectura(base, claves_universo,
                     utils::modifyList(lectura, list(periodo = periodo)),
                     "federal_vs_estatal", columna_precio = columna_precio,
                     factores = factores, ciclo_bianual = ciclo, canal = canal)
  }
  res <- lectura_anexo(lectura$periodo)
  res_principal <- lectura_anexo(periodo_principal)
  conteos <- res$filas |>
    dplyr::summarise(
      n_filas_federal = sum(orden_gobierno == "federal"),
      n_filas_estatal = sum(orden_gobierno == "estatal"),
      .by = clave_cnis
    )
  pares <- brecha |>
    dplyr::summarise(pares_estatal_año_con_federal = sum(con_federal_mismo_año),
                     .by = clave_cnis)
  claves <- conteos |>
    dplyr::left_join(pares, by = "clave_cnis") |>
    dplyr::left_join(
      con_comparada_principal(res$comparadas, res_principal$comparadas),
      by = "clave_cnis"
    ) |>
    dplyr::mutate(
      canal = canal,
      pares_estatal_año_con_federal =
        dplyr::coalesce(pares_estatal_año_con_federal, 0L),
      .after = clave_cnis
    ) |>
    dplyr::arrange(clave_cnis)
  list(
    brecha = dplyr::mutate(brecha, canal = canal, .after = clave_cnis),
    claves = claves
  )
}
