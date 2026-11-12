# Supply orders of the SSA platform (R/entregas.R). Tiny hand-made orders;
# the real 827 MB file is never read here.

ka <- "010.000.0001.00"
kb <- "010.000.0002.00"
kc <- "010.000.0003.00"
# 43 keys like the real universe: ka and kb have orders, the other 41 do not.
claves_43 <- c(ka, kb, sprintf("010.000.9%03d.00", 1:41))
universo_e <- tibble(clave_cnis = claves_43,
                     componente = paste("Comp", seq_along(claves_43)),
                     area = rep(c("Diabetes", "Salud mental"), length.out = 43))

# One order with neutral defaults, as read from ordenes_suministro.csv.
orden <- function(...) {
  defaults <- list(clave = ka, institucion = "IMSS", licitacion = "LA-1",
                   estatus = "COMPLETA", fecha_solicitud = "2025-03-01",
                   piezas_solicitadas = 10, proveedor = "Prov A",
                   piezas_entregadas = 10, canceladas_activas = "ACTIVA")
  as_tibble(utils::modifyList(defaults, list(...)))
}

# Key a: complete 100/100 (Prov B), incomplete 50 asked / 20 delivered
# (Prov A, ISSSTE, 2026), failed 30 (Prov A, procedure LA-2), and one
# cancelled complete order of 5 / 5. Key b: in transit 40 and in validation 60,
# nothing delivered. Key c is outside the universe.
ordenes_e <- bind_rows(
  orden(piezas_solicitadas = 100, piezas_entregadas = 100, proveedor = "Prov B"),
  orden(estatus = "INCOMPLETA", piezas_solicitadas = 50, piezas_entregadas = 20,
        institucion = "ISSSTE", fecha_solicitud = "2026-01-15"),
  orden(estatus = "INCUMPLIDA", piezas_solicitadas = 30, piezas_entregadas = 0,
        licitacion = "LA-2"),
  orden(piezas_solicitadas = 5, piezas_entregadas = 5,
        canceladas_activas = "CANCELADA", proveedor = "Prov C",
        licitacion = "LA-9"),
  orden(clave = kb, estatus = "EN TRÁNSITO", piezas_solicitadas = 40,
        piezas_entregadas = 0),
  orden(clave = kb, estatus = "VALIDACIÓN ENTREGA", piezas_solicitadas = 60,
        piezas_entregadas = 0, licitacion = " la-2 "),
  orden(clave = kc, piezas_solicitadas = 999, piezas_entregadas = 999)
) |>
  preparar_ordenes(claves_43)

# Price-side tables as the run builds them (only the columns used).
razon_e <- tibble(nivel = c("eje", "clave"), area = "Diabetes",
                  clave_cnis = c("", ka), componente = "", pares = c(9L, 3L),
                  razon_estatal_federal_mediana = c(2, 2.5))
sobrecosto_e <- tibble(nivel = c("total", "clave"), nombre = c("2024-2025", ka),
                       componente = "", gasto_estatal_comparado_mxn = c(500, 500),
                       sobrecosto_mxn = c(100, 100), parte_del_gasto = c(0.2, 0.2))
comparadas_e <- tibble(comparacion = "federal_vs_estatal",
                       comparacion_principal = TRUE, clave_cnis = claves_43,
                       comparada_principal = claves_43 == ka)

test_that("preparar_ordenes keeps universe keys and flags cancellations", {
  expect_identical(nrow(ordenes_e), 6L)
  expect_false(kc %in% ordenes_e$clave)
  expect_identical(sum(ordenes_e$cancelada), 1L)
  expect_identical(sort(unique(ordenes_e$año)), c(2025L, 2026L))
  expect_error(preparar_ordenes(orden(estatus = "OTRO"), ka), "sin categoría")
  expect_error(preparar_ordenes(orden(canceladas_activas = "X"), ka),
               "canceladas_activas")
})

test_that("volume per key: active orders only, cancelled counted apart", {
  v <- volumen_entregas(ordenes_e, "clave") |> arrange(clave)
  a <- v[v$clave == ka, ]
  expect_identical(a$ordenes, 3L)
  expect_equal(a$piezas_solicitadas, 180)
  expect_equal(a$piezas_entregadas, 120)
  expect_equal(a$pct_entregado, round(120 / 180, 4))
  expect_identical(a$canceladas_ordenes, 1L)
  expect_equal(a$canceladas_piezas_solicitadas, 5)
  expect_equal(a$canceladas_piezas_entregadas, 5)
  # LA-9 belongs to the cancelled order only; Prov C too.
  expect_identical(a$procedimientos, 2L)
  expect_identical(a$proveedores, 2L)
})

