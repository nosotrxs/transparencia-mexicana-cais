# State overcost against the federal reference (R/sobrecosto.R).

k1 <- "010.000.0001.00"
k2 <- "010.000.0002.00"
estatal <- function(...) {
  fila(orden_gobierno = "estatal", entidad_federativa = "Colima", ...)
}
universo_s <- tibble(clave_cnis = c(k1, k2), componente = c("A", "B"),
                     area = "Diabetes")

# Key 1, 2025: federal 10 x 30 and 100 x 10 -> weighted median 10, weighted
# mean 32.5. Colima pays 15 x 4 (overcost 20) and 5 x 2 (no overcost, not
# negative). A Colima row without quantity and one in 2024 (no federal
# reference that year) drop out. Key 2: only a 2024 cycle price 8 x 100,
# carried into 2025, where Jalisco pays 12 x 10 (overcost 40).
base_s <- filas(
  fila(precio_unitario_envase_mxn = 10, cantidad_envases = 30),
  fila(precio_unitario_envase_mxn = 100, cantidad_envases = 10),
  estatal(precio_unitario_envase_mxn = 15, cantidad_envases = 4),
  estatal(precio_unitario_envase_mxn = 5, cantidad_envases = 2,
          cantidad_maxima_envases = 50),
  estatal(precio_unitario_envase_mxn = 15, cantidad_envases = 0),
  estatal(precio_unitario_envase_mxn = 15, año_fiscal = 2024L),
  fila(clave_cnis = k2, año_fiscal = 2024L, precio_unitario_envase_mxn = 8,
       cantidad_envases = 100,
       notas_metodologicas = "[CICLO_BIANUAL] El ciclo 24.25 cubre"),
  fila(clave_cnis = k2, orden_gobierno = "estatal",
       entidad_federativa = "Jalisco", precio_unitario_envase_mxn = 12,
       cantidad_envases = 10)
)
filas_s <- filtrar_lectura(base_s, c(k1, k2), lectura_base, arrastre_ciclo = TRUE)

test_that("overcost: max(0, price - federal weighted median) x quantity", {
  res <- sobrecosto_estatal_filas(filas_s, "precio_unitario_envase_mxn") |>
    arrange(clave_cnis, desc(.precio))
  expect_identical(nrow(res), 3L)
  expect_identical(res$clave_cnis, c(k1, k1, k2))
  expect_equal(res$referencia, c(10, 10, 8))
  expect_equal(res$gasto, c(60, 10, 120))
  expect_equal(res$sobrecosto, c(20, 0, 40))
})

test_that("tabla_sobrecosto_estatal: total, year, state and key", {
  tabla <- sobrecosto_estatal_filas(filas_s, "precio_unitario_envase_mxn") |>
    tabla_sobrecosto_estatal(universo_s)
  expect_identical(names(tabla), c("nivel", "nombre", "componente",
                                   "gasto_estatal_comparado_mxn",
                                   "sobrecosto_mxn", "parte_del_gasto"))
  expect_identical(tabla$nivel, c("total", "año", "entidad", "entidad",
                                  "clave", "clave"))
  expect_identical(tabla$nombre, c("2024-2025", "2025", "Jalisco", "Colima",
                                   k2, k1))
  expect_identical(tabla$componente, c("", "", "", "", "B", "A"))
  expect_equal(tabla$gasto_estatal_comparado_mxn, c(190, 190, 120, 70, 120, 70))
  expect_equal(tabla$sobrecosto_mxn, c(60, 60, 40, 20, 40, 20))
  expect_equal(tabla$parte_del_gasto, round(c(60 / 190, 60 / 190, 1 / 3,
                                              20 / 70, 1 / 3, 20 / 70), 4))
})

test_that("sobrecosto_variantes: references, maximum quantity, federal group", {
  v <- sobrecosto_variantes(filas_s, "precio_unitario_envase_mxn")
  get <- function(id) v[v$variante == id, ]
  expect_equal(get("principal")$sobrecosto, 60)
  # (a) federal weighted mean 32.5 on key 1: no Colima row is above it.
  expect_equal(get("a")$sobrecosto, 40)
  # (b) all purchases of key 1, 2025 (no cycle copies): (300 + 1000 + 60 +
  # 10) / 46 = 29.78; key 2: 12, its only purchase in 2025 -> 0. The Colima
  # 2024 row of key 1 now has a reference (itself): 4 rows.
  expect_identical(get("b")$filas, 4L)
  expect_equal(get("b")$sobrecosto, 0)
  # (c) maximum quantity: the 5 x 2 row (max 50) is still below; 15 x 4 has
  # no maximum. Same as the headline here.
  expect_equal(get("c")$sobrecosto, 60)
  # (d) federal group of key 1: mean 32.5, row 100 x 10 -> 675; key 2 in 2024
  # and its copy in 2025: single rows, 0. Spending 300 + 1000 + 800 + 800.
  expect_identical(get("d")$ambito, "federal")
  expect_identical(get("d")$filas, 4L)
  expect_equal(get("d")$sobrecosto, 675)
  expect_equal(get("d")$gasto, 2900)
})

test_that("variant (c) multiplies by the open contract's maximum", {
  base_c <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 30),
    estatal(precio_unitario_envase_mxn = 15, cantidad_envases = 4,
            cantidad_maxima_envases = 40)
  )
  f <- filtrar_lectura(base_c, k1, lectura_base, arrastre_ciclo = TRUE)
  v <- sobrecosto_variantes(f, "precio_unitario_envase_mxn")
  expect_equal(v$sobrecosto[v$variante == "principal"], 20)
  expect_equal(v$sobrecosto[v$variante == "c"], 200)
  # Spending stays on the minimum quantity.
  expect_equal(v$gasto[v$variante == "c"], 60)
})

test_that("resumen_sobrecosto writes the totals and the four variants", {
  tabla <- sobrecosto_estatal_filas(filas_s, "precio_unitario_envase_mxn") |>
    tabla_sobrecosto_estatal(universo_s)
  v <- sobrecosto_variantes(filas_s, "precio_unitario_envase_mxn")
  res <- resumen_sobrecosto(tabla, v)
  valor <- function(campo) res$valor[res$campo == campo]
  expect_identical(valor("filas_estatales"), "3")
  expect_identical(valor("sobrecosto_2024-2025"), "60 de 190 (31.6 %)")
  expect_identical(valor("sobrecosto_2025"), "60 de 190 (31.6 %)")
  expect_match(valor("variante_d"), "675 de 2,900 \\(23\\.3 %\\); 4 filas federales")
  expect_identical(sum(startsWith(res$campo, "variante_")), 4L)
})
