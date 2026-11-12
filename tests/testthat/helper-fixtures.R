# Loads the analysis functions and builds small hand-made rows for the tests.
# testthat runs this file with tests/testthat as the working directory.

suppressMessages({
  library(dplyr)
  library(tibble)
})

for (archivo in c("config.R", "cargar.R", "filtrar.R", "deflactar.R",
                  "indicadores.R", "tablas.R", "anexos.R", "principal.R",
                  "ocamis.R", "sobrecosto.R", "marginacion.R",
                  "entregas.R", "exportar.R")) {
  source(file.path("..", "..", "R", archivo), encoding = "UTF-8")
}

# One comparable row with neutral defaults; override any column by name.
fila <- function(...) {
  defaults <- list(
    id_registro = "MED-0001",
    id_contrato_fuente = "C-1",
    id_procedimiento = "P-1",
    orden_gobierno = "federal",
    entidad_federativa = "Federal",
    institucion_compradora = "Inst",
    tipo_institucion = "IMSS",
    proveedor = "Prov",
    clave_cnis = "010.000.0001.00",
    canal = "ambulatorio",
    cantidad_envases = 10,
    cantidad_unidades_minimas = 100,
    precio_unitario_envase_mxn = 100,
    precio_por_unidad_minima_mxn = 10,
    monto_partida_mxn = 1000,
    año_fiscal = 2025L,
    fecha_documento = NA_character_,
    comparable = TRUE,
    notas_metodologicas = NA_character_
  )
  valores <- utils::modifyList(defaults, list(...))
  tibble::as_tibble(valores)
}

filas <- function(...) dplyr::bind_rows(...)
