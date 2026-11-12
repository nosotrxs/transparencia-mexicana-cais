# Quality comparator with OCAMIS prescriptions (Andrés, 2026-11-08). Tiny
# hand-made fixtures; the real workbook is never read here.

k1 <- "010.000.0001.00"
k2 <- "010.000.0002.00"
k3 <- "010.000.0003.00"
inst <- c(IMSS = "IMSS (Ordinario)", ISSSTE = "ISSSTE")

presc_fila <- function(año, institucion, clave, prescrito, semana = 1L) {
  tibble(año = as.integer(año), semana = as.integer(semana),
         institucion = institucion, clave_cnis = clave, prescrito = prescrito,
         entregado = prescrito, recetas = 1)
}

test_that("leer_ocamis reads the sheet datos with typed columns", {
  ruta <- tempfile(fileext = ".xlsx")
  hoja <- data.frame(
    `año ISO` = c(2023, 2023), `semana ISO` = c(1, 2),
    `institución` = c("ISSSTE", "IMSS (Ordinario)"),
    estado = c(NA, "Colima"), clave = c(k1, k2),
    prescrito = c(5, 7), entregado = c(5, 0), recetas = c(2, 3),
    check.names = FALSE
  )
  libro <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(libro, "datos")
  openxlsx::writeData(libro, "datos", hoja)
  openxlsx::saveWorkbook(libro, ruta)
  res <- leer_ocamis(ruta)
  expect_identical(res$año, c(2023L, 2023L))
  expect_identical(res$clave_cnis, c(k1, k2))
  expect_identical(res$institucion, c("ISSSTE", "IMSS (Ordinario)"))
  expect_equal(res$prescrito, c(5, 7))
  expect_error(leer_ocamis(tempfile()), "No existe")
})

test_that("prescripcion_anual sums weeks, keeps universe keys, counts weeks", {
  ocamis <- bind_rows(
    presc_fila(2023, inst[[1]], k1, 10, 1), presc_fila(2023, inst[[1]], k1, 5, 2),
    presc_fila(2023, inst[[1]], "999.000.9999.00", 100, 3),
    presc_fila(2023, inst[[2]], k1, 4, 1)
  )
  res <- prescripcion_anual(ocamis, c(k1, k2))
  expect_equal(res$prescrito, c(15, 4))
  expect_identical(res$n_semanas, c(3L, 1L))
})

universo3 <- tibble(clave_cnis = c(k1, k2, k3), componente = c("A", "B", "C"),
                    area = "Diabetes")

test_that("cobertura_prescripcion: boxes, shares, compared years and reasons", {
  presc <- bind_rows(
    presc_fila(2023, inst[[1]], k1, 60), presc_fila(2023, inst[[1]], k2, 40),
    presc_fila(2022, inst[[1]], k3, 999),
    presc_fila(2023, inst[[2]], k3, 10)
  )
  comparadas <- tibble(clave_cnis = c(k1, k2, k3),
                       comparada_principal = c(TRUE, FALSE, TRUE),
                       años_comparados = c("2024, 2025", "2019", "2025"))
  motivos <- tibble(clave_cnis = c(k1, k2, k3), motivo = c("x", "sin filas", "y"))
  res <- cobertura_prescripcion(presc, universo3, comparadas, motivos,
                                año = 2023L, instituciones = inst,
                                años_principal = c(2024L, 2025L))
  expect_equal(res$cajas_prescritas_imss_2023, c(60, 40, 0))
  expect_equal(res$parte_imss, c(0.6, 0.4, 0))
  expect_equal(res$cajas_prescritas_issste_2023, c(0, 0, 10))
  expect_identical(res$comparada_2024, c(TRUE, FALSE, FALSE))
  expect_identical(res$comparada_2025, c(TRUE, FALSE, TRUE))
  expect_identical(res$motivo_no_comparada, c(NA, "sin filas", NA))
  texto <- resumen_cobertura_prescripcion(res, año = 2023L, instituciones = inst)
  expect_identical(texto$campo, unname(inst))
  expect_match(texto$valor[1], "^60\\.0 % \\(60 de 100 cajas")
  expect_match(texto$valor[2], "^100\\.0 % \\(10 de 10 cajas")
})

