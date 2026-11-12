test_that("brecha IMSS-ISSSTE: medians, ratio, difference and flags", {
  datos <- filas(
    # Clave 1, 2025: shared procedure P-1, identical price sets.
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 100),
    fila(tipo_institucion = "ISSSTE", precio_unitario_envase_mxn = 100),
    # Clave 2, 2025: different procedures, different prices.
    fila(clave_cnis = "010.000.0002.00", tipo_institucion = "IMSS",
         precio_unitario_envase_mxn = 50, id_procedimiento = "P-9"),
    fila(clave_cnis = "010.000.0002.00", tipo_institucion = "IMSS",
         precio_unitario_envase_mxn = 70, id_procedimiento = "P-9"),
    fila(clave_cnis = "010.000.0002.00", tipo_institucion = "ISSSTE",
         precio_unitario_envase_mxn = 90, id_procedimiento = NA_character_),
    # Clave 3: IMSS only, must not appear.
    fila(clave_cnis = "010.000.0003.00", tipo_institucion = "IMSS")
  )
  res <- brecha_imss_issste(datos, "precio_unitario_envase_mxn")
  expect_equal(nrow(res), 2)
  c1 <- filter(res, clave_cnis == "010.000.0001.00")
  c2 <- filter(res, clave_cnis == "010.000.0002.00")
  expect_true(c1$mismo_procedimiento)
  expect_true(c1$precio_identico)
  expect_equal(c1$razon_issste_imss, 1)
  expect_identical(c1$procedimientos_compartidos, "P-1")
  expect_equal(c2$mediana_imss, 60)
  expect_equal(c2$mediana_issste, 90)
  # Per-row median, kept as sensitivity (the principal ratio is below).
  expect_equal(c2$razon_issste_imss_mediana, 1.5)
  expect_equal(c2$diferencia_issste_menos_imss_mediana, 30)
  # Principal: weighted median. Equal quantities on IMSS 50 and 70, so the
  # half-weight boundary picks 50: ratio 90 / 50, difference 40.
  expect_equal(c2$mediana_ponderada_cantidad_imss, 50)
  expect_equal(c2$razon_issste_imss, 1.8)
  expect_equal(c2$diferencia_issste_menos_imss, 40)
  expect_false(c2$mismo_procedimiento)
  expect_false(c2$precio_identico)
})

test_that("precio_identico compares sets, not row counts", {
  datos <- filas(
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10),
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10),
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 20),
    fila(tipo_institucion = "ISSSTE", precio_unitario_envase_mxn = 20),
    fila(tipo_institucion = "ISSSTE", precio_unitario_envase_mxn = 10)
  )
  expect_true(brecha_imss_issste(datos, "precio_unitario_envase_mxn")$precio_identico)
})

test_that("brecha federal-estatal uses the pooled federal median of the year", {
  datos <- filas(
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10),
    fila(tipo_institucion = "Institutos nacionales", precio_unitario_envase_mxn = 30),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40, año_fiscal = 2022L)
  )
  res <- brecha_federal_estatal(datos, "precio_unitario_envase_mxn")
  r25 <- filter(res, año_fiscal == 2025L)
  expect_equal(r25$mediana_federal, 20)
  expect_equal(r25$razon_estatal_federal_mediana, 2)
  # Principal: weighted median, equal quantities on 10 and 30 -> 10.
  expect_equal(r25$mediana_ponderada_cantidad_federal, 10)
  expect_equal(r25$razon_estatal_federal, 4)
  expect_true(is.na(filter(res, año_fiscal == 2022L)$mediana_federal))
})

test_that("dispersion counts rows above 2x and 5x the clave-year median", {
  precios <- c(10, 10, 10, 25, 60)
  datos <- purrr::map(precios, \(p) fila(precio_unitario_envase_mxn = p)) |>
    bind_rows()
  res <- dispersion_por_clave(datos, "precio_unitario_envase_mxn")$por_clave
  expect_equal(res$mediana, 10)
  expect_equal(res$filas_sobre_2x_mediana_año, 2)
  expect_equal(res$filas_sobre_5x_mediana_año, 1)
  expect_equal(res$razon_max_min, 6)
  expect_equal(res$p90, unname(quantile(precios, 0.9)))
})

