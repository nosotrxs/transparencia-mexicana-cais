# Writing the tables: one UTF-8 CSV per table and one workbook with a sheet
# per table plus a LEEME sheet.

descripciones_hojas <- c(
  medianas = "Serie de contexto 2019-2026. Precio por clave x grupo x año fiscal, las cinco comparaciones apiladas: mediana ponderada por cantidad (indicador principal), mediana por fila (sensibilidad), mínimo, máximo y media ponderada por cantidad, en pesos nominales y en pesos de 2025 (sufijo _real_2025), con el factor de deflación y los meses de INPC del año. n_sin_cantidad cuenta las filas sin cantidad utilizable (vacía, cero o negativa), que no entran en la ponderación.",
  medianas_sin_menudeo = "Sensibilidad de precios sin menudeo de farmacia: las mismas filas y columnas que medianas (cada comparación x clave x grupo x año), calculadas con los filtros de la serie de contexto 2019-2026 pero sin las filas [MENUDEO_FARMACIA]. mediana_ponderada_cantidad_con_menudeo repite el indicador principal de medianas y razon_sin_entre_con = sin menudeo / con menudeo (vacía si falta alguno de los dos). Los grupos cuyas filas eran todas de menudeo aparecen con n_filas = 0 y precios vacíos.",
  claves_comparadas = "Por comparación y clave: grupos con mediana ponderada por cantidad y si la clave queda comparada en la serie de contexto 2019-2026, agrupando el periodo (comparada_agrupado) o dentro de un mismo año fiscal (comparada_mismo_año, con los años en años_comparados). comparada_principal aplica la regla del mismo año a los años fiscales 2024 y 2025, los de las cifras titulares: cada par se compara dentro de su año y la clave cuenta si queda comparada en 2024 o en 2025 (años_comparados dice en cuál). En federal_vs_estatal se exige el grupo federal agrupado (columna grupo_requerido) y el precio del ciclo bianual cuenta también en el segundo año del ciclo (nota ciclo_bianual). La cifra titular de claves comparadas son las filas con comparacion_principal = TRUE y comparada_principal = TRUE. Las columnas con sufijo _mediana repiten la regla con la mediana por fila (sensibilidad).",
  sensibilidad = "Rejilla completa comparación x periodo (todo, 2019_2026, 2024_2027, 2024_2025, solo_2025) x los cuatro interruptores (400 filas): filas usadas, filas sin cantidad, claves con precio, claves con mediana ponderada, grupos, claves comparadas (agrupado y mismo año) con el indicador principal (columna indicador) y si alcanza el umbral; las columnas con sufijo _mediana repiten el conteo con la mediana por fila. excluir_menudeo = FALSE/TRUE da la lectura con y sin menudeo de farmacia. Las filas federal_vs_estatal aplican la regla del grupo federal requerido y la del ciclo bianual; filas_usadas no cuenta las copias de segundo año del ciclo. lectura_principal = TRUE marca la fila de la lectura principal (periodo 2024_2025); la fila equivalente con periodo solo_2025 es la lectura anterior y la de 2019_2026, la serie de contexto. Se calcula con las insulinas leídas como canal ambulatorio (nota reclasificacion_canal).",
  brecha_imss_issste = "Serie de contexto 2019-2026. Por clave x año con precio en IMSS e ISSSTE: medianas ponderadas por cantidad y medianas por fila de ambos, razón ISSSTE/IMSS y diferencia con el indicador principal (con sufijo _mediana, con la mediana por fila), procedimiento compartido y precios idénticos. Medianas y diferencias también en pesos de 2025.",
  brecha_federal_estatal = "Serie de contexto 2019-2026. Por clave x entidad x año: par_principal = TRUE marca los pares entidad-clave-año de los años fiscales 2024 y 2025 con indicador principal estatal y federal, los de las cifras titulares. Mediana ponderada por cantidad y mediana por fila, estatal y federal agrupada del mismo año, y razón estatal/federal con el indicador principal (razon_estatal_federal_mediana: con la mediana por fila); con_federal_mismo_año indica si hay indicador principal federal ese año. La referencia federal de un año incluye los precios del ciclo bianual adjudicados el año anterior (nota ciclo_bianual): n_filas_federal_ciclo_arrastrado cuenta esas filas y federal_con_ciclo_arrastrado = TRUE marca las filas que las usan. Medianas también en pesos de 2025.",
  dispersion_por_clave = "Por clave, los años 2019-2026 juntos: mediana ponderada por cantidad, mediana por fila, n, p10, p90, razón máx/mín y filas por encima de 2x y 5x la mediana de su clave-año, contadas contra la mediana por fila y contra la mediana ponderada. Versión en pesos de 2025 calculada sobre las filas con INPC (n_filas_con_inpc; excluye 2027).",
  dispersion_por_clave_año = "Igual que dispersion_por_clave, por clave x año fiscal, con el factor de deflación y los meses de INPC del año.",
  serie_real_por_clave = "Serie de contexto 2019-2026. Por clave x año fiscal: mediana ponderada por cantidad y mediana por fila, federal agrupada y estatal agrupada (todas las entidades juntas), con n filas y filas sin cantidad, en pesos nominales y de 2025. Sirve para comparar entre años.",
  cobertura_tipo_institucion = "Filas comparables por clave x tipo de institución, las 43 claves del universo, años fiscales 2019-2026.",
  cobertura_entidad = "Filas comparables por clave x entidad federativa, las 43 claves del universo, años fiscales 2019-2026.",
  anexo_canal_hospitalario = "Anexo, fuera de la lectura principal: la misma comparación que brecha_federal_estatal (federal agrupado contra cada entidad, mismo año, indicador principal, regla del ciclo bianual), calculada solo con las filas de canal hospitalario y los demás filtros de la lectura principal, años fiscales 2019-2026. par_principal = TRUE marca los pares de 2024 y 2025. Las insulinas no están: se leen como canal ambulatorio (nota reclasificacion_canal).",
  anexo_canal_hospitalario_claves = "Anexo, fuera de la lectura principal: por clave con filas de canal hospitalario, filas federales y estatales, pares entidad-año con referencia federal y la regla de clave comparada en 2019-2026 (agrupado y mismo año; con sufijo _mediana, con la mediana por fila) y en 2024-2025 (comparada_principal).",
  reclasificacion_canal = "Por clave de insulina y orden de gobierno, las filas que la base clasifica en otro canal (canal_base) y que esta capa lee como canal ambulatorio: todas, las comparables y las comparables de 2024-2025. La base no cambia.",
  cobertura_prescripcion = "Por clave (43): cajas prescritas en 2023 (año ISO) por el IMSS (Ordinario) y el ISSSTE según OCAMIS, parte de cada clave en el total de la institución sobre las 43 claves, si la clave queda comparada en la lectura principal (comparada_principal) y en cada año (comparada_2024, comparada_2025), y el motivo cuando no lo está. 2023 es el último año completo de OCAMIS.",
  compra_vs_prescripcion = "Revisión de cobertura de la base, no lectura de precios. Por institución y año (2019-2024): cajas prescritas en OCAMIS (43 claves; año ISO tomado como año fiscal; semanas_prescripcion dice cuántas semanas tiene el año) contra cajas compradas en filas comparables de la base, de cualquier canal y sin duplicado_de: con la cantidad mínima (cantidad_envases) y con la máxima donde un contrato abierto la trae. Claves con prescripción, con compra y con ambas; compra entre prescripción en las claves con ambas; compra como parte de todo lo prescrito. 2024 está incompleto en OCAMIS.",
  compra_vs_prescripcion_clave = "Revisión de cobertura de la base, no lectura de precios. Lo mismo que compra_vs_prescripcion, por institución x año (2019-2024) x clave: cajas prescritas en OCAMIS contra cajas compradas en el mismo año fiscal (filas comparables, de cualquier canal, sin duplicado_de), con la cantidad mínima y con la máxima donde un contrato abierto la trae. ambas = TRUE si la clave tiene cajas de los dos lados; razon_compra_prescripcion_minimo y _maximo = compradas / prescritas (vacías sin prescripción). Solo claves con cajas de algún lado. La sección Compra contra prescripción por clave de LEEME resume el ISSSTE en 2023.",
  razon_por_eje_y_clave = "Pares de la lectura principal (par_principal en brecha_federal_estatal, años fiscales 2024 y 2025): mediana de la razón estatal/federal por eje (nivel = eje: salud mental, diabetes) y por clave (nivel = clave), con el número de pares; cada par cuenta una vez.",
  sobrecosto_estatal = "Sobrecosto estatal frente a la referencia federal (método de PODER, 2021, adaptado). Filas estatales de la lectura principal (años fiscales 2024 y 2025, canal ambulatorio con las insulinas reclasificadas, precio y cantidad positivos) con referencia federal el mismo año. Sobrecosto de una fila = max(0, (precio por caja - referencia) x cajas, cantidad mínima); referencia = mediana ponderada por cantidad del grupo federal agrupado de la clave y el año, con el precio del ciclo bianual arrastrado (como en brecha_federal_estatal). Por nivel: total, año, entidad y clave; gasto estatal comparado (precio x cantidad), sobrecosto y parte del gasto. Variantes en la sección Sobrecosto estatal de LEEME.",
  cruce_marginacion_entidad = "Por entidad con pares de la lectura principal: pares, claves y mediana de la razón estatal/federal (brecha_mediana), índice de marginación 2020 de CONAPO (indice_marginacion_2020), índice normalizado (imn_2020) y grado, población de 3 años y más y hablantes de lengua indígena del Censo 2020 del INEGI (tabulado de etnicidad, hoja 02, sexo y edad Total) y su porcentaje (pct_hli).",
  cobertura_marginacion_entidad = "Las 32 entidades con su grado de marginación 2020 (CONAPO) y su cobertura de precios estatales, la primera categoría que aplica: Con pares (pares de la lectura principal); Con filas comparables, sin par (filas comparables en cobertura_entidad, serie 2019-2026, canal ambulatorio); Con filas, ninguna comparable (filas estatales en la base, ninguna comparable); Sin filas. filas_total cuenta todas las filas estatales de la base, comparables o no.",
  compra_2025_vs_presc_2023 = "Aproximación. Por institución y clave: la compra del año fiscal 2025 (ciclo consolidado 2025-2026) llevada a un año contra lo prescrito en 2023. Solo las filas con [CICLO_BIANUAL] se dividen entre dos; las filas sin etiqueta cuentan como están. Filas comparables, de cualquier canal, sin duplicado_de. Compara años distintos: sirve para ver el orden de magnitud, no para medir abasto.",
  entregas_por_clave = "Entregas de la compra consolidada federal (Plataforma de monitoreo de medicamentos de la Secretaría de Salud, ordenes_suministro.csv, solicitudes del 2025-01-06 al 2026-10-23; sin precios). Por clave (las 43): eje, en_plataforma (la clave tiene al menos una orden, activa o cancelada), órdenes activas, piezas solicitadas y entregadas, pct_entregado (entregadas / solicitadas; vacío si no se solicitó nada), piezas solicitadas por estatus (completa, incompleta, en tránsito, incumplida, en validación; suman piezas_solicitadas), órdenes canceladas con sus piezas solicitadas y entregadas (fuera de los demás conteos), procedimientos (licitacion) y proveedores distintos, proveedor principal por piezas entregadas (empate: orden alfabético) y su parte. Del lado de precios, de las tablas de esta corrida: pares y razon_estatal_federal_mediana (razon_por_eje_y_clave), comparada_principal (claves_comparadas) y gasto estatal comparado, sobrecosto y su parte (sobrecosto_estatal).",
  entregas_por_clave_institucion = "Las mismas columnas de volumen que entregas_por_clave, por clave x institución que solicita (IMSS, IMSS BIENESTAR, ISSSTE, CCINSHAE, etc.). Solo combinaciones con órdenes en la plataforma; sin columnas de precio.",
  entregas_por_clave_año = "Las mismas columnas de volumen que entregas_por_clave, por clave x año de fecha_solicitud (2025, 2026; 2026 llega al 23 de octubre). Solo combinaciones con órdenes; sin columnas de precio.",
  entregas_cruce_procedimientos = "Por clave (43): órdenes activas y sus piezas solicitadas y entregadas cuyo número de procedimiento (licitacion) aparece como id_procedimiento en alguna fila de la base de precios (coincidencia exacta tras quitar espacios y pasar a mayúsculas), en conteo y como parte. Dice para cuánto del volumen entregado hay un procedimiento con precio en la base.",
  entregas_control = "Control, no lectura: por clave (43), filas y piezas solicitadas y entregadas en ordenes_suministro.csv (todas las filas, canceladas incluidas, porque la pestaña de cumplimiento no marca la cancelación) contra cumplimiento_proveedores.csv, y la diferencia (cumplimiento menos órdenes). Las tablas de entregas usan ordenes_suministro.csv."
)

