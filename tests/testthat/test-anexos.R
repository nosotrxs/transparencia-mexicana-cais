claves <- c("010.000.0001.00", "010.000.0002.00")

test_that("anexo_canal compares only hospital rows, apart from the principal reading", {
  base <- filas(
    # Clave 1: federal and Colima in the hospital channel; Jalisco ambulatory.
    fila(canal = "hospitalario", precio_unitario_envase_mxn = 50),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         canal = "hospitalario", precio_unitario_envase_mxn = 100),
    fila(orden_gobierno = "estatal", entidad_federativa = "Jalisco",
         precio_unitario_envase_mxn = 999),
    # Clave 2: ambulatory only.
    fila(clave_cnis = "010.000.0002.00"),
    fila(clave_cnis = "010.000.0002.00", orden_gobierno = "estatal",
         entidad_federativa = "Colima")
  )
  anexo <- anexo_canal(base, claves, lectura = lectura_base)
  expect_identical(anexo$brecha$entidad_federativa, "Colima")
  expect_identical(anexo$brecha$canal, "hospitalario")
  expect_equal(anexo$brecha$razon_estatal_federal, 2)
  expect_identical(anexo$claves$clave_cnis, "010.000.0001.00")
  expect_equal(anexo$claves$n_filas_federal, 1L)
  expect_equal(anexo$claves$n_filas_estatal, 1L)
  expect_equal(anexo$claves$pares_estatal_año_con_federal, 1L)
  expect_true(anexo$claves$comparada_mismo_año)
  # The principal reading does not see the hospital rows.
  principal <- calcular_lectura(base, claves, lectura_base,
                                "federal_vs_estatal")
  expect_identical(
    principal$comparadas$clave_cnis[principal$comparadas$comparada_mismo_año],
    "010.000.0002.00"
  )
})

test_that("anexo_canal covers 2019-2026 and marks the 2024-2025 headline", {
  hosp <- function(...) fila(canal = "hospitalario", ...)
  base <- filas(
    # Clave 1: federal and Colima in 2023 and 2025, plus a federal 2027 row.
    hosp(año_fiscal = 2023L),
    hosp(año_fiscal = 2023L, orden_gobierno = "estatal",
         entidad_federativa = "Colima"),
    hosp(), hosp(orden_gobierno = "estatal", entidad_federativa = "Colima"),
    hosp(año_fiscal = 2027L),
    # Clave 2: pair in 2023 only.
    hosp(clave_cnis = "010.000.0002.00", año_fiscal = 2023L),
    hosp(clave_cnis = "010.000.0002.00", año_fiscal = 2023L,
         orden_gobierno = "estatal", entidad_federativa = "Colima")
  )
  anexo <- anexo_canal(base, claves)
  b1 <- filter(anexo$brecha, clave_cnis == "010.000.0001.00")
  expect_identical(b1$año_fiscal, c(2023L, 2025L))
  expect_identical(b1$par_principal, c(FALSE, TRUE))
  expect_equal(anexo$claves$n_filas_federal, c(2L, 1L))
  expect_identical(anexo$claves$comparada_mismo_año, c(TRUE, TRUE))
  expect_identical(anexo$claves$comparada_principal, c(TRUE, FALSE))
})