test_that("estatus pivot: five columns that add up to requested pieces", {
  v <- volumen_entregas(ordenes_e, "clave") |> arrange(clave)
  columnas <- paste0("piezas_solicitadas_", unname(categorias_estatus))
  expect_true(all(columnas %in% names(v)))
  a <- v[v$clave == ka, ]
  b <- v[v$clave == kb, ]
  expect_equal(unlist(a[columnas], use.names = FALSE), c(100, 50, 0, 30, 0))
  expect_equal(unlist(b[columnas], use.names = FALSE), c(0, 0, 40, 0, 60))
  expect_equal(rowSums(v[columnas]), v$piezas_solicitadas)
  # Categories absent from the data still get their column, with zeros.
  solo_b <- volumen_entregas(filter(ordenes_e, clave == kb), "clave")
  expect_true(all(columnas %in% names(solo_b)))
  expect_equal(solo_b$piezas_solicitadas_completa, 0)
})

test_that("pct_entregado is NA when nothing was requested", {
  # Key b delivered nothing: 0 %, not NA. A group with only cancelled orders
  # requested nothing active: NA, not 0 or NaN.
  v <- volumen_entregas(ordenes_e, "clave")
  expect_equal(v$pct_entregado[v$clave == kb], 0)
  solo_cancelada <- volumen_entregas(filter(ordenes_e, cancelada), "clave")
  expect_true(is.na(solo_cancelada$pct_entregado))
  expect_identical(solo_cancelada$ordenes, 0L)
  expect_equal(porcentaje(c(1, 0, 3), c(2, 0, 0)), c(0.5, NA, NA))
})

test_that("main supplier: most delivered pieces, ties alphabetical, NA if none", {
  # Key a: Prov B 100 vs Prov A 20 (the cancelled Prov C does not count).
  p <- proveedor_principal(filter(ordenes_e, !cancelada), "clave")
  expect_identical(p$proveedor_principal[p$clave == ka], "Prov B")
  expect_equal(p$proveedor_principal_parte[p$clave == ka], round(100 / 120, 4))
  expect_true(is.na(p$proveedor_principal[p$clave == kb]))
  empate <- bind_rows(orden(proveedor = "Zeta", piezas_entregadas = 7),
                      orden(proveedor = "Alfa", piezas_entregadas = 7)) |>
    preparar_ordenes(ka)
  p2 <- proveedor_principal(empate, "clave")
  expect_identical(p2$proveedor_principal, "Alfa")
  expect_equal(p2$proveedor_principal_parte, 0.5)
})

test_that("entregas_por_clave keeps the 43 keys and joins the price side", {
  t <- entregas_por_clave(ordenes_e, universo_e, razon_e, sobrecosto_e,
                          comparadas_e)
  expect_identical(nrow(t), 43L)
  expect_setequal(t$clave_cnis, claves_43)
  expect_identical(sum(t$en_plataforma), 2L)
  vacia <- t[t$clave_cnis == claves_43[10], ]
  expect_false(vacia$en_plataforma)
  expect_equal(vacia$ordenes, 0)
  expect_equal(vacia$piezas_solicitadas_completa, 0)
  expect_true(is.na(vacia$pct_entregado))
  expect_true(is.na(vacia$proveedor_principal))
  a <- t[t$clave_cnis == ka, ]
  expect_identical(a$eje, "Diabetes")
  expect_equal(a$razon_estatal_federal_mediana, 2.5)
  expect_identical(a$pares, 3L)
  expect_true(a$comparada_principal)
  expect_equal(a$sobrecosto_mxn, 100)
  expect_equal(a$sobrecosto_parte_del_gasto, 0.2)
  expect_identical(t$pares[t$clave_cnis == kb], 0L)
  # A key missing from claves_comparadas counts as not compared.
  t2 <- entregas_por_clave(ordenes_e, universo_e, razon_e, sobrecosto_e,
                           filter(comparadas_e, clave_cnis != kb))
  expect_false(t2$comparada_principal[t2$clave_cnis == kb])
  expect_true(is.na(t$sobrecosto_mxn[t$clave_cnis == kb]))
})

