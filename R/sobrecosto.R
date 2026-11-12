# State overcost against the federal reference (definition approved by Andrés,
# 2026-11-08): method of PODER's 2021 project «Salud, dinero y corrupción»,
# adapted. Over the state rows of the headline reading that have a federal
# reference in the same fiscal year,
#   overcost of a row = max(0, (state price - reference) x state quantity),
# where the reference is the headline indicator: the quantity-weighted median
# of the pooled federal group of that key and year, carried biannual-cycle
# prices included exactly as brecha_federal_estatal() uses them. Quantities
# are boxes (cantidad_envases, the minimum quantity of an open contract).
# Variants for the LEEME summary only: other references, the maximum quantity
# of open contracts, and the formula applied inside the federal group.

# Rows that can enter the computation: positive price and quantity. `filas`
# carry .precio and .cantidad (con_precios(), indicadores.R).
filas_sobrecosto_validas <- function(filas, columna_precio) {
  filas |>
    con_precios(columna_precio) |>
    dplyr::filter(!is.na(.precio), .precio > 0, !is.na(.cantidad), .cantidad > 0)
}

# Reference price per key x year over `filas` with `fn(precio, cantidad)`.
referencia_por_clave_año <- function(filas, fn) {
  filas |>
    dplyr::summarise(referencia = fn(.precio, .cantidad),
                     .by = c(clave_cnis, año_fiscal)) |>
    dplyr::filter(!is.na(referencia))
}

# Row-level overcost of `objetivo` rows against `referencia` (clave_cnis,
# año_fiscal, referencia). Rows without a reference drop out. `cantidad` names
# the quantity column the overcost multiplies (.cantidad, or the maximum).
sobrecosto_filas <- function(objetivo, referencia, cantidad = ".cantidad") {
  objetivo |>
    dplyr::inner_join(referencia, by = c("clave_cnis", "año_fiscal")) |>
    dplyr::mutate(
      gasto = .precio * .cantidad,
      sobrecosto = pmax(0, (.precio - referencia) * .data[[cantidad]])
    )
}

# The headline computation. `filas` = rows of the headline reading with the
# biannual-cycle copies (filtrar_lectura(lectura_base, arrastre_ciclo = TRUE)).
# Returns the row-level table (one row per state purchase with a reference).
sobrecosto_estatal_filas <- function(filas, columna_precio = config$columna_precio) {
  validas <- filas_sobrecosto_validas(filas, columna_precio)
  federal <- dplyr::filter(validas, orden_gobierno %in% "federal")
  # Cycle copies are federal rows only, so no state row is a copy.
  estatal <- dplyr::filter(validas, orden_gobierno %in% "estatal")
  sobrecosto_filas(estatal, referencia_por_clave_año(federal, mediana_ponderada))
}

# Output table: total, by year, by state and by key, with the state spending
# compared (price x quantity), the overcost and its share. Same columns as the
# provisional file it replaces (nivel, nombre, componente, ...).
tabla_sobrecosto_estatal <- function(por_fila, universo, periodo = lectura_base$periodo) {
  resumir <- function(datos, nivel, ...) {
    datos |>
      dplyr::summarise(gasto_estatal_comparado_mxn = sum(gasto),
                       sobrecosto_mxn = sum(sobrecosto), .by = c(...)) |>
      dplyr::mutate(nivel = nivel, .before = 1)
  }
  total <- resumir(por_fila, "total") |>
    dplyr::mutate(nombre = etiqueta_periodo(periodo))
  años <- resumir(por_fila, "año", año_fiscal) |>
    dplyr::arrange(año_fiscal) |>
    dplyr::mutate(nombre = as.character(año_fiscal))
  entidades <- resumir(por_fila, "entidad", entidad_federativa) |>
    dplyr::arrange(dplyr::desc(sobrecosto_mxn)) |>
    dplyr::rename(nombre = entidad_federativa)
  claves <- resumir(por_fila, "clave", clave_cnis) |>
    dplyr::arrange(dplyr::desc(sobrecosto_mxn)) |>
    dplyr::left_join(dplyr::select(universo, clave_cnis, componente),
                     by = "clave_cnis") |>
    dplyr::rename(nombre = clave_cnis)
  dplyr::bind_rows(total, años, entidades, claves) |>
    dplyr::transmute(
      nivel, nombre, componente = dplyr::coalesce(componente, ""),
      gasto_estatal_comparado_mxn = round(gasto_estatal_comparado_mxn, 2),
      sobrecosto_mxn = round(sobrecosto_mxn, 2),
      parte_del_gasto = round(sobrecosto_mxn / gasto_estatal_comparado_mxn, 4)
    )
}

