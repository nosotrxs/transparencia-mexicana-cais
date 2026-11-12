# Headline reading = fiscal 2024 and 2025, each pair within its own year;
# context series = 2019-2026 (2026-11-08).

k <- c("010.000.0001.00", "010.000.0002.00", "010.000.0003.00")
colima <- function(...) {
  fila(orden_gobierno = "estatal", entidad_federativa = "Colima", ...)
}

test_that("the headline is fiscal 2024-2025 and the context 2019-2026, same switches", {
  expect_identical(lectura_base$periodo, "2024_2025")
  expect_identical(lectura_contexto$periodo, "2019_2026")
  expect_identical(lectura_principal$filtros, lectura_base)
  sin_periodo <- function(x) x[names(x) != "periodo"]
  expect_identical(sin_periodo(lectura_contexto), sin_periodo(lectura_base))
})

test_that("comparada_principal reads 2024 and 2025, each year on its own", {
  base <- filas(
    # Key 1: federal and Colima in 2023 only (context, not headline).
    fila(año_fiscal = 2023L), colima(año_fiscal = 2023L),
    # Key 2: federal and Colima in 2024.
    fila(clave_cnis = k[2], año_fiscal = 2024L),
    colima(clave_cnis = k[2], año_fiscal = 2024L),
    # Key 3: federal 2024 and Colima 2025: never in the same year.
    fila(clave_cnis = k[3], año_fiscal = 2024L), colima(clave_cnis = k[3])
  )
  lee <- function(lectura) {
    calcular_lectura(base, k, lectura, "federal_vs_estatal")$comparadas
  }
  res <- con_comparada_principal(lee(lectura_contexto), lee(lectura_base))
  expect_identical(res$clave_cnis, k)
  expect_identical(res$comparada_mismo_año, c(TRUE, TRUE, FALSE))
  expect_identical(res$comparada_principal, c(FALSE, TRUE, FALSE))
  expect_identical(res$comparada_principal_mediana, c(FALSE, TRUE, FALSE))
})

test_that("par_principal marks 2024-2025 pairs with both indicators", {
  datos <- filas(
    fila(año_fiscal = 2023L), colima(año_fiscal = 2023L),
    fila(), colima(),
    # Jalisco 2025 without federal quantity on key 2: no principal pair.
    fila(clave_cnis = k[2], cantidad_envases = NA_real_),
    fila(clave_cnis = k[2], orden_gobierno = "estatal",
         entidad_federativa = "Jalisco")
  )
  res <- brecha_federal_estatal(datos, "precio_unitario_envase_mxn") |>
    marcar_pares_principal()
  expect_identical(res$año_fiscal, c(2023L, 2025L, 2025L))
  expect_identical(res$par_principal, c(FALSE, TRUE, FALSE))
  expect_identical(names(res)[match("año_fiscal", names(res)) + 1],
                   "par_principal")
})

test_that("context tables drop fiscal 2027 and the copies carried into it", {
  base <- filas(
    fila(año_fiscal = 2019L),
    fila(año_fiscal = 2026L,
         notas_metodologicas = "[CICLO_BIANUAL] El ciclo 26.27 cubre"),
    fila(año_fiscal = 2027L,
         notas_metodologicas = "[CICLO_BIANUAL] El ciclo 27.28 cubre")
  )
  res <- filtrar_lectura(base, k, lectura_contexto, arrastre_ciclo = TRUE)
  expect_identical(res$año_fiscal, c(2019L, 2026L))
})

