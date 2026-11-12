test_that("median, min, max and weighted mean per clave x grupo x año", {
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 20, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 30, cantidad_envases = 8),
    fila(precio_unitario_envase_mxn = 40, cantidad_envases = 0)
  ) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  expect_equal(nrow(res), 1)
  expect_equal(res$n_filas, 4)
  expect_equal(res$mediana, 25)
  expect_equal(res$minimo, 10)
  expect_equal(res$maximo, 40)
  # Quantity 0 is left out of the weights: (10 + 20 + 240) / 10.
  expect_equal(res$media_ponderada_cantidad, 27)
})

test_that("weights follow the price column", {
  expect_identical(columna_cantidad_para("precio_por_unidad_minima_mxn"),
                   "cantidad_unidades_minimas")
  expect_identical(columna_cantidad_para("precio_unitario_envase_mxn"),
                   "cantidad_envases")
})

test_that("comparada: pooled needs 2 groups, same-year needs them in one year", {
  medianas <- tribble(
    ~clave_cnis, ~grupo,   ~año_fiscal,
    "A",         "IMSS",   2024L,
    "A",         "ISSSTE", 2025L,   # two groups, never the same year
    "B",         "IMSS",   2025L,
    "B",         "ISSSTE", 2025L,   # same year
    "C",         "IMSS",   2024L,
    "C",         "IMSS",   2025L    # one group only
  )
  res <- claves_comparadas(medianas) |> arrange(clave_cnis)
  expect_identical(res$comparada_agrupado, c(TRUE, TRUE, FALSE))
  expect_identical(res$comparada_mismo_año, c(FALSE, TRUE, FALSE))
  expect_identical(res$años_comparados, c("", "2025", ""))
})

test_that("grupo_requerido demands that group among those compared", {
  medianas <- tribble(
    ~clave_cnis, ~grupo,               ~año_fiscal,
    "A",         "Colima",             2025L,
    "A",         "Jalisco",            2025L,
    "B",         "Colima",             2025L,
    "B",         "Federal (agrupado)", 2025L
  )
  res <- claves_comparadas(medianas, grupo_requerido = "Federal (agrupado)") |>
    arrange(clave_cnis)
  expect_identical(res$comparada_agrupado, c(FALSE, TRUE))
})

test_that("principal rule: federal plus one entidad in the same fiscal year", {
  medianas <- tribble(
    ~clave_cnis, ~grupo,               ~año_fiscal,
    # Two states, no federal that year: must not count.
    "A",         "Colima",             2025L,
    "A",         "Jalisco",            2025L,
    # Federal in 2024, state only in 2025: pooled yes, same-year no.
    "B",         "Federal (agrupado)", 2024L,
    "B",         "Colima",             2025L,
    # Federal and a state in 2025: counts both ways.
    "C",         "Federal (agrupado)", 2025L,
    "C",         "Colima",             2025L,
    "C",         "Colima",             2024L
  )
  requerido <- grupo_requerido_para("federal_vs_estatal")
  res <- claves_comparadas(medianas, grupo_requerido = requerido) |>
    arrange(clave_cnis)
  expect_identical(res$comparada_mismo_año, c(FALSE, FALSE, TRUE))
  expect_identical(res$comparada_agrupado, c(FALSE, TRUE, TRUE))
  expect_identical(res$años_comparados, c("", "", "2025"))
})

test_that("the required group applies to federal_vs_estatal only", {
  expect_identical(grupo_requerido_para("federal_vs_estatal"), "Federal (agrupado)")
  expect_null(grupo_requerido_para("entidades"))
  expect_identical(lectura_principal$comparacion, "federal_vs_estatal")
  expect_identical(lectura_principal$grupo_requerido,
                   grupo_requerido_para(lectura_principal$comparacion))
})

test_that("calcular_lectura applies the rule and can drop it", {
  base <- filas(
    fila(clave_cnis = "010.000.0001.00", orden_gobierno = "estatal",
         entidad_federativa = "Colima"),
    fila(clave_cnis = "010.000.0001.00", orden_gobierno = "estatal",
         entidad_federativa = "Jalisco")
  )
  con <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                          "federal_vs_estatal")
  sin <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                          "federal_vs_estatal", grupo_requerido = NULL)
  expect_false(con$comparadas$comparada_mismo_año)
  expect_true(sin$comparadas$comparada_mismo_año)
})

# Quantity-weighted median (principal indicator, decision of 2026-11-07) ----

test_that("weighted median differs from the per-row median and weighted mean", {
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 5),
    fila(precio_unitario_envase_mxn = 20, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 30, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 40, cantidad_envases = 3)
  ) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  # Cumulative quantity 5 of 10 reaches half at the first price.
  expect_equal(res$mediana_ponderada_cantidad, 10)
  expect_equal(res$mediana, 25)
  expect_equal(res$media_ponderada_cantidad, 22)
  expect_equal(res$n_sin_cantidad, 0L)
})

test_that("weighted median ignores rows without usable quantity and counts them", {
  datos <- filas(
    fila(precio_unitario_envase_mxn = 5, cantidad_envases = NA_real_),
    fila(precio_unitario_envase_mxn = 6, cantidad_envases = 0),
    fila(precio_unitario_envase_mxn = 7, cantidad_envases = -2),
    fila(precio_unitario_envase_mxn = 50, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 60, cantidad_envases = 3)
  ) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  expect_equal(res$n_filas, 5L)
  expect_equal(res$n_sin_cantidad, 3L)
  expect_equal(res$mediana_ponderada_cantidad, 60)
  expect_equal(res$mediana, 7)
})

