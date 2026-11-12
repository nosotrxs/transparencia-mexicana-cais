# One-off: converts the Banxico SIE download of the general INPC (series SP1)
# into a plain CSV the analysis reads, so the analysis does not depend on the
# xlsx living in another project.
# Input:  banxico-sie-sp1-inpc-mensual-1969-2026.xlsx (evolucion-sistema-salud
#         project, read-only). Path below, overridable with TM_INPC_XLSX.
# Output: datos/inpc_general_mensual.csv (fecha, año, mes, inpc) and
#         datos/LEEME_inpc.md (provenance).
#
# Run from the "Analisis precios" folder:  Rscript R/01_preparar_inpc.R

suppressMessages({
  library(dplyr)
  library(readr)
})

if (!file.exists("R/config.R")) {
  stop("Corre este script desde la carpeta 'Analisis precios'.", call. = FALSE)
}

ruta_xlsx <- Sys.getenv(
  "TM_INPC_XLSX",
  unset = paste0(
    "/home/castanedaprado/OneDrive/Documentos/Trabajo/evolucion-sistema-salud/",
    "fuentes/descargas-2026-10-05-imss/banxico-sie-sp1-inpc-mensual-1969-2026.xlsx"
  )
)
dir_datos <- "datos"

# Everything as text first: the header block mixes labels and values.
crudo <- readxl::read_excel(ruta_xlsx, sheet = 1, col_names = FALSE,
                            col_types = "text", .name_repair = "minimal")
names(crudo) <- c("a", "b")

# Header block: label in column A, value in column B, up to the "Fecha" row.
fila_fecha <- which(crudo$a == "Fecha")
stopifnot(length(fila_fecha) == 1)
encabezado <- crudo[seq_len(fila_fecha), ]
dato_encabezado <- function(etiqueta) {
  valor <- encabezado$b[encabezado$a %in% etiqueta]
  stopifnot(length(valor) == 1)
  valor
}
fecha_consulta <- grep("^Fecha de consulta", encabezado$a, value = TRUE)
procedencia <- list(
  institucion = encabezado$a[1],
  fecha_consulta = sub("^Fecha de consulta:\\s*", "", fecha_consulta),
  titulo = dato_encabezado("Título"),
  periodo_disponible = dato_encabezado("Periodo disponible"),
  periodicidad = dato_encabezado("Periodicidad"),
  cifra = dato_encabezado("Cifra"),
  unidad = dato_encabezado("Unidad"),
  base = dato_encabezado("Base"),
  id_serie = dato_encabezado("Fecha")
)

# Data rows: Excel date serial (first of month) and the index value.
inpc <- crudo[-seq_len(fila_fecha), ] |>
  filter(!is.na(a)) |>
  transmute(
    fecha = as.Date(as.numeric(a), origin = "1899-12-30"),
    año = as.integer(format(fecha, "%Y")),
    mes = as.integer(format(fecha, "%m")),
    inpc = as.numeric(b)
  )

# Checks on the series itself.
meses_esperados <- seq(min(inpc$fecha), max(inpc$fecha), by = "month")
stopifnot(
  !anyNA(inpc),
  all(format(inpc$fecha, "%d") == "01"),
  identical(inpc$fecha, meses_esperados),
  min(inpc$fecha) == as.Date("1969-01-01"),
  max(inpc$fecha) == as.Date("2026-08-01")
)
# The base is the second half of July 2018 = 100, so the monthly July 2018
# value (mean of both halves) must sit just below 100.
julio_2018 <- inpc$inpc[inpc$fecha == as.Date("2018-07-01")]
stopifnot(julio_2018 > 99.5, julio_2018 <= 100)

dir.create(dir_datos, showWarnings = FALSE)
ruta_csv <- file.path(dir_datos, "inpc_general_mensual.csv")
write_csv(inpc, ruta_csv)

sha_xlsx <- unname(tools::sha256sum(ruta_xlsx))
sha_csv <- unname(tools::sha256sum(ruta_csv))
leeme <- c(
  "# INPC general mensual",
  "",
  "Insumo para deflactar precios a pesos de 2025 en el análisis de precios. Lo genera `R/01_preparar_inpc.R`; el análisis solo lee el CSV.",
  "",
  "## Archivo fuente",
  "",
  paste0("- Ruta: `", ruta_xlsx, "`"),
  paste0("- sha256: `", sha_xlsx, "`"),
  paste0("- Institución (encabezado): ", procedencia$institucion),
  paste0("- Fecha de consulta (encabezado): ", procedencia$fecha_consulta,
         "; la carpeta de descarga es del 2026-10-05"),
  "- El archivo pertenece al proyecto `evolucion-sistema-salud`; no se modifica.",
  "",
  "## Serie",
  "",
  paste0("- Identificador: ", procedencia$id_serie),
  paste0("- Título: ", procedencia$titulo),
  paste0("- Periodo disponible: ", procedencia$periodo_disponible),
  paste0("- Periodicidad: ", procedencia$periodicidad),
  paste0("- Cifra: ", procedencia$cifra, "; unidad: ", procedencia$unidad),
  paste0("- Periodo base: ", procedencia$base,
         " (segunda quincena de julio de 2018 = 100)"),
  "",
  "## CSV",
  "",
  paste0("- Archivo: `", ruta_csv, "`; sha256: `", sha_csv, "`"),
  "- Columnas: `fecha` (primer día del mes), `año`, `mes`, `inpc`.",
  paste0("- Rango: ", format(min(inpc$fecha)), " a ", format(max(inpc$fecha)),
         ", ", nrow(inpc), " meses consecutivos, sin faltantes."),
  paste0("- Comprobación: julio de 2018 vale ", julio_2018,
         ", justo debajo de 100, como corresponde a una base en la segunda quincena de ese mes."),
  "- 2026 solo tiene enero a agosto. El análisis usa el promedio de los meses disponibles y lo marca con `inpc_meses`."
)
writeLines(leeme, file.path(dir_datos, "LEEME_inpc.md"), useBytes = FALSE)

message("INPC: ", nrow(inpc), " meses, ", format(min(inpc$fecha)), " a ",
        format(max(inpc$fecha)), ". Julio 2018 = ", julio_2018)
message("Escrito ", normalizePath(ruta_csv))