test_that("cobertura lists every universe key, with zeros", {
  universo <- tibble(clave_cnis = c("010.000.0001.00", "010.000.0009.00"),
                     componente = c("A", "B"), area = "Diabetes")
  datos <- filas(fila(), fila(tipo_institucion = "ISSSTE"), fila())
  res <- cobertura(datos, universo)$tipo_institucion
  expect_equal(nrow(res), 2)
  expect_equal(res$IMSS, c(2L, 0L))
  expect_equal(res$total, c(3, 0))
})

test_that("serie_real_por_clave pools each side per year, nominal and real", {
  factores <- tibble(año = c(2024L, 2025L), inpc_anual = c(100, 120),
                     inpc_meses = 12L, factor_deflacion = c(1.2, 1))
  datos <- filas(
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10),
    fila(tipo_institucion = "ISSSTE", precio_unitario_envase_mxn = 30),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40),
    fila(orden_gobierno = "estatal", entidad_federativa = "Jalisco",
         precio_unitario_envase_mxn = 60),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 50, año_fiscal = 2024L)
  ) |>
    deflactar_precios(factores)
  res <- serie_real_por_clave(datos, "precio_unitario_envase_mxn")
  expect_identical(res$año_fiscal, c(2024L, 2025L))
  expect_equal(res$n_filas_federal, c(NA, 2))
  expect_equal(res$mediana_federal, c(NA, 20))
  expect_equal(res$mediana_estatal, c(50, 50))
  expect_equal(res$mediana_estatal_real_2025, c(60, 50))

  brecha <- brecha_federal_estatal(datos, "precio_unitario_envase_mxn")
  expect_identical(brecha$con_federal_mismo_año, c(FALSE, TRUE, TRUE))
  expect_equal(brecha$mediana_estatal_real_2025, c(60, 40, 60))
})

test_that("brecha federal-estatal: no federal quantity means no principal pair", {
  datos <- filas(
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10,
         cantidad_envases = NA_real_),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40)
  )
  res <- brecha_federal_estatal(datos, "precio_unitario_envase_mxn")
  expect_false(res$con_federal_mismo_año)
  expect_true(is.na(res$razon_estatal_federal))
  expect_equal(res$razon_estatal_federal_mediana, 4)
  expect_equal(res$n_sin_cantidad_federal, 1L)
})

test_that("sensibilidad counts on the principal indicator, with *_mediana", {
  base <- filas(
    fila(cantidad_envases = NA_real_),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima")
  )
  grilla <- tibble(comparacion = "federal_vs_estatal", periodo = "todo",
                   excluir_entrada_almacen_hgm = FALSE,
                   excluir_duplicados_exactos = FALSE,
                   excluir_menudeo = c(FALSE, TRUE), solo_ambulatorio = FALSE)
  res <- tabla_sensibilidad(base, "010.000.0001.00", grilla = grilla)
  expect_identical(res$indicador, rep("mediana_ponderada_cantidad", 2))
  expect_equal(res$claves_comparadas_mismo_año, c(0L, 0L))
  expect_equal(res$claves_comparadas_mismo_año_mediana, c(1L, 1L))
  expect_equal(res$filas_sin_cantidad, c(1L, 1L))
})

test_that("sensibilidad: excluir_menudeo changes the weighted reading", {
  menudeo <- "[MENUDEO_FARMACIA]"
  base <- filas(
    fila(cantidad_envases = 1),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         notas_metodologicas = menudeo)
  )
  grilla <- tibble(comparacion = "federal_vs_estatal", periodo = "todo",
                   excluir_entrada_almacen_hgm = FALSE,
                   excluir_duplicados_exactos = FALSE,
                   excluir_menudeo = c(FALSE, TRUE), solo_ambulatorio = FALSE)
  res <- tabla_sensibilidad(base, "010.000.0001.00", grilla = grilla)
  expect_equal(res$claves_comparadas_mismo_año, c(1L, 0L))
})