test_that("motivos_no_comparada names the reason of each key", {
  cuatro <- "010.000.0004.00"
  cinco <- "010.000.0005.00"
  seis <- "010.000.0006.00"
  siete <- "010.000.0007.00"
  base <- filas(
    # Key 1: only a non-comparable row.
    fila(comparable = FALSE),
    # Key 2: rows in 2023 only.
    fila(clave_cnis = k[2], año_fiscal = 2023L),
    # Key 3: 2025 rows, hospital channel only.
    fila(clave_cnis = k[3], canal = "hospitalario"),
    colima(clave_cnis = k[3], canal = "hospitalario"),
    # Key 4: state ambulatory; federal only in the hospital channel.
    fila(clave_cnis = cuatro, canal = "hospitalario"),
    colima(clave_cnis = cuatro),
    # Key 5: federal only.
    fila(clave_cnis = cinco),
    # Key 6: federal row without quantity: no federal price.
    fila(clave_cnis = seis, cantidad_envases = NA_real_),
    colima(clave_cnis = seis),
    # Key 7: only a 2023 cycle price, carried into 2024: has rows in the
    # period.
    fila(clave_cnis = siete, año_fiscal = 2023L,
         notas_metodologicas = "[CICLO_BIANUAL] El ciclo 23.24 cubre")
  )
  claves <- c(k, cuatro, cinco, seis, siete)
  res <- motivos_no_comparada(base, claves)
  expect_identical(res$clave_cnis, claves)
  expect_identical(res$motivo, c(
    "sin filas comparables en la base (ningún año ni canal)",
    "sin filas en 2024-2025",
    "solo canal hospitalario en 2024-2025",
    "sin precio federal en 2024-2025 (hay filas federales de canal hospitalario)",
    "sin precio estatal en 2024-2025",
    "sin precio federal en 2024-2025",
    "sin precio estatal en 2024-2025"
  ))
})

test_that("resumen_principal: totals for 2024-2025 and the same block per year", {
  universo <- tibble(clave_cnis = k, componente = c("A", "B", "C"),
                     area = "Diabetes")
  base <- filas(
    # Key 1, 2025: federal 10; Colima 20 and Jalisco 40 -> ratios 2 and 4.
    fila(precio_unitario_envase_mxn = 10),
    colima(precio_unitario_envase_mxn = 20),
    fila(orden_gobierno = "estatal", entidad_federativa = "Jalisco",
         precio_unitario_envase_mxn = 40),
    # Key 1, 2023: a context pair, outside the headline.
    fila(año_fiscal = 2023L), colima(año_fiscal = 2023L),
    # Key 2: 2024 cycle price 10, carried into 2025; Colima 2025 at 5 -> 0.5
    # (carried reference) and Colima 2024 at 100 -> 10.
    fila(clave_cnis = k[2], año_fiscal = 2024L, precio_unitario_envase_mxn = 10,
         notas_metodologicas = "[CICLO_BIANUAL] El ciclo 24.25 cubre"),
    colima(clave_cnis = k[2], precio_unitario_envase_mxn = 5),
    colima(clave_cnis = k[2], año_fiscal = 2024L),
    # Key 3: federal only.
    fila(clave_cnis = k[3])
  )
  brecha <- filtrar_lectura(base, k, lectura_contexto, arrastre_ciclo = TRUE) |>
    brecha_federal_estatal("precio_unitario_envase_mxn") |>
    marcar_pares_principal()
  lee <- function(lectura) {
    calcular_lectura(base, k, lectura, "federal_vs_estatal")$comparadas
  }
  comparadas <- con_comparada_principal(lee(lectura_contexto), lee(lectura_base))
  res <- resumen_principal(base, universo, brecha, comparadas, seccion = "R")
  valor <- function(campo, seccion = "R") {
    res$valor[res$seccion == seccion & res$campo == campo]
  }

  expect_identical(unique(res$seccion),
                   c("R", "R: 2024", "R: 2025", "R: clave no comparada"))
  # 2024-2025: ratios 0.5, 2, 4 (2025) and 10 (2024).
  expect_match(valor("periodo"), "^2024_2025 ")
  expect_identical(valor("claves_comparadas"), "2 de 3")
  expect_identical(valor("claves_no_comparadas"), "1")
  expect_identical(valor("pares_entidad_clave_año"), "4")
  expect_identical(valor("entidades_con_pares"), "2: Colima, Jalisco")
  expect_match(valor("razon_estatal_federal_mediana_de_pares"), "^3\\.000 .*4 pares")
  expect_identical(valor("razon_estatal_federal_p25"), "1.625")
  expect_identical(valor("razon_estatal_federal_p75"), "5.500")
  expect_identical(valor("pares_razon_mayor_a_1"), "3 de 4 (75.0 %)")
  expect_identical(valor("pares_razon_mayor_a_2"), "2 de 4 (50.0 %)")
  expect_match(valor("razon_estatal_federal_por_fila_mediana_de_pares"), "^3\\.000 ")
  expect_identical(valor("pares_con_ciclo_arrastrado"), "1 de 4 (25.0 %)")
  # 2024 alone: key 2 in Colima.
  expect_identical(valor("claves_comparadas", "R: 2024"), "1 de 3")
  expect_identical(valor("claves_no_comparadas", "R: 2024"), "2")
  expect_identical(valor("pares_entidad_clave_año", "R: 2024"), "1")
  expect_identical(valor("entidades_con_pares", "R: 2024"), "1: Colima")
  expect_match(valor("razon_estatal_federal_mediana_de_pares", "R: 2024"), "^10\\.000 ")
  expect_identical(valor("pares_con_ciclo_arrastrado", "R: 2024"), "0 de 1 (0.0 %)")
  # 2025 alone: the three 2025 pairs.
  expect_identical(valor("claves_comparadas", "R: 2025"), "2 de 3")
  expect_identical(valor("pares_entidad_clave_año", "R: 2025"), "3")
  expect_match(valor("razon_estatal_federal_mediana_de_pares", "R: 2025"), "^2\\.000 ")
  expect_identical(valor("razon_estatal_federal_p25", "R: 2025"), "1.250")
  expect_identical(valor("razon_estatal_federal_p75", "R: 2025"), "3.000")
  expect_identical(valor("pares_razon_mayor_a_2", "R: 2025"), "1 de 3 (33.3 %)")
  expect_identical(valor("pares_con_ciclo_arrastrado", "R: 2025"), "1 de 3 (33.3 %)")
  no <- filter(res, seccion == "R: clave no comparada")
  expect_identical(no$campo, k[3])
  expect_identical(no$valor, "C: sin precio estatal en 2024-2025")
  # The same summary computed from the base alone (used for the headline
  # without the channel override).
  expect_identical(resumen_desde_base(base, universo, seccion = "R"), res)
})