notas_leeme <- c(
  indicador_principal = "El precio de cada clave x grupo x año es la mediana del precio unitario ponderada por cantidad comprada (mediana_ponderada_cantidad), decidida por Edu el 2026-11-07 y aceptada por Andrés el mismo día. Convención: se ordenan las filas por precio y se toma el menor precio cuya cantidad acumulada alcanza al menos la mitad de la cantidad total. Las filas sin cantidad, con cantidad cero o negativa no entran en la ponderación y se cuentan en n_sin_cantidad; si ninguna fila del grupo tiene cantidad, el indicador queda vacío y el grupo no cuenta para la regla de clave comparada. La mediana por fila se conserva en todas las tablas como sensibilidad.",
  sensibilidad_menudeo = "La sensibilidad con y sin menudeo de farmacia ([MENUDEO_FARMACIA]) está en la hoja sensibilidad: filas con excluir_menudeo = FALSE (con menudeo) y TRUE (sin menudeo), con el indicador principal y, en las columnas _mediana, con la mediana por fila.",
  sensibilidad_menudeo_precios = "La hoja medianas_sin_menudeo da los precios sin las filas de menudeo de farmacia ([MENUDEO_FARMACIA]), en las mismas filas que medianas, con el indicador principal con menudeo al lado y la razón sin/con. Es sensibilidad: la lectura principal incluye el menudeo. Los grupos que solo tenían filas de menudeo quedan con n_filas = 0 y precios vacíos.",
  lectura_principal = "Federal contra estados (comparacion = federal_vs_estatal). Una clave cuenta como comparada cuando, en el mismo año fiscal, tiene mediana ponderada federal agrupada y mediana ponderada en al menos una entidad. La cifra titular es la de los años fiscales 2024 y 2025, cada par dentro de su año (comparada_principal); el conteo en cualquier año de 2019-2026 y el agrupado quedan como contexto. Las demás comparaciones y la rejilla completa siguen calculadas.",
  periodo = "Las cifras titulares son las de los años fiscales 2024 y 2025 (decisión de Andrés del 2026-11-08, como propuso Edu; sustituye a la de solo 2025). La regla sigue siendo la del mismo año: cada par entidad-clave se compara dentro de su año fiscal, y una clave cuenta como comparada si lo está en 2024 o en 2025. Dónde están: sección Resumen lectura principal de esta hoja (con el mismo bloque para 2024 solo y 2025 solo), fila lectura_principal de sensibilidad, comparada_principal en claves_comparadas y par_principal en brecha_federal_estatal. Las tablas por año cubren la serie de contexto 2019-2026. El año fiscal 2027 (ciclo federal 27.28) sigue en la base pero queda fuera de todas las tablas, salvo en la rejilla de sensibilidad (periodos todo y 2024_2027).",
  canal = "La lectura principal usa solo filas de canal ambulatorio (solo_ambulatorio = TRUE; decisión de Andrés del 2026-11-08, sobre la decisión (3) de Edu del 2026-11-07 en el diccionario). Las filas de canal hospitalario no se descartan: se comparan aparte en las hojas anexo_canal_hospitalario y anexo_canal_hospitalario_claves, nunca mezcladas con las tablas principales. Todas las tablas principales, incluida medianas, se calculan con este filtro; la hoja sensibilidad recorre también solo_ambulatorio = FALSE.",
  reclasificacion_canal = "Las tres claves de insulina (010.000.4158.00 insulina glargina; 010.000.1050.00 y 010.000.1051.00 insulina humana) se leen como canal ambulatorio, diga lo que diga la columna canal de la base, que clasifica como hospitalario casi todas sus filas federales: se dispensan en primer nivel de atención (decisión de Andrés del 2026-11-08). Entran en la lectura principal y salen del anexo hospitalario. La base no cambia; la lista está en config$claves_canal_ambulatorio y el interruptor en lectura_principal$reclasificar_canal. Filas movidas: sección Reclasificación de canal y hoja reclasificacion_canal. La lectura principal sin la reclasificación está en la sección Sensibilidad de esta hoja.",
  prescripcion_ocamis = "Comparador de calidad: cuánto de lo que prescriben el IMSS (Ordinario) y el ISSSTE capta la lectura, con las cajas prescritas en OCAMIS (hoja datos de ocamis_43_claves_semana_institucion_estado.xlsx; las cantidades son cajas, la misma unidad que cantidad_envases). OCAMIS termina a inicios de 2024, así que 2023 es el último año completo. La sección Cobertura de la prescripción da la parte del volumen prescrito en 2023 que corresponde a claves comparadas en la lectura principal; las hojas cobertura_prescripcion, compra_vs_prescripcion y compra_2025_vs_presc_2023 dan el detalle.",
  ciclo_bianual = "La compra consolidada federal adjudica un precio por ciclo de dos años (25.26 cubre 2025 y 2026); la base la registra una vez, en el primer año, con [CICLO_BIANUAL]. En la comparación federal contra estados (brecha_federal_estatal, claves_comparadas y sensibilidad en federal_vs_estatal, y el anexo hospitalario) ese precio también sirve de referencia federal en el segundo año del ciclo: la referencia federal de ese año junta las filas federales fechadas en él con las del ciclo, y la mediana ponderada se calcula sobre todas, cada una con su cantidad. Las demás tablas (medianas, serie_real_por_clave, dispersión, cobertura) conservan una fila por adjudicación: no se duplican filas, cantidades ni montos. Decisión de Andrés del 2026-11-08, sobre la decisión (4) de Edu del 2026-11-07.",
  contrato_abierto = "En contrato abierto ([CONTRATO_ABIERTO]) la ponderación usa la cantidad mínima adjudicada (cantidad_envases), no la máxima (cantidad_maxima_envases), como fija el diccionario de datos (columna 21). Confirmado por Andrés el 2026-11-08; el cálculo no cambió.",
  grupo_requerido = "La regla del grupo federal requerido se aplica a todas las filas federal_vs_estatal (claves_comparadas y sensibilidad): una clave con dos entidades y sin precio federal ese año no cuenta.",
  deflacion = "Pesos de 2025 con el INPC general (Banxico SIE, serie SP1). INPC anual = promedio de los meses disponibles del año calendario; factor = INPC 2025 / INPC del año; precio real = nominal x factor. 2026 solo tiene enero a agosto (inpc_meses = 8). El año fiscal 2027 no tiene INPC: su precio real queda vacío, nunca nominal.",
  razones = "Las razones y comparaciones dentro de un mismo año (razón ISSSTE/IMSS, razón estatal/federal, filas sobre 2x y 5x) son idénticas en pesos nominales y reales. Los precios reales solo importan al comparar entre años; las diferencias en pesos sí cambian."
)