test_that("serie_real_por_clave carries the weighted median per side", {
  datos <- filas(
    fila(tipo_institucion = "IMSS", precio_unitario_envase_mxn = 10,
         cantidad_envases = 9),
    fila(tipo_institucion = "ISSSTE", precio_unitario_envase_mxn = 30,
         cantidad_envases = 1),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40)
  )
  res <- serie_real_por_clave(datos, "precio_unitario_envase_mxn")
  expect_equal(res$mediana_federal, 20)
  expect_equal(res$mediana_ponderada_cantidad_federal, 10)
  expect_equal(res$mediana_ponderada_cantidad_estatal, 40)
  expect_equal(res$n_sin_cantidad_estatal, 0L)
})

test_that("dispersion flags rows against the weighted clave-year median too", {
  # Weighted median 10 (quantity 8 of 11); per-row median 25.
  datos <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 8),
    fila(precio_unitario_envase_mxn = 25, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 25, cantidad_envases = 1),
    fila(precio_unitario_envase_mxn = 60, cantidad_envases = 1)
  )
  res <- dispersion_por_clave(datos, "precio_unitario_envase_mxn")$por_clave
  expect_equal(res$mediana_ponderada_cantidad, 10)
  expect_equal(res$filas_sobre_2x_mediana_año, 1)
  expect_equal(res$filas_sobre_2x_mediana_ponderada_año, 3)
  expect_equal(res$filas_sobre_5x_mediana_ponderada_año, 1)
})

test_that("medianas_sin_menudeo: same rows as medianas, retail-only groups kept", {
  menudeo <- "[MENUDEO_FARMACIA]"
  claves <- c("010.000.0001.00", "010.000.0002.00")
  base <- filas(
    # Federal, clave 1: mixed group. With retail the weighted median is 10
    # (quantity 6 of 10); without retail only 30 and 50 remain -> 30.
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 6,
         notas_metodologicas = menudeo),
    fila(precio_unitario_envase_mxn = 30, cantidad_envases = 3),
    fila(precio_unitario_envase_mxn = 50, cantidad_envases = 1),
    # Colima, clave 1: retail only.
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40, notas_metodologicas = menudeo),
    # Federal, clave 2: no retail, one row without quantity.
    fila(clave_cnis = "010.000.0002.00", precio_unitario_envase_mxn = 20),
    fila(clave_cnis = "010.000.0002.00", precio_unitario_envase_mxn = 80,
         cantidad_envases = NA_real_)
  )
  con <- calcular_lectura(base, claves, lectura_base, "federal_vs_estatal")$medianas |>
    mutate(comparacion = "federal_vs_estatal", .before = 1)
  res <- medianas_sin_menudeo(base, claves, con, lectura = lectura_base)

  expect_equal(nrow(res), nrow(con))
  expect_identical(select(res, comparacion, clave_cnis, grupo, año_fiscal),
                   select(con, comparacion, clave_cnis, grupo, año_fiscal))
  expect_true(all(names(con) %in% names(res)))

  mixto <- filter(res, clave_cnis == claves[1], grupo == etiqueta_federal)
  expect_equal(mixto$n_filas, 2L)
  expect_equal(mixto$mediana_ponderada_cantidad, 30)
  expect_equal(mixto$mediana_ponderada_cantidad_con_menudeo, 10)
  expect_equal(mixto$razon_sin_entre_con, 3)
  expect_equal(mixto$mediana, 40)

  solo_menudeo <- filter(res, grupo == "Colima")
  expect_equal(solo_menudeo$n_filas, 0L)
  expect_equal(solo_menudeo$n_sin_cantidad, 0L)
  expect_true(is.na(solo_menudeo$mediana))
  expect_true(is.na(solo_menudeo$mediana_ponderada_cantidad))
  expect_equal(solo_menudeo$mediana_ponderada_cantidad_con_menudeo, 40)
  expect_true(is.na(solo_menudeo$razon_sin_entre_con))

  sin_menudeo <- filter(res, clave_cnis == claves[2])
  expect_equal(sin_menudeo$n_filas, 2L)
  expect_equal(sin_menudeo$n_sin_cantidad, 1L)
  expect_equal(sin_menudeo$mediana_ponderada_cantidad, 20)
  expect_equal(sin_menudeo$razon_sin_entre_con, 1)
})

