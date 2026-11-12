# Monthly fixture: 2024 and 2025 complete, 2026 with three months only, 2023
# absent. Values chosen so the annual means are round.
inpc_mensual <- dplyr::bind_rows(
  tibble(año = 2024L, mes = 1:12, inpc = rep(c(90, 110), 6)),     # mean 100
  tibble(año = 2025L, mes = 1:12, inpc = rep(c(115, 125), 6)),    # mean 120
  tibble(año = 2026L, mes = 1:3, inpc = c(126, 132, 138))         # mean 132
) |>
  mutate(fecha = as.Date(sprintf("%d-%02d-01", año, mes)))

test_that("annual INPC is the mean of the available months", {
  anual <- inpc_anual(inpc_mensual)
  expect_identical(anual$año, c(2024L, 2025L, 2026L))
  expect_equal(anual$inpc_anual, c(100, 120, 132))
  expect_identical(anual$inpc_meses, c(12L, 12L, 3L))
})

test_that("factor = INPC of the base year / INPC of the year; base is exactly 1", {
  f <- factores_deflacion(inpc_mensual, año_base = 2025L)
  expect_identical(f$factor_deflacion[f$año == 2025L], 1)
  expect_equal(f$factor_deflacion[f$año == 2024L], 1.2)
  expect_equal(f$factor_deflacion[f$año == 2026L], 120 / 132)
})

test_that("the base year must have twelve months", {
  expect_error(factores_deflacion(inpc_mensual, año_base = 2026L), "12 meses")
  expect_error(factores_deflacion(inpc_mensual, año_base = 2023L), "12 meses")
})

test_that("real price = nominal x factor; years without INPC stay NA", {
  f <- factores_deflacion(inpc_mensual, año_base = 2025L)
  datos <- filas(
    fila(año_fiscal = 2024L, precio_unitario_envase_mxn = 50),
    fila(año_fiscal = 2025L, precio_unitario_envase_mxn = 50),
    fila(año_fiscal = 2026L, precio_unitario_envase_mxn = 66),
    fila(año_fiscal = 2023L, precio_unitario_envase_mxn = 50),   # no INPC
    fila(año_fiscal = 2027L, precio_unitario_envase_mxn = 50),   # no INPC
    fila(año_fiscal = NA_integer_, precio_unitario_envase_mxn = 50)
  )
  res <- deflactar_precios(datos, f)
  real <- res[[columna_real("precio_unitario_envase_mxn")]]
  expect_equal(real, c(60, 50, 60, NA, NA, NA))
  expect_identical(res$inpc_meses, c(12L, 12L, 3L, NA, NA, NA))
  # Nominal prices untouched, and the per-unit price is deflated too.
  expect_identical(res$precio_unitario_envase_mxn, datos$precio_unitario_envase_mxn)
  expect_equal(res[[columna_real("precio_por_unidad_minima_mxn")]][1], 12)
  expect_identical(deflactar_precios(datos, NULL), datos)
})

test_that("medians carry real columns; 2027 gets NA, not the nominal price", {
  f <- factores_deflacion(inpc_mensual, año_base = 2025L)
  datos <- filas(
    fila(año_fiscal = 2024L, precio_unitario_envase_mxn = 10),
    fila(año_fiscal = 2024L, precio_unitario_envase_mxn = 30),
    fila(año_fiscal = 2027L, precio_unitario_envase_mxn = 40)
  ) |>
    deflactar_precios(f) |>
    mutate(grupo = "IMSS")
  res <- mediana_por_grupo(datos, "precio_unitario_envase_mxn")
  real <- paste0("mediana", sufijo_real)
  expect_equal(res$mediana, c(20, 40))
  expect_equal(res[[real]], c(24, NA))
  expect_equal(res$factor_deflacion, c(1.2, NA))
})