test_that("tables by institution and by year", {
  i <- entregas_por_clave_y(ordenes_e, universo_e, "institucion")
  expect_identical(nrow(i), 3L)
  issste <- i[i$clave_cnis == ka & i$institucion == "ISSSTE", ]
  expect_equal(issste$piezas_solicitadas_incompleta, 50)
  expect_equal(issste$pct_entregado, 0.4)
  y <- entregas_por_clave_y(ordenes_e, universo_e, "año")
  expect_equal(y$piezas_solicitadas[y$clave_cnis == ka & y$año == 2025L], 130)
  expect_equal(y$piezas_solicitadas[y$clave_cnis == ka & y$año == 2026L], 50)
})

test_that("procedure cross: orders whose licitacion is in the price base", {
  base_e <- filas(fila(id_procedimiento = "LA-2"), fila(id_procedimiento = NA),
                  fila(id_procedimiento = ""), fila(id_procedimiento = "LA-9"))
  x <- entregas_cruce_procedimientos(ordenes_e, base_e, universo_e)
  expect_identical(nrow(x), 43L)
  a <- x[x$clave_cnis == ka, ]
  # Key a: only the failed order (LA-2, 30 pieces) matches; LA-9 is cancelled.
  expect_equal(a$ordenes, 3)
  expect_equal(a$ordenes_con_procedimiento_en_base, 1)
  expect_equal(a$piezas_solicitadas_con_procedimiento_en_base, 30)
  expect_equal(a$piezas_entregadas_con_procedimiento_en_base, 0)
  expect_equal(a$parte_ordenes, round(1 / 3, 4))
  expect_equal(a$parte_piezas_entregadas, 0)
  # Key b: " la-2 " matches after trimming and upper-casing.
  b <- x[x$clave_cnis == kb, ]
  expect_equal(b$piezas_solicitadas_con_procedimiento_en_base, 60)
  expect_true(is.na(b$parte_piezas_entregadas))
  expect_true(is.na(x$parte_ordenes[x$clave_cnis == claves_43[10]]))
})

test_that("control compares every order row with the supplier tab", {
  cumpl <- tibble(clave = c(ka, ka, kb), solicitadas = c(185, 1, 100),
                  entregadas = c(125, 0, 0))
  ctl <- entregas_control(ordenes_e, cumpl, universo_e)
  expect_identical(nrow(ctl), 43L)
  a <- ctl[ctl$clave_cnis == ka, ]
  expect_equal(a$filas_ordenes, 4)
  expect_equal(a$solicitadas_ordenes, 185)
  expect_equal(a$diferencia_filas, -2)
  expect_equal(a$diferencia_solicitadas, 1)
  expect_equal(a$diferencia_entregadas, 0)
  expect_equal(ctl$diferencia_solicitadas[ctl$clave_cnis == kb], 0)
})

test_that("missing orders file: the step is skipped with a message", {
  falta <- file.path(tempdir(), "no_existe_ordenes.csv")
  expect_message(
    res <- calcular_entregas(falta, falta, universo_e, filas(fila()),
                             razon_e, sobrecosto_e, comparadas_e),
    "se omiten"
  )
  expect_identical(res, list())
  r <- resumen_entregas(res, falta)
  expect_identical(nrow(r), 1L)
  expect_match(r$valor, "Omitido")
})

test_that("reads a tiny CSV; missing supplier tab drops only the control", {
  ruta <- tempfile(fileext = ".csv")
  readr::write_csv(bind_rows(orden(), orden(clave = kc)) |>
                     mutate(descripcion = "x", .after = clave), ruta)
  falta <- file.path(tempdir(), "no_existe_cumplimiento.csv")
  expect_message(
    res <- calcular_entregas(ruta, falta, universo_e, filas(fila()),
                             razon_e, sobrecosto_e, comparadas_e),
    "entregas_control"
  )
  expect_setequal(names(res), c("entregas_por_clave",
                                "entregas_por_clave_institucion",
                                "entregas_por_clave_año",
                                "entregas_cruce_procedimientos"))
  expect_equal(sum(res$entregas_por_clave$piezas_entregadas), 10)
  expect_identical(nrow(resumen_entregas(res, ruta)), 7L)
})