# Variants, totals only (LEEME):
# (a) reference = federal quantity-weighted average (copies included);
# (b) reference = quantity-weighted average of all purchases of the key and
#     year, federal and state (purchases only: no cycle copies);
# (c) headline reference, overcost on the maximum quantity of open contracts
#     (cantidad_maxima_envases, else the minimum);
# (d) the formula inside the federal group (copies included), each federal row
#     against the weighted average of its own key-year group.
sobrecosto_variantes <- function(filas, columna_precio = config$columna_precio) {
  validas <- filas_sobrecosto_validas(filas, columna_precio)
  copia <- es_copia_ciclo(validas)
  federal <- dplyr::filter(validas, orden_gobierno %in% "federal")
  estatal <- validas[validas$orden_gobierno %in% "estatal" & !copia, ]
  compras <- validas[validas$orden_gobierno %in% c("federal", "estatal") & !copia, ]
  # Maximum quantity where an open contract has a positive one, else the minimum.
  estatal <- dplyr::mutate(
    estatal,
    .cantidad_max = dplyr::if_else(
      !is.na(cantidad_maxima_envases) & cantidad_maxima_envases > 0,
      cantidad_maxima_envases, .cantidad
    )
  )
  ref_mediana <- referencia_por_clave_año(federal, mediana_ponderada)
  ref_media <- referencia_por_clave_año(federal, media_ponderada)
  total <- function(x, nombre, ambito = "estatal") {
    tibble::tibble(variante = nombre, ambito = ambito, filas = nrow(x),
                   gasto = sum(x$gasto), sobrecosto = sum(x$sobrecosto))
  }
  dplyr::bind_rows(
    total(sobrecosto_filas(estatal, ref_mediana), "principal"),
    total(sobrecosto_filas(estatal, ref_media), "a"),
    total(sobrecosto_filas(estatal, referencia_por_clave_año(compras, media_ponderada)), "b"),
    total(sobrecosto_filas(estatal, ref_mediana, cantidad = ".cantidad_max"), "c"),
    total(sobrecosto_filas(federal, ref_media), "d", ambito = "federal")
  ) |>
    dplyr::mutate(parte = sobrecosto / gasto)
}

# LEEME rows: the headline total, each year, and the four variants.
resumen_sobrecosto <- function(tabla, variantes, seccion = "Sobrecosto estatal") {
  fmt <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
  pct <- function(x) sprintf("%.1f %%", 100 * x)
  linea <- function(sobrecosto, gasto) {
    sprintf("%s de %s (%s)", fmt(sobrecosto), fmt(gasto), pct(sobrecosto / gasto))
  }
  v <- function(id) variantes[variantes$variante == id, ]
  base <- dplyr::filter(tabla, nivel %in% c("total", "año"))
  textos_v <- c(
    a = "referencia = promedio ponderado federal del mismo año",
    b = "referencia = promedio ponderado de todas las compras, federales y estatales, de la clave y el año",
    c = "referencia principal; cantidad máxima de los contratos abiertos en lugar de la mínima",
    d = "misma fórmula dentro del grupo federal, contra su propio promedio ponderado"
  )
  tibble::tibble(
    seccion = seccion,
    campo = c("definicion", "filas_estatales",
              paste0("sobrecosto_", base$nombre),
              paste0("variante_", names(textos_v))),
    valor = c(
      "Sobrecosto de una fila estatal = max(0, (precio por caja - referencia federal) x cantidad en cajas); referencia = mediana ponderada por cantidad del grupo federal agrupado de la clave y el año (indicador principal, con el precio del ciclo bianual arrastrado). Filas estatales de la lectura principal con referencia federal, precio y cantidad positivos. Método de PODER (2021), adaptado. Detalle por año, entidad y clave en la hoja sobrecosto_estatal.",
      as.character(v("principal")$filas),
      linea(base$sobrecosto_mxn, base$gasto_estatal_comparado_mxn),
      purrr::map_chr(names(textos_v), \(id) {
        x <- v(id)
        sprintf("%s: %s; %d filas %s", textos_v[[id]],
                linea(x$sobrecosto, x$gasto), x$filas,
                if (x$ambito == "federal") "federales (con las copias del ciclo bianual)" else "estatales")
      })
    )
  )
}
