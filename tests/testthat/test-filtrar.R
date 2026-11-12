claves_univ <- c("010.000.0001.00", "010.000.0002.00")

base_filtro <- filas(
  fila(id_registro = "A"),
  fila(id_registro = "B", comparable = FALSE),
  fila(id_registro = "C", clave_cnis = "099.000.9999.00"),
  fila(id_registro = "D", año_fiscal = 2019L),
  fila(id_registro = "E", año_fiscal = 2027L),
  fila(id_registro = "F", notas_metodologicas = "[X] | [ENTRADA_DE_ALMACEN] nota"),
  fila(id_registro = "G", notas_metodologicas = "[MENUDEO_FARMACIA]"),
  fila(id_registro = "H", canal = "hospitalario"),
  fila(id_registro = "I", notas_metodologicas = "[ENTRADA_ALMACEN]")
)

ids <- function(lectura) {
  filtrar_lectura(base_filtro, claves_univ, lectura)$id_registro
}

test_that("the base reading keeps comparable rows in the universe only", {
  expect_identical(ids(nueva_lectura()), c("A", "D", "E", "F", "G", "H", "I"))
})

test_that("periodo restricts fiscal years", {
  expect_identical(ids(nueva_lectura(periodo = "2024_2027")),
                   c("A", "E", "F", "G", "H", "I"))
  expect_identical(ids(nueva_lectura(periodo = "solo_2025")),
                   c("A", "F", "G", "H", "I"))
  expect_error(nueva_lectura(periodo = "2030"))
})

test_that("each switch drops only its rows", {
  expect_identical(ids(nueva_lectura(excluir_entrada_almacen_hgm = TRUE)),
                   c("A", "D", "E", "G", "H", "I"))
  expect_identical(ids(nueva_lectura(excluir_menudeo = TRUE)),
                   c("A", "D", "E", "F", "H", "I"))
  expect_identical(ids(nueva_lectura(solo_ambulatorio = TRUE)),
                   c("A", "D", "E", "F", "G", "I"))
})

test_that("switches combine", {
  lectura <- nueva_lectura(periodo = "solo_2025", excluir_menudeo = TRUE,
                           solo_ambulatorio = TRUE,
                           excluir_entrada_almacen_hgm = TRUE)
  expect_identical(ids(lectura), c("A", "I"))
})

test_that("the almacén tag set is configurable", {
  datos <- filtrar_lectura(base_filtro, claves_univ,
                           nueva_lectura(excluir_entrada_almacen_hgm = TRUE),
                           etiquetas_almacen = c("[ENTRADA_DE_ALMACEN]",
                                                 "[ENTRADA_ALMACEN]"))
  expect_false(any(c("F", "I") %in% datos$id_registro))
})

test_that("exact duplicates collapse to the first row of each group", {
  datos <- filas(
    fila(id_registro = "A"),
    fila(id_registro = "B"),                      # identical to A
    fila(id_registro = "C"),                      # identical to A
    fila(id_registro = "D", id_procedimiento = NA_character_),
    fila(id_registro = "E", id_procedimiento = NA_character_),  # same as D
    fila(id_registro = "F", fecha_documento = "2025-01-01"),    # differs
    fila(id_registro = "G", tipo_institucion = "ISSSTE")        # not a key field
  )
  res <- filtrar_lectura(datos, claves_univ,
                         nueva_lectura(excluir_duplicados_exactos = TRUE))
  expect_identical(res$id_registro, c("A", "D", "F"))
  sin <- filtrar_lectura(datos, claves_univ, nueva_lectura())
  expect_equal(nrow(sin), 7)
})

test_that("asignar_grupos labels and scopes each comparison", {
  datos <- filas(
    fila(tipo_institucion = "IMSS"),
    fila(tipo_institucion = "ISSSTE"),
    fila(tipo_institucion = "IMSS-Bienestar"),
    fila(tipo_institucion = "Institutos nacionales"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Colima",
         tipo_institucion = "Servicios estatales de salud")
  )
  expect_identical(asignar_grupos(datos, "imss_issste")$grupo, c("IMSS", "ISSSTE"))
  expect_equal(nrow(asignar_grupos(datos, "tres_federales")), 3)
  expect_equal(nrow(asignar_grupos(datos, "federal_todas")), 4)
  expect_identical(asignar_grupos(datos, "entidades")$grupo, "Colima")
  expect_identical(unique(asignar_grupos(datos, "federal_vs_estatal")$grupo),
                   c("Federal (agrupado)", "Colima"))
})