compra <- function(...) {
  valores <- utils::modifyList(
    list(cantidad_maxima_envases = NA_real_, duplicado_de = NA_character_),
    list(...)
  )
  do.call(fila, valores)
}

test_that("compra_vs_prescripcion: comparable, non-duplicate, any channel", {
  base <- filas(
    compra(clave_cnis = k1, cantidad_envases = 30, año_fiscal = 2023L),
    compra(clave_cnis = k1, cantidad_envases = 5, año_fiscal = 2023L,
           canal = "hospitalario", cantidad_maxima_envases = 20),
    # Left out: duplicate, non-comparable, other institution, other key.
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2023L,
           duplicado_de = "MED-9"),
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2023L,
           comparable = FALSE),
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2023L,
           tipo_institucion = "IMSS-Bienestar"),
    compra(clave_cnis = "999.000.9999.00", cantidad_envases = 1000,
           año_fiscal = 2023L),
    # A purchase without prescription.
    compra(clave_cnis = k3, cantidad_envases = 7, año_fiscal = 2023L)
  )
  presc <- bind_rows(
    presc_fila(2023, inst[[1]], k1, 70), presc_fila(2023, inst[[1]], k2, 30)
  ) |>
    prescripcion_anual(c(k1, k2, k3))
  res <- compra_vs_prescripcion(base, c(k1, k2, k3), presc, años = 2022:2023,
                                instituciones = inst)
  expect_identical(res$institucion, rep(unname(inst), each = 2))
  expect_identical(res$año, rep(2022:2023, 2))
  imss <- filter(res, institucion == inst[[1]], año == 2023L)
  expect_equal(imss$cajas_prescritas, 100)
  expect_equal(imss$cajas_compradas_minimo, 42)
  expect_equal(imss$cajas_compradas_maximo, 57)
  expect_equal(imss$claves_con_prescripcion, 2)
  expect_equal(imss$claves_con_compra, 2)
  expect_equal(imss$claves_con_ambas, 1)
  expect_equal(imss$razon_compra_prescripcion_claves_con_ambas, 35 / 70)
  expect_equal(imss$parte_comprada_minimo, 0.42)
  expect_equal(imss$parte_comprada_maximo, 0.57)
  expect_identical(imss$semanas_prescripcion, 1L)
  vacio <- filter(res, institucion == inst[[2]], año == 2022L)
  expect_equal(vacio$cajas_prescritas, 0)
  expect_true(is.na(vacio$parte_comprada_minimo))
})

test_that("compra_ciclo_vs_prescripcion halves only the tagged cycle rows", {
  ciclo <- "[CICLO_BIANUAL] El ciclo 25.26 cubre dos ejercicios"
  base <- filas(
    compra(clave_cnis = k1, cantidad_envases = 100, notas_metodologicas = ciclo),
    compra(clave_cnis = k1, cantidad_envases = 10),
    compra(clave_cnis = k2, cantidad_envases = 40, tipo_institucion = "ISSSTE",
           notas_metodologicas = ciclo),
    # Other year and duplicate: left out.
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2024L),
    compra(clave_cnis = k1, cantidad_envases = 1000, duplicado_de = "MED-9")
  )
  presc <- bind_rows(
    presc_fila(2023, inst[[1]], k1, 120), presc_fila(2023, inst[[1]], k3, 5),
    presc_fila(2023, inst[[2]], k2, 10)
  )
  res <- compra_ciclo_vs_prescripcion(base, universo3, presc, año_compra = 2025L,
                                      año_prescripcion = 2023L,
                                      instituciones = inst)
  imss_k1 <- filter(res$por_clave, institucion == inst[[1]], clave_cnis == k1)
  expect_equal(imss_k1$cajas_anuales, 60)
  expect_equal(imss_k1$razon_anual_prescrito, 0.5)
  expect_equal(imss_k1$diferencia_anual_menos_prescrito, -60)
  expect_identical(nrow(res$por_clave), 3L)
  expect_equal(res$resumen$filas_ciclo, c(1, 1))
  expect_equal(res$resumen$filas_sin_etiqueta, c(1, 0))
  expect_equal(res$resumen$cajas_ciclo, c(100, 40))
  expect_equal(res$resumen$cajas_sin_etiqueta, c(10, 0))
  expect_equal(res$resumen$cajas_anuales, c(60, 20))
  expect_equal(res$resumen$razon_anual_prescrito, c(60 / 125, 2))
  texto <- resumen_compra_ciclo(res$resumen, 2025L, 2023L)
  expect_match(texto$valor[1], "^60 cajas al año contra 125 prescritas \\(razón 0\\.48\\)\\. Filas 2: 1 con \\[CICLO_BIANUAL\\] \\(100 cajas")
})