test_that("medianas_sin_menudeo: ratio is NA when the value with retail is NA", {
  base <- filas(fila(cantidad_envases = NA_real_))
  con <- calcular_lectura(base, "010.000.0001.00", lectura_base,
                          "federal_vs_estatal")$medianas |>
    mutate(comparacion = "federal_vs_estatal", .before = 1)
  res <- medianas_sin_menudeo(base, "010.000.0001.00", con, lectura = lectura_base)
  expect_equal(res$n_filas, 1L)
  expect_true(is.na(res$mediana_ponderada_cantidad_con_menudeo))
  expect_true(is.na(res$razon_sin_entre_con))
  expect_equal(res$mediana, 100)
})

test_that("brecha federal-estatal: the second-year reference pools cycle and own rows", {
  ciclo <- "[CICLO_BIANUAL] El ciclo 25.26 cubre"
  base <- filas(
    fila(precio_unitario_envase_mxn = 10, cantidad_envases = 6,
         notas_metodologicas = ciclo),
    fila(precio_unitario_envase_mxn = 30, cantidad_envases = 4,
         año_fiscal = 2026L),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         precio_unitario_envase_mxn = 40, año_fiscal = 2026L)
  )
  datos <- filtrar_lectura(base, "010.000.0001.00", lectura_contexto,
                           arrastre_ciclo = TRUE)
  res <- brecha_federal_estatal(datos, "precio_unitario_envase_mxn")
  r26 <- filter(res, año_fiscal == 2026L)
  # 2026: the cycle row (6 at 10) and the 2026 row (4 at 30) -> 10.
  expect_equal(r26$n_filas_federal, 2L)
  expect_equal(r26$n_filas_federal_ciclo_arrastrado, 1L)
  expect_true(r26$federal_con_ciclo_arrastrado)
  expect_equal(r26$mediana_ponderada_cantidad_federal, 10)
  expect_equal(r26$razon_estatal_federal, 4)
  r25 <- filter(res, año_fiscal == 2025L)
  expect_equal(r25$n_filas_federal, 1L)
  expect_false(r25$federal_con_ciclo_arrastrado)
  # Tables with one row per award do not see the copy.
  serie <- serie_real_por_clave(
    filtrar_lectura(base, "010.000.0001.00", lectura_contexto),
    "precio_unitario_envase_mxn"
  )
  expect_equal(serie$n_filas_federal, c(1, 1))
  expect_equal(serie$mediana_ponderada_cantidad_federal, c(10, 30))
})

test_that("sensibilidad marks the principal row against lectura_base", {
  base <- filas(fila(), fila(orden_gobierno = "estatal",
                             entidad_federativa = "Colima"))
  grilla <- tibble(comparacion = "federal_vs_estatal",
                   periodo = c("2024_2025", "2024_2025", "solo_2025", "2019_2026"),
                   excluir_entrada_almacen_hgm = FALSE,
                   excluir_duplicados_exactos = FALSE,
                   excluir_menudeo = FALSE,
                   solo_ambulatorio = c(FALSE, TRUE, TRUE, TRUE))
  res <- tabla_sensibilidad(base, "010.000.0001.00", grilla = grilla)
  # The headline is fiscal 2024-2025, ambulatory only; 2025 alone and the
  # context period are not.
  expect_identical(res$lectura_principal, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(res$parametros_distintos_a_base, c(1L, 0L, 1L, 1L))
})

test_that("sensibilidad applies the cycle rule without counting copies", {
  base <- filas(
    fila(notas_metodologicas = "[CICLO_BIANUAL] El ciclo 25.26 cubre"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         año_fiscal = 2026L)
  )
  grilla <- tibble(comparacion = "federal_vs_estatal",
                   periodo = c("todo", "solo_2025"),
                   excluir_entrada_almacen_hgm = FALSE,
                   excluir_duplicados_exactos = FALSE,
                   excluir_menudeo = FALSE, solo_ambulatorio = TRUE)
  res <- tabla_sensibilidad(base, "010.000.0001.00", grilla = grilla)
  expect_equal(res$filas_usadas, c(2L, 1L))
  expect_equal(res$claves_comparadas_mismo_año, c(1L, 0L))
})