# Biannual cycle (decision of 2026-11-08) ------------------------------------

ciclo_25 <- "[X] | [CICLO_BIANUAL] El ciclo 25.26 cubre dos ejercicios"
base_ciclo <- filas(
  fila(id_registro = "F25", notas_metodologicas = ciclo_25),
  fila(id_registro = "F24", año_fiscal = 2024L, notas_metodologicas =
         "[CICLO_BIANUAL] La vigencia del pedido cubre 2024 a 2025: se imputa al primer año."),
  fila(id_registro = "F27", año_fiscal = 2027L,
       notas_metodologicas = "[CICLO_BIANUAL] El ciclo 27.28 cubre dos ejercicios"),
  fila(id_registro = "N25"),
  # A state row is never carried, tagged or not.
  fila(id_registro = "E25", orden_gobierno = "estatal",
       entidad_federativa = "Colima", notas_metodologicas = ciclo_25)
)

test_that("a cycle price is copied once into the cycle's second year", {
  res <- filtrar_lectura(base_ciclo, claves_univ, nueva_lectura(),
                         arrastre_ciclo = TRUE)
  copias <- filter(res, ciclo_arrastrado)
  expect_identical(copias$id_registro, c("F25", "F24", "F27"))
  expect_identical(copias$año_fiscal, c(2026L, 2025L, 2028L))
  expect_identical(res$id_registro[!res$ciclo_arrastrado], base_ciclo$id_registro)
  # Without the switch: no copy, no new column.
  sin <- filtrar_lectura(base_ciclo, claves_univ, nueva_lectura())
  expect_identical(sin$id_registro, base_ciclo$id_registro)
  expect_false("ciclo_arrastrado" %in% names(sin))
})

test_that("the period filter reads each copy in the year it is carried to", {
  solo_2025 <- filtrar_lectura(base_ciclo, claves_univ,
                               nueva_lectura(periodo = "solo_2025"),
                               arrastre_ciclo = TRUE)
  expect_identical(solo_2025$id_registro[solo_2025$ciclo_arrastrado], "F24")
  hasta_2027 <- filtrar_lectura(base_ciclo, claves_univ,
                                nueva_lectura(periodo = "2024_2027"),
                                arrastre_ciclo = TRUE)
  expect_identical(hasta_2027$id_registro[hasta_2027$ciclo_arrastrado],
                   c("F25", "F24"))
})

test_that("a cycle that does not start in the row's year stops the run", {
  mal <- fila(notas_metodologicas = "[CICLO_BIANUAL] El ciclo 24.25 cubre")
  expect_error(
    filtrar_lectura(mal, claves_univ, nueva_lectura(), arrastre_ciclo = TRUE),
    "no empieza en su año fiscal"
  )
  # Numbers outside the tag segment are not read as the cycle.
  bien <- fila(notas_metodologicas = "importe 29.65 | [CICLO_BIANUAL] El ciclo 25.26")
  expect_no_error(
    filtrar_lectura(bien, claves_univ, nueva_lectura(), arrastre_ciclo = TRUE)
  )
})

test_that("canal keeps only the channel named (hospital annex)", {
  res <- filtrar_lectura(base_filtro, claves_univ, nueva_lectura(),
                         canal = "hospitalario")
  expect_identical(res$id_registro, "H")
})

test_that("periodo 2019_2026 (context series) drops fiscal 2027", {
  expect_identical(ids(nueva_lectura(periodo = "2019_2026")),
                   c("A", "D", "F", "G", "H", "I"))
})