test_that("compra_vs_prescripcion_clave: per key, same year, both quantities", {
  base <- filas(
    compra(clave_cnis = k1, cantidad_envases = 30, año_fiscal = 2023L,
           tipo_institucion = "ISSSTE", cantidad_maxima_envases = 75),
    compra(clave_cnis = k1, cantidad_envases = 10, año_fiscal = 2023L,
           tipo_institucion = "ISSSTE", canal = "hospitalario"),
    # Left out: a duplicate and a purchase of another year.
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2023L,
           tipo_institucion = "ISSSTE", duplicado_de = "MED-9"),
    compra(clave_cnis = k1, cantidad_envases = 1000, año_fiscal = 2022L,
           tipo_institucion = "ISSSTE"),
    # A purchase without prescription.
    compra(clave_cnis = k3, cantidad_envases = 7, año_fiscal = 2023L,
           tipo_institucion = "ISSSTE")
  )
  presc <- bind_rows(
    presc_fila(2023, inst[[2]], k1, 50), presc_fila(2023, inst[[2]], k2, 20),
    presc_fila(2023, inst[[2]], k3, 0)
  ) |>
    prescripcion_anual(c(k1, k2, k3))
  res <- compra_vs_prescripcion_clave(base, c(k1, k2, k3), presc,
                                      años = 2023L, instituciones = inst)
  expect_identical(res$clave_cnis, c(k1, k2, k3))
  expect_identical(res$año, rep(2023L, 3))
  expect_equal(res$cajas_prescritas, c(50, 20, 0))
  expect_equal(res$cajas_compradas_minimo, c(40, 0, 7))
  expect_equal(res$cajas_compradas_maximo, c(85, 0, 7))
  expect_identical(res$ambas, c(TRUE, FALSE, FALSE))
  expect_equal(res$razon_compra_prescripcion_minimo, c(0.8, 0, NA))
  expect_equal(res$razon_compra_prescripcion_maximo, c(1.7, 0, NA))
  # The summary by institution-year is the sum of these rows.
  tot <- compra_vs_prescripcion(base, c(k1, k2, k3), presc, años = 2023L,
                                instituciones = inst) |>
    filter(institucion == inst[[2]])
  expect_equal(tot$cajas_compradas_minimo, sum(res$cajas_compradas_minimo))
  expect_equal(tot$claves_con_ambas, 1)
})

test_that("resumen_compra_prescripcion_clave: keys with both and median ratio", {
  por_clave <- tibble(
    institucion = c("ISSSTE", "ISSSTE", "ISSSTE", "ISSSTE", "ISSSTE",
                    "IMSS (Ordinario)"),
    año = c(2023L, 2023L, 2023L, 2023L, 2022L, 2023L),
    ambas = c(TRUE, TRUE, TRUE, FALSE, TRUE, TRUE),
    razon_compra_prescripcion_minimo = c(0.5, 1.5, 4, 0, 9, 9)
  )
  res <- resumen_compra_prescripcion_clave(por_clave, "ISSSTE", 2023L)
  expect_identical(res$campo, "ISSSTE 2023")
  # Median of 0.5, 1.5 and 4 (the mean would be 2).
  expect_match(res$valor, "^3 claves con compra y prescripción del mismo año; .*: 1\\.50$")
})
