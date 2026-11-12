# State context: marginalisation, indigenous language and coverage
# (R/marginacion.R). Tiny hand-made files; the real ones are never read here.

estados <- sprintf("Estado %02d", 1:32)

marginacion_csv <- function() {
  ruta <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble(anio = 2020, cve_ent = 1:32, entidad = estados,
           im = 20 + (1:32) / 1000 + 0.00049, imn = 0.7 + (1:32) / 10000,
           grado_marginacion = rep(c("Muy bajo", "Bajo", "Medio", "Alto"), 8)),
    ruta
  )
  ruta
}

# A sheet laid out like the INEGI tabulation: title rows, a header block with
# the two labels in their own columns, then per state a Total x Total row and
# rows by sex and age that must be ignored.
censo_xlsx <- function(n_estados = 32) {
  # Columns: entity, sex, age, population 3+, indigenous-language speakers,
  # Spanish speakers (a distractor).
  encabezado <- rbind(
    c("INEGI. Censo 2020", NA, NA, NA, NA, NA),
    c("Entidad federativa", "Sexo", "Grupos quinquenales de edad",
      "Población de 3 años y más", "Condición de habla indígena", NA),
    c(NA, NA, NA, NA, "Habla lengua indígena", "Habla español"),
    c("Estados Unidos Mexicanos", "Total", "Total", "9", "9", "9")
  )
  estado <- function(i) {
    nombre <- sprintf("%02d Estado %02d", i, i)
    rbind(c(nombre, "Total", "Total", 1000 * i, 10 * i, 1),
          c(nombre, "Hombres", "Total", 1, 1, 1),
          c(nombre, "Total", "03-04 años", 1, 1, 1))
  }
  m <- do.call(rbind, c(list(encabezado), lapply(seq_len(n_estados), estado)))
  ruta <- tempfile(fileext = ".xlsx")
  libro <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(libro, "02")
  openxlsx::writeData(libro, "02", as.data.frame(m), colNames = FALSE)
  openxlsx::saveWorkbook(libro, ruta)
  ruta
}

test_that("leer_marginacion keeps 32 states with a two-digit code", {
  m <- leer_marginacion(marginacion_csv())
  expect_identical(nrow(m), 32L)
  expect_identical(m$cve_ent[c(1, 32)], c("01", "32"))
  expect_identical(names(m), c("cve_ent", "entidad", "im", "imn",
                               "grado_marginacion"))
  expect_error(leer_marginacion(tempfile()), "No existe")
})

test_that("leer_lengua_indigena reads Total x Total rows by header label", {
  l <- leer_lengua_indigena(censo_xlsx())
  expect_identical(nrow(l), 32L)
  expect_identical(l$cve_ent[1:2], c("01", "02"))
  expect_equal(l$pob_3ymas[1:2], c(1000, 2000))
  expect_equal(l$hablantes_lengua_indigena[1:2], c(10, 20))
  expect_error(leer_lengua_indigena(censo_xlsx(31)), "32 entidades")
})

brecha_m <- tibble(
  entidad_federativa = c("Estado 01", "Estado 01", "Estado 01", "Estado 02",
                         "Estado 03"),
  clave_cnis = c("k1", "k1", "k2", "k1", "k1"),
  razon_estatal_federal = c(1, 2.123456, 3, 0.5, NA),
  par_principal = c(TRUE, TRUE, TRUE, TRUE, FALSE)
)

test_that("cruce_marginacion: pairs, keys, median ratio and context", {
  m <- leer_marginacion(marginacion_csv())
  l <- leer_lengua_indigena(censo_xlsx())
  res <- cruce_marginacion(brecha_m, m, l)
  expect_identical(names(res), c(
    "entidad", "pares", "claves", "brecha_mediana", "indice_marginacion_2020",
    "imn_2020", "grado_marginacion_2020", "pob_3ymas",
    "hablantes_lengua_indigena", "pct_hli"
  ))
  # Estado 03 has no headline pair.
  expect_identical(res$entidad, c("Estado 01", "Estado 02"))
  expect_identical(res$pares, c(3L, 1L))
  expect_identical(res$claves, c(2L, 1L))
  expect_equal(res$brecha_mediana, c(2.1235, 0.5))
  expect_equal(res$indice_marginacion_2020, c(20.001, 20.002))
  expect_equal(res$imn_2020, c(0.7001, 0.7002))
  expect_equal(res$pct_hli, c(1, 1))
  mal <- mutate(brecha_m, entidad_federativa = "Otro")
  expect_error(cruce_marginacion(mal, m, l), "sin marginación")
})

test_that("cobertura_marginacion: first category that applies, 32 states", {
  m <- leer_marginacion(marginacion_csv())
  cruce <- tibble(entidad = "Estado 01", pares = 3L)
  base <- filas(
    fila(orden_gobierno = "estatal", entidad_federativa = "Estado 01"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Estado 02"),
    fila(orden_gobierno = "estatal", entidad_federativa = "Estado 03",
         comparable = FALSE),
    fila(orden_gobierno = "estatal", entidad_federativa = "Estado 03",
         comparable = FALSE),
    fila() # federal: not counted
  )
  cobertura_entidad <- tibble(clave_cnis = c("k1", "k2"), componente = "A",
                              area = "Diabetes", `Estado 01` = c(1L, 0L),
                              `Estado 02` = c(2L, 3L), total = c(3L, 3L))
  res <- cobertura_marginacion(base, cobertura_entidad, cruce, m)
  expect_identical(nrow(res), 32L)
  fila_de <- function(e) res[res$entidad == e, ]
  expect_identical(fila_de("Estado 01")$cobertura, "Con pares")
  expect_identical(fila_de("Estado 02")$cobertura, "Con filas comparables, sin par")
  expect_identical(fila_de("Estado 02")$filas_comparables, 5L)
  expect_identical(fila_de("Estado 03")$cobertura, "Con filas, ninguna comparable")
  expect_identical(fila_de("Estado 03")$filas_total, 2L)
  expect_identical(fila_de("Estado 04")$cobertura, "Sin filas")
  expect_identical(res$entidad[1:3], c("Estado 01", "Estado 02", "Estado 03"))
  expect_identical(names(res), c("cve_ent", "entidad", "grado_marginacion_2020",
                                 "filas_total", "filas_comparables", "pares",
                                 "cobertura"))
})