test_that("periodo 2024_2025 (headline) keeps fiscal 2024 and 2025 only", {
  datos <- filas(
    fila(id_registro = "a23", año_fiscal = 2023L),
    fila(id_registro = "a24", año_fiscal = 2024L),
    fila(id_registro = "a25", año_fiscal = 2025L),
    fila(id_registro = "a26", año_fiscal = 2026L)
  )
  res <- filtrar_lectura(datos, claves_univ, nueva_lectura(periodo = "2024_2025"))
  expect_identical(res$id_registro, c("a24", "a25"))
})

# Channel override of the insulins (Andrés, 2026-11-08) -----------------------

insulina <- "010.000.4158.00"
base_canal <- filas(
  fila(id_registro = "i1", clave_cnis = insulina, canal = "hospitalario"),
  fila(id_registro = "i2", clave_cnis = insulina, canal = "hospitalario",
       comparable = FALSE),
  fila(id_registro = "i3", clave_cnis = insulina, canal = "hospitalario",
       orden_gobierno = "estatal", entidad_federativa = "Colima",
       año_fiscal = 2023L),
  fila(id_registro = "i4", clave_cnis = insulina, orden_gobierno = "estatal",
       entidad_federativa = "Colima"),
  fila(id_registro = "o1", canal = "hospitalario")
)

test_that("the override lists the three insulin keys", {
  expect_setequal(unname(config$claves_canal_ambulatorio),
                  c("010.000.4158.00", "010.000.1050.00", "010.000.1051.00"))
  expect_true(lectura_principal$reclasificar_canal)
})

test_that("reclasificar_canal reads the listed keys as ambulatory, nothing else", {
  res <- reclasificar_canal(base_canal, insulina)
  expect_identical(res$canal, c(rep("ambulatorio", 4), "hospitalario"))
  expect_identical(res$canal_base, base_canal$canal)
  expect_identical(select(res, -canal, -canal_base),
                   select(base_canal, -canal))
})

test_that("with the override an insulin enters the headline and leaves the annex", {
  base <- filas(
    fila(clave_cnis = insulina, canal = "hospitalario"),
    fila(clave_cnis = insulina, orden_gobierno = "estatal",
         entidad_federativa = "Colima")
  )
  lee <- function(b) {
    calcular_lectura(b, insulina, lectura_base, "federal_vs_estatal")$comparadas
  }
  expect_false(lee(base)$comparada_mismo_año)
  expect_true(lee(reclasificar_canal(base, insulina))$comparada_mismo_año)
  # No hospital row is left: the empty summaries warn (min of nothing).
  anexo <- suppressWarnings(
    anexo_canal(reclasificar_canal(base, insulina), insulina)
  )
  expect_equal(nrow(anexo$claves), 0)
  expect_equal(nrow(anexo_canal(base, insulina)$claves), 1)
})

test_that("filas_reclasificadas counts moved rows per key and side", {
  claves <- c("insulina glargina" = insulina, "insulina humana" = "010.000.1050.00")
  res <- filas_reclasificadas(reclasificar_canal(base_canal, claves), claves)
  expect_identical(res$clave_cnis, rep(unname(claves), each = 2))
  expect_identical(res$orden_gobierno, rep(c("federal", "estatal"), 2))
  expect_identical(res$componente, rep(names(claves), each = 2))
  expect_identical(res$canal_base, c("hospitalario", "hospitalario", "", ""))
  # i1 and i2 federal (one comparable, in 2025); i3 state comparable in 2023.
  expect_identical(res$filas, c(2L, 1L, 0L, 0L))
  expect_identical(res$filas_comparables, c(1L, 1L, 0L, 0L))
  expect_identical(res$filas_comparables_periodo_principal, c(1L, 0L, 0L, 0L))
  texto <- resumen_reclasificacion(res)
  expect_identical(texto$campo[1], paste(insulina, "federal"))
  expect_match(texto$valor[1], "^insulina glargina: 1 filas comparables de canal hospitalario leídas como ambulatorio \\(1 en 2024-2025\\); 2 filas")
  expect_match(texto$valor[2], "^insulina glargina: 1 filas comparables .*\\(0 en 2024-2025\\); 1 filas")
})