test_that("comparada_en_año reads años_comparados", {
  expect_identical(comparada_en_año(c("2024, 2025", "2025", "", NA), 2024),
                   c(TRUE, FALSE, FALSE, FALSE))
  expect_identical(años_del_periodo("2024_2025"), c(2024L, 2025L))
})

test_that("motivos_no_comparada with no row in the channel gives the reason, no warning", {
  base <- filas(fila(), colima())
  expect_no_warning(
    res <- motivos_no_comparada(base, k[1], canal = "hospitalario")
  )
  expect_identical(res$motivo, "solo canal ambulatorio en 2024-2025")
})

test_that("cifras_pares counts ratios above 5 and 10 and single-row state sides", {
  pares <- tibble(
    entidad_federativa = "Colima", clave_cnis = "k",
    razon_estatal_federal = c(0.5, 4, 6, 11, 20),
    razon_estatal_federal_mediana = c(0.5, 4, 6, 11, 20),
    n_filas_estatal = c(1L, 2L, 1L, 1L, 3L),
    federal_con_ciclo_arrastrado = FALSE
  )
  res <- cifras_pares(pares, 1, 3, "R", "p")
  valor <- function(campo) res$valor[res$campo == campo]
  expect_identical(valor("pares_razon_mayor_a_5"), "3 de 5 (60.0 %)")
  expect_identical(valor("pares_razon_mayor_a_10"), "2 de 5 (40.0 %)")
  expect_identical(valor("pares_con_una_fila_estatal"), "3 de 5 (60.0 %)")
})

test_that("razon_por_eje_y_clave: median ratio per axis and per key", {
  universo <- tibble(clave_cnis = k, componente = c("A", "B", "C"),
                     area = c("Diabetes", "Salud mental", "Salud mental"))
  brecha <- tibble(
    clave_cnis = c(k[1], k[1], k[2], k[3], k[3], k[3], k[3]),
    razon_estatal_federal = c(1, 3, 10, 2, 4, 6, 100),
    par_principal = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)
  )
  res <- razon_por_eje_y_clave(brecha, universo)
  expect_identical(res$nivel, c("eje", "eje", "clave", "clave", "clave"))
  expect_identical(res$area, c("Diabetes", "Salud mental", "Diabetes",
                               "Salud mental", "Salud mental"))
  expect_identical(res$clave_cnis, c("", "", k[1], k[2], k[3]))
  expect_identical(res$pares, c(2L, 4L, 2L, 1L, 3L))
  expect_equal(res$razon_estatal_federal_mediana, c(2, 5, 2, 10, 4))
})
