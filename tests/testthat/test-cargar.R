escribir_fixture_csv <- function(claves) {
  ruta <- tempfile(fileext = ".csv")
  datos <- purrr::map(rlang::set_names(columnas_base), \(x) rep("", length(claves)))
  datos <- tibble::as_tibble(datos)
  datos$clave_cnis <- claves
  datos$comparable <- "TRUE"
  datos$año_fiscal <- "2025"
  datos$cantidad_envases <- "10"
  datos$precio_unitario_envase_mxn <- "5.5"
  datos$monto_partida_mxn <- "55"
  # A quoted field with a newline inside, as in the real base.
  datos$descripcion_original <- "línea uno\nlínea dos"
  readr::write_csv(datos, ruta, na = "")
  ruta
}

test_that("keys with leading zeros survive the read as character", {
  claves <- c("010.000.0042.00", "040.000.0001.01")
  base <- leer_base(escribir_fixture_csv(claves))
  expect_type(base$clave_cnis, "character")
  expect_identical(base$clave_cnis, claves)
  expect_type(base$precio_unitario_envase_mxn, "double")
  expect_type(base$año_fiscal, "integer")
  expect_type(base$comparable, "logical")
  expect_identical(base$descripcion_original, rep("línea uno\nlínea dos", 2))
})

test_that("a missing column stops the loader", {
  ruta <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(clave_cnis = "010.000.0042.00"), ruta)
  expect_error(leer_base(ruta), "Faltan columnas")
})

test_that("validar_base rejects a comparable row without price", {
  base <- fila(precio_unitario_envase_mxn = NA_real_)
  expect_error(validar_base(base), "sin precio_unitario_envase_mxn")
  expect_silent(validar_base(fila()))
})

test_that("validar_anclas stops when an anchor does not match", {
  universo <- tibble::tibble(clave_cnis = "010.000.0001.00", componente = "X",
                             area = "Diabetes")
  base <- filas(fila(), fila(tipo_institucion = "ISSSTE"))
  ok <- list(filas = 2, claves_imss_issste = 1)
  expect_true(all(validar_anclas(base, universo, ok, "[X]")$coincide))
  mal <- list(filas = 3)
  expect_error(capture.output(validar_anclas(base, universo, mal, "[X]")),
               "no reproduce las anclas")
})