tabla_leeme <- function(tablas, lectura, columna_precio, ruta_base, sha256,
                        fecha_corrida, anclas, principal = lectura_principal,
                        factores = NULL, ruta_inpc = NA_character_,
                        sha256_inpc = NA_character_, contexto = NULL,
                        resumen = NULL) {
  hojas <- tibble::tibble(
    seccion = "Hoja",
    campo = names(tablas),
    valor = unname(descripciones_hojas[names(tablas)])
  )
  principal_tbl <- tibble::tibble(
    seccion = "Lectura principal",
    campo = c("periodo", "indicador", "comparacion", "regla_comparada",
              "grupo_requerido", "ciclo_bianual_segundo_año", "canal",
              "reclasificar_canal", "sensibilidad"),
    valor = c(paste0(principal$filtros$periodo, " (cifras titulares); serie de ",
                     "contexto en las tablas por año: ",
                     contexto$periodo %||% principal$filtros$periodo),
              principal$indicador, principal$comparacion,
              principal$regla_comparada, principal$grupo_requerido,
              as.character(principal$ciclo_bianual_segundo_año),
              "solo ambulatorio; hospitalario en anexo_canal_hospitalario",
              paste0(isTRUE(principal$reclasificar_canal), " (claves leídas como ambulatorio: ",
                     paste(config$claves_canal_ambulatorio, collapse = ", "), ")"),
              "mediana por fila en todas las tablas; con y sin menudeo de farmacia: conteos en la hoja sensibilidad (excluir_menudeo) y precios en medianas_sin_menudeo")
  )
  parametros <- tibble::tibble(
    seccion = "Filtros de la lectura",
    campo = c(names(lectura), "columna_precio"),
    valor = c(vapply(lectura, as.character, character(1)), columna_precio)
  )
  parametros_contexto <- if (is.null(contexto)) {
    NULL
  } else {
    tibble::tibble(
      seccion = "Filtros de la serie de contexto",
      campo = names(contexto),
      valor = vapply(contexto, as.character, character(1))
    )
  }
  notas <- tibble::tibble(
    seccion = "Nota", campo = names(notas_leeme), valor = unname(notas_leeme)
  )
  insumo <- tibble::tibble(
    seccion = "Insumo",
    campo = c("archivo", "sha256", "fecha_corrida", "precios", "inpc_archivo",
              "inpc_sha256"),
    valor = c(ruta_base, sha256, fecha_corrida,
              "Nominales y en pesos de 2025 (sufijo _real_2025)",
              ruta_inpc, sha256_inpc)
  )
  deflactor <- if (is.null(factores)) {
    NULL
  } else {
    tibble::tibble(
      seccion = "Deflactor",
      campo = as.character(factores$año),
      valor = sprintf("INPC anual %.4f (%d meses); factor a 2025 %.6f",
                      factores$inpc_anual, factores$inpc_meses,
                      factores$factor_deflacion)
    )
  }
  verificacion <- tibble::tibble(
    seccion = "Ancla",
    campo = anclas$ancla,
    valor = paste0("esperado ", anclas$esperado, "; medido ", anclas$medido)
  )
  dplyr::bind_rows(hojas, principal_tbl, resumen, parametros,
                   parametros_contexto, notas, insumo, deflactor, verificacion)
}

escribir_csvs <- function(tablas, dir_salidas) {
  purrr::iwalk(tablas, \(tabla, nombre) {
    readr::write_csv(tabla, file.path(dir_salidas, paste0(nombre, ".csv")),
                     na = "")
  })
}

escribir_xlsx <- function(tablas, leeme, ruta) {
  libro <- openxlsx::createWorkbook()
  estilo_encabezado <- openxlsx::createStyle(
    textDecoration = "bold", border = "bottom"
  )
  hojas <- c(list(LEEME = leeme), tablas)
  purrr::iwalk(hojas, \(tabla, nombre) {
    openxlsx::addWorksheet(libro, nombre)
    openxlsx::writeData(libro, nombre, tabla, headerStyle = estilo_encabezado)
    openxlsx::freezePane(libro, nombre, firstRow = TRUE)
    openxlsx::setColWidths(libro, nombre, cols = seq_along(tabla),
                           widths = "auto")
  })
  openxlsx::saveWorkbook(libro, ruta, overwrite = TRUE)
}