test_that("weighted median is NA when no row has a usable quantity", {
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = NA_real_),
    fila(precio_unitario_envase_mxn = 20, cantidad_envases = 0)
  ) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  expect_true(is.na(res$mediana_ponderada_cantidad))
  expect_equal(res$mediana, 15)
  expect_equal(res$n_sin_cantidad, 2L)
})

test_that("half-weight boundary picks the lower price; ties and float sums", {
  # Exactly half on the first price: that price.
  expect_equal(mediana_ponderada(c(10, 20), c(5, 5)), 10)
  # Just under half: the next one.
  expect_equal(mediana_ponderada(c(10, 20), c(4, 6)), 20)
  # Order of the input does not matter.
  expect_equal(mediana_ponderada(c(20, 10), c(5, 5)), 10)
  # Repeated prices pool their quantity.
  expect_equal(mediana_ponderada(c(10, 10, 20), c(1, 1, 2)), 10)
  # cumsum(c(0.3, 0.6, 0.9))[2] is 0.8999999999999999, half of 1.8 is 0.9:
  # the second price reaches half exactly and must be picked.
  expect_equal(mediana_ponderada(c(10, 20, 30), c(0.3, 0.6, 0.9)), 20)
  expect_true(is.na(mediana_ponderada(c(10, NA), c(NA, 3))))
})

test_that("real weighted median is the nominal one times the factor", {
  factores <- tibble(año = 2024L, inpc_anual = 100, inpc_meses = 12L,
                     factor_deflacion = 1.25)
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 1, año_fiscal = 2024L),
    fila(precio_unitario_envase_mxn = 20, cantidad_envases = 9, año_fiscal = 2024L)
  ) |>
    deflactar_precios(factores) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  expect_equal(res$mediana_ponderada_cantidad, 20)
  expect_equal(res$mediana_ponderada_cantidad_real_2025, 25)
})

test_that("principal indicator comes from config and drives 'comparada'", {
  expect_identical(lectura_principal$indicador, "mediana_ponderada_cantidad")
  expect_identical(indicador_principal(), "mediana_ponderada_cantidad")
  expect_error(indicador_principal("media"), "Indicador no reconocido")
  # Federal has a price but no usable quantity: per-row it counts, weighted not.
  base <- filas(
    fila(cantidad_envases = NA_real_),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima")
  )
  res <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                          "federal_vs_estatal")
  expect_false(res$comparadas$comparada_mismo_año)
  expect_equal(res$comparadas$n_grupos, 1L)
  expect_true(res$comparadas$comparada_mismo_año_mediana)
  expect_equal(res$comparadas$n_grupos_mediana, 2L)
  por_fila <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                               "federal_vs_estatal", indicador = "mediana")
  expect_true(por_fila$comparadas$comparada_mismo_año)
})

test_that("the principal reading keeps only the ambulatory channel", {
  expect_true(lectura_base$solo_ambulatorio)
  # The only federal row is hospital-channel: no federal reference.
  base <- filas(
    fila(canal = "hospitalario"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima")
  )
  res <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                          "federal_vs_estatal")
  expect_false("hospitalario" %in% res$filas$canal)
  expect_false(res$comparadas$comparada_mismo_año)
})

test_that("federal_vs_estatal reads a cycle price in its second year", {
  base <- filas(
    fila(notas_metodologicas = "[CICLO_BIANUAL] El ciclo 25.26 cubre"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         año_fiscal = 2026L)
  )
  res <- calcular_lectura(base, "010.000.0001.00", lectura_contexto,
                          "federal_vs_estatal")
  expect_true(res$comparadas$comparada_mismo_año)
  expect_identical(res$comparadas$años_comparados, "2026")
  # One row per award in filas and medianas: no federal 2026 row.
  expect_equal(nrow(res$filas), 2)
  expect_false("ciclo_arrastrado" %in% names(res$filas))
  expect_identical(res$medianas$año_fiscal[res$medianas$grupo == etiqueta_federal],
                   2025L)
  # The rule can be switched off, and other comparisons never carry.
  sin <- calcular_lectura(base, "010.000.0001.00", lectura_contexto,
                          "federal_vs_estatal", ciclo_bianual = FALSE)
  expect_false(sin$comparadas$comparada_mismo_año)
  todas <- calcular_lectura(base, "010.000.0001.00", lectura_contexto,
                            "federal_todas")
  expect_equal(nrow(todas$medianas), 1)
})

test_that("open contracts weigh by the minimum quantity, not the maximum", {
  abierto <- "[CONTRATO_ABIERTO] Cantidad mínima en cantidad_envases"
  # Minimum: 3 at 10 and 5 at 20 -> half 4 -> 20. Maximum would give 10.
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 3,
         cantidad_maxima_envases = 100, notas_metodologicas = abierto),
    fila(precio_unitario_envase_mxn = 20, cantidad_envases = 5,
         cantidad_maxima_envases = 5, notas_metodologicas = abierto)
  ) |>
    mutate(grupo = "IMSS")
  expect_identical(columna_cantidad_para("precio_unitario_envase_mxn"),
                   "cantidad_envases")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  expect_equal(res$mediana_ponderada_cantidad, 20)
})
