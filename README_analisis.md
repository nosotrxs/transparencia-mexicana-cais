# Análisis de precios · TMX CAIS-T2-C1

Capa de análisis sobre la base de precios de medicamentos (43 claves CNIS de salud mental y diabetes). Las cifras titulares del informe son las de los años fiscales 2024 y 2025; las tablas por año dan la serie 2019-2026 como contexto. Un comparador con las recetas de OCAMIS mide cuánto de lo que prescriben el IMSS y el ISSSTE capta la lectura. Las definiciones metodológicas que siguen abiertas son parámetros: cada lectura se calcula lado a lado y la tabla `sensibilidad` las recorre todas. Precios en pesos nominales y en pesos de 2025.

## Lectura principal

Decidida el 2026-11-06 (comparación y regla), el 2026-11-07 (indicador) y el 2026-11-08 (canal, ciclo bianual, periodo y canal de las insulinas), y fijada en `lectura_principal` (`R/config.R`):

- Indicador: la mediana del precio ponderada por cantidad (`indicador = "mediana_ponderada_cantidad"`). La decidió Edu el 2026-11-07 y Andrés la aceptó el mismo día. La mediana por fila sigue en todas las tablas como sensibilidad; con y sin menudeo de farmacia, los conteos están en `sensibilidad` y los precios en `medianas_sin_menudeo`.
- Comparación federal contra estados (`federal_vs_estatal`).
- Una clave cuenta como «comparada» cuando, en el mismo año fiscal, tiene mediana ponderada federal agrupada y mediana ponderada en al menos una entidad. La cifra titular es la de 2024-2025: cada par entidad-clave se compara dentro de su año, y la clave cuenta si queda comparada en 2024 o en 2025. El conteo en cualquier año de 2019-2026 y el agrupado sobre esos años quedan como contexto.
- Ciclo bianual (`ciclo_bianual_segundo_año = TRUE`, decisión de Andrés del 2026-11-08): en la comparación federal contra estados, el precio federal de un ciclo bianual también es referencia federal en el segundo año del ciclo. Detalle en «Ciclo bianual».
- Filtros de filas (`lectura_base`): años fiscales 2024 y 2025 (`periodo = "2024_2025"`, decisión de Andrés del 2026-11-08, como propuso Edu; sustituye a `solo_2025`), solo canal ambulatorio (`solo_ambulatorio = TRUE`, decisión de Andrés del 2026-11-08), sin otras exclusiones. Las filas de canal hospitalario se comparan aparte, en el anexo (ver «Anexo de canal hospitalario»).
- Insulinas como canal ambulatorio (`reclasificar_canal = TRUE`, decisión de Andrés del 2026-11-08). Detalle en «Canal de las insulinas».

Los conteos de claves comparadas de cada corrida están en la tabla `sensibilidad` (la fila con `lectura_principal = TRUE`, y las filas con `excluir_menudeo` en `TRUE` para la lectura sin menudeo) y en la hoja `LEEME`, que registra la base usada. Los precios sin menudeo están en `medianas_sin_menudeo`.

## Cifras titulares (2024-2025) y serie de contexto (2019-2026)

Las cifras titulares son las de `lectura_base` (años fiscales 2024 y 2025). Las tablas por año usan `lectura_contexto` (`R/config.R`): los mismos filtros con `periodo = "2019_2026"`. Así cubren 2019 a 2026 `medianas`, `medianas_sin_menudeo`, `claves_comparadas` (columnas de contexto), `brecha_imss_issste`, `brecha_federal_estatal`, `dispersion_por_clave` y `dispersion_por_clave_año`, `serie_real_por_clave`, las dos tablas de cobertura y el anexo hospitalario. El año fiscal 2027 (22 filas federales del ciclo `27.28`) sigue en la base, pero queda fuera de esas tablas; solo lo ve la rejilla de `sensibilidad`, en los periodos `todo` y `2024_2027`.

Dónde está la cifra titular, sin recalcular (`R/principal.R`):

- `LEEME`, sección «Resumen lectura principal»: claves comparadas (de 43), pares entidad-clave-año (`pares_entidad_clave_año`), entidades con al menos un par, razón estatal/federal (mediana de los pares con el indicador principal, p25, p75, pares con razón mayor a 1, 2, 5 y 10, pares cuyo lado estatal descansa en una sola fila (`pares_con_una_fila_estatal`), y la mediana con la mediana por fila como sensibilidad) y pares cuya referencia federal usa un precio de ciclo arrastrado, primero para 2024-2025 y luego, con los mismos campos, para 2024 solo y 2025 solo (secciones «Resumen lectura principal: 2024» y «: 2025»; en cada año, una clave cuenta si tiene al menos un par ese año), y al final cada clave no comparada con su motivo. La sección «Sensibilidad: lectura principal sin reclasificar el canal de las insulinas» da el mismo resumen con el canal de la base, y «Resumen anexo hospitalario» lo mismo para el canal hospitalario.
- `sensibilidad`: la fila con `lectura_principal = TRUE` (periodo `2024_2025`); la de `solo_2025` es la lectura anterior.
- `claves_comparadas`: `comparada_principal` (y `comparada_principal_mediana`) aplica la regla del mismo año a 2024 y 2025. La cifra titular son las filas con `comparacion_principal = TRUE` y `comparada_principal = TRUE`; `años_comparados` dice en qué años; `comparada_mismo_año` y `comparada_agrupado` son la serie de contexto.
- `brecha_federal_estatal` y `anexo_canal_hospitalario`: `par_principal = TRUE` marca los pares entidad-clave-año de 2024 y 2025 con indicador principal en los dos lados. `anexo_canal_hospitalario_claves` lleva `comparada_principal`.
- `razon_por_eje_y_clave`: la mediana de la razón sobre esos pares por eje (salud mental, diabetes) y por clave, con el número de pares.

Motivos de clave no comparada, en este orden (el primero que aplica): sin filas comparables en la base; sin filas en 2024-2025 (en ningún canal; el precio de ciclo arrastrado cuenta como fila federal); solo filas de otro canal en 2024-2025; y, en el canal de la lectura, sin precio federal ni estatal, sin precio federal o sin precio estatal en 2024-2025, o los dos pero nunca en el mismo año. Si al lado que falta le quedan filas de otro canal, el motivo lo dice. Las razones se resumen sobre los pares, cada par cuenta una vez; los cuantiles son los de R por omisión (tipo 7).

La regla del grupo federal requerido se aplica a todas las filas `federal_vs_estatal`, también en `sensibilidad`, donde la columna `lectura_principal` marca la fila de esta lectura. Las demás comparaciones, incluidas las tablas IMSS-ISSSTE, siguen calculadas. Para quitar la regla en una corrida propia: `calcular_lectura(..., grupo_requerido = NULL)`.

## Indicadores

Por clave × grupo × año fiscal (`R/indicadores.R`), en pesos nominales y de 2025:

- `mediana_ponderada_cantidad` (indicador principal): se ordenan las filas por precio y se toma el menor precio cuya cantidad acumulada alcanza al menos la mitad de la cantidad total. La cantidad es la que corresponde a la columna de precio (`cantidad_envases` para el precio por envase, `cantidad_unidades_minimas` para el precio por unidad mínima). Las filas con cantidad vacía, cero o negativa no entran en la ponderación y se cuentan en `n_sin_cantidad`; si ninguna fila del grupo tiene cantidad, el indicador queda vacío y el grupo no cuenta para la regla de clave comparada.
- `mediana`: mediana por fila, sin ponderar (sensibilidad).
- `media_ponderada_cantidad`: media ponderada por cantidad, como referencia.

Donde una tabla elige «el» precio (razones, diferencias, la marca `con_federal_mismo_año` y la regla de clave comparada) usa el indicador de `lectura_principal$indicador`. La versión con la mediana por fila va en columnas con sufijo `_mediana`. Para cambiar el indicador en una corrida propia: `calcular_lectura(..., indicador = "mediana")`.

Contrato abierto (`[CONTRATO_ABIERTO]`): la ponderación usa la cantidad mínima adjudicada, `cantidad_envases`, como fija el diccionario (columna 21); la máxima (`cantidad_maxima_envases`) no entra. Andrés lo confirmó el 2026-11-08.

## Ciclo bianual

La compra consolidada federal adjudica un precio por ciclo de dos años (`25.26` cubre 2025 y 2026). La base registra cada adjudicación una vez, en el primer año, con `[CICLO_BIANUAL]` (diccionario, regla 1). En la comparación federal contra estados, cada fila federal con esa etiqueta se lee también en el año siguiente (`copias_segundo_año_ciclo()` en `R/filtrar.R`). La referencia federal de ese segundo año junta las filas federales fechadas en él con las del ciclo, y la mediana ponderada se calcula sobre todas, cada una con su cantidad.

Lo usan `brecha_federal_estatal`, la regla de clave comparada en `federal_vs_estatal` (`claves_comparadas` y `sensibilidad`) y el anexo de canal hospitalario. En `brecha_federal_estatal`, `n_filas_federal_ciclo_arrastrado` cuenta las filas del ciclo en la referencia y `federal_con_ciclo_arrastrado = TRUE` marca las filas que las usan. Las demás tablas (`medianas`, `medianas_sin_menudeo`, `serie_real_por_clave`, dispersión, cobertura) conservan una fila por adjudicación: no se duplican filas, cantidades ni montos.

El periodo se aplica después, sobre el año en que se lee cada fila: un precio de ciclo imputado a 2024 cuenta en 2025, uno de 2026 queda fuera de `2019_2026` en su segundo año, y uno de 2027 (ciclo `27.28`) queda fuera de `2024_2027`. Si el ciclo escrito en la etiqueta (`25.26`) no empieza en el año fiscal de la fila, el script se detiene. Para quitar la regla en una corrida propia: `calcular_lectura(..., ciclo_bianual = FALSE)`.

## Anexo de canal hospitalario

`anexo_canal_hospitalario` hace la misma comparación que `brecha_federal_estatal` (federal agrupado contra cada entidad, mismo año, indicador principal, regla del ciclo bianual, demás filtros de la lectura principal) solo con las filas de canal hospitalario, años fiscales 2019-2026; `par_principal` marca los pares de 2024 y 2025. `anexo_canal_hospitalario_claves` da, por clave, las filas federales y estatales, los pares entidad-año con referencia federal y la regla de clave comparada en 2019-2026 y en 2024-2025 (`comparada_principal`). Es anexo: nunca se mezcla con las tablas principales (`anexo_canal()` en `R/anexos.R`). Las insulinas ya no están en el anexo (ver abajo).

## Canal de las insulinas

Las tres claves de insulina del universo, `010.000.4158.00` (insulina glargina), `010.000.1050.00` y `010.000.1051.00` (insulina humana), se leen como canal ambulatorio diga lo que diga la columna `canal` de la base, que clasifica como hospitalario casi todas sus filas federales: se dispensan en primer nivel de atención (decisión de Andrés del 2026-11-08). Entran en la lectura principal y salen del anexo hospitalario.

La lista está en `config$claves_canal_ambulatorio` y el interruptor en `lectura_principal$reclasificar_canal`. `reclasificar_canal()` (`R/filtrar.R`) se aplica una sola vez, en `R/00_correr_todo.R`, a la copia de la base en memoria, después de validar las anclas y antes de cualquier filtro de canal; guarda el valor original en `canal_base`. La base no cambia. La hoja `reclasificacion_canal` y la sección «Reclasificación de canal» de `LEEME` cuentan las filas movidas por clave y orden de gobierno; la sección «Sensibilidad: lectura principal sin reclasificar el canal de las insulinas» da el resumen titular con el canal de la base (`resumen_desde_base()` en `R/principal.R`). Con el interruptor en `FALSE`, la corrida usa el canal de la base y esa sección da el resumen con la reclasificación. La rejilla `sensibilidad` se calcula con la base reclasificada.

## Comparador con la prescripción (OCAMIS)

Cuánto de lo que prescriben el IMSS (Ordinario) y el ISSSTE capta la lectura (`R/ocamis.R`). Fuente: `../OCamis Abasto/ocamis_43_claves_semana_institucion_estado.xlsx`, hoja `datos` (`config$ruta_ocamis`, solo lectura): una fila por semana ISO × institución × estado × clave; `prescrito` está en cajas, la misma unidad que `cantidad_envases`. Los datos terminan a inicios de 2024, así que 2023 es el último año completo (`config$año_prescripcion`). El año ISO se toma como año fiscal.

- `cobertura_prescripcion`: por clave (43), cajas prescritas en 2023 por el IMSS y por el ISSSTE, la parte de cada clave en el total de la institución, si la clave queda comparada en la lectura principal y en cada año (`comparada_2024`, `comparada_2025`) y el motivo cuando no lo está. La sección «Cobertura de la prescripción» de `LEEME` da la parte del volumen prescrito en 2023 que corresponde a claves comparadas.
- `compra_vs_prescripcion`: por institución y año (2019-2024), cajas prescritas contra cajas compradas en la base (filas comparables, de cualquier canal, sin `duplicado_de`; `tipo_institucion` `IMSS` → `IMSS (Ordinario)`, `ISSSTE` → `ISSSTE`), con la cantidad mínima y con la máxima donde un contrato abierto la trae, claves con ambas, compra entre prescripción en esas claves y compra como parte de todo lo prescrito. Es una revisión de cobertura de la base, no de precios. 2024 está incompleto en OCAMIS (`semanas_prescripcion`).
- `compra_vs_prescripcion_clave`: lo mismo por institución × año × clave (cajas prescritas, compradas con la cantidad mínima y con la máxima, `ambas` y las razones compra/prescripción). La sección «Compra contra prescripción por clave» de `LEEME` da, para el ISSSTE en 2023, las claves con los dos datos y la mediana de su razón (cantidad mínima). La figura 5 del informe sale de esta tabla.
- `compra_2025_vs_presc_2023`: aproximación por institución y clave, la compra del año fiscal 2025 llevada a un año contra lo prescrito en 2023. Solo las filas `[CICLO_BIANUAL]` se dividen entre dos; las filas sin etiqueta cuentan como están. La sección «Aproximación: compra 2025 contra prescripción 2023» de `LEEME` da por institución las filas y cajas con y sin etiqueta.

## Sobrecosto estatal

`sobrecosto_estatal` (`R/sobrecosto.R`; definición aprobada por Andrés el 2026-11-08, método del proyecto «Salud, dinero y corrupción» de PODER, 2021, adaptado). Sobre las filas estatales de la lectura principal (años fiscales 2024 y 2025, canal ambulatorio con las insulinas reclasificadas, claves del universo, precio y cantidad positivos) que tienen referencia federal el mismo año, el sobrecosto de una fila es max(0, (precio estatal por caja − referencia federal) × cajas estatales). La referencia es el indicador principal: la mediana ponderada por cantidad del grupo federal agrupado de la clave y el año, con el precio del ciclo bianual arrastrado como lo usa `brecha_federal_estatal`. Las cajas son la cantidad mínima de los contratos abiertos. La tabla da el total, cada año, cada entidad y cada clave: gasto estatal comparado (precio × cantidad), sobrecosto y su parte del gasto.

La sección «Sobrecosto estatal» de `LEEME` repite el total y los años, cuenta las filas estatales y da cuatro variantes, solo como total: (a) referencia = promedio ponderado federal; (b) referencia = promedio ponderado de todas las compras, federales y estatales, de la clave y el año (solo compras: sin las copias del ciclo); (c) referencia principal con la cantidad máxima de los contratos abiertos; (d) la misma fórmula dentro del grupo federal (con las copias del ciclo), cada fila contra el promedio ponderado de su clave-año.

## Contexto estatal: marginación, lengua indígena y cobertura

`R/marginacion.R` lee dos insumos de `datos/`, solo lectura: `conapo_marginacion_2020.csv` (CONAPO, índice de marginación 2020 por entidad: `im`, `imn`, `grado_marginacion`; `config$ruta_marginacion`) y el tabulado del Censo 2020 del INEGI `inegi_censo2020/cpv2020_b_eum_05_etnicidad.xlsx`, hoja `02`, filas con sexo y grupo de edad «Total», columnas «Población de 3 años y más» y «Habla lengua indígena» (`config$ruta_lengua_indigena`; las columnas se ubican por su encabezado y la entidad por el prefijo de dos dígitos, que es su clave).

- `cruce_marginacion_entidad`: por entidad con pares de la lectura principal, pares, claves y mediana de la razón (`brecha_mediana`, 4 decimales), índice, índice normalizado y grado de marginación, población de 3 años y más, hablantes de lengua indígena y su porcentaje (`pct_hli`). La figura 2 del informe sale de esta tabla.
- `cobertura_marginacion_entidad`: las 32 entidades con su grado de marginación y su categoría de cobertura, la primera que aplica: con pares; con filas comparables (en `cobertura_entidad`, serie 2019-2026, canal ambulatorio) pero sin par; con filas estatales en la base, ninguna comparable; sin filas. `filas_total` cuenta todas las filas estatales de la base, comparables o no. La figura 6 sale de esta tabla.

## Entregas de la compra consolidada (plataforma SSA)

Cuánto de lo que pidió la compra consolidada federal llegó, clave por clave, junto a lo que el análisis dice de sus precios (`R/entregas.R`). Fuente: la extracción del 9 de noviembre de 2026 de la Plataforma de monitoreo de medicamentos de la Secretaría de Salud, `../Plataforma entrega medicamentos/datos/ordenes_suministro.csv` (`config$ruta_entregas`, solo lectura; su `LEEME.md` documenta columnas y límites). Una fila por orden de suministro, solicitudes del 2025-01-06 al 2026-10-23, corte de la plataforma al 23 de octubre de 2026. No trae precios y solo cubre a las instituciones de la compra consolidada federal (IMSS, IMSS-Bienestar, ISSSTE, PEMEX, CCINSHAE y programas federales). Si el archivo no está, la corrida omite estas tablas con un mensaje y lo anota en `LEEME`; no se detiene.

- `entregas_por_clave`: las 43 claves, con `en_plataforma = FALSE` y ceros en las 5 que no tienen órdenes (`010.000.1050.00`, `010.000.1051.00`, `010.000.4489.00`, `040.000.2614.00` y `040.000.4486.00`). Órdenes, piezas solicitadas y entregadas, `pct_entregado`, piezas solicitadas por estatus, órdenes canceladas aparte, procedimientos y proveedores distintos, y el proveedor principal con su parte. Del lado de precios, tomados de las tablas de la misma corrida: `pares` y `razon_estatal_federal_mediana` (`razon_por_eje_y_clave`), `comparada_principal` (`claves_comparadas`; una clave ausente de esa tabla cuenta como no comparada) y gasto estatal comparado, sobrecosto y su parte (`sobrecosto_estatal`).
- `entregas_por_clave_institucion` y `entregas_por_clave_año` (año de `fecha_solicitud`: 2025 y 2026): las mismas columnas de volumen, sin precios, solo en las combinaciones con órdenes.
- `entregas_cruce_procedimientos`: por clave, las órdenes y piezas cuyo número de procedimiento (`licitacion`) aparece como `id_procedimiento` en alguna fila de la base de precios (de cualquier clave; coincidencia exacta tras quitar espacios y pasar a mayúsculas). Dice para cuánto del volumen entregado hay un procedimiento con precio en la base.
- `entregas_control`: control, no lectura (ver abajo).

Reglas:

- Estatus: cada valor de la plataforma es una categoría: `COMPLETA` → `completa`, `INCOMPLETA` → `incompleta`, `EN TRÁNSITO` → `en_transito`, `INCUMPLIDA` → `incumplida`, `VALIDACIÓN ENTREGA` → `en_validacion`. Las columnas `piezas_solicitadas_<categoría>` reparten las piezas solicitadas por estatus y suman `piezas_solicitadas`; solo `completa` e `incompleta` tienen piezas entregadas. Un estatus nuevo detiene la corrida.
- Canceladas: las órdenes con `canceladas_activas = CANCELADA` no entran en órdenes, piezas, `pct_entregado`, procedimientos, proveedores ni proveedor principal; se cuentan aparte en `canceladas_ordenes`, `canceladas_piezas_solicitadas` y `canceladas_piezas_entregadas` (algunas canceladas tienen piezas entregadas).
- `pct_entregado` = piezas entregadas / piezas solicitadas, sobre órdenes activas; vacío si no se solicitó nada.
- Proveedor principal: el que entregó más piezas de la clave (o del grupo); si dos empatan, el primero en orden alfabético; vacío si no se entregó nada. `proveedor_principal_parte` es su parte de las piezas entregadas.

Las tablas usan `ordenes_suministro.csv`. La pestaña «Cumplimiento de proveedores» (`cumplimiento_proveedores.csv`, `config$ruta_cumplimiento_proveedores`) ve las mismas órdenes desde el proveedor y solo alimenta `entregas_control`: por clave, filas y piezas solicitadas y entregadas en cada archivo y la diferencia (cumplimiento menos órdenes). Como esa pestaña no marca la cancelación, el control compara todas las filas de órdenes, canceladas incluidas. La sección «Entregas (plataforma SSA)» de `LEEME` da los totales y el resultado del control.

## Deflación

Pesos de 2025 con el INPC general (Banxico SIE, serie SP1, base 2Q jul 2018 = 100). INPC anual = promedio de los meses disponibles del año; factor = INPC 2025 / INPC del año; precio real = nominal × factor. 2026 tiene enero a agosto (columna `inpc_meses`). El año fiscal 2027 no tiene INPC y su precio real queda vacío.

Las columnas reales llevan el sufijo `_real_2025` y van junto a las nominales. Las razones dentro de un mismo año no cambian al deflactar; los precios reales sirven para comparar entre años.

La serie sale de un xlsx de otro proyecto. `R/01_preparar_inpc.R` la convierte una sola vez en `datos/inpc_general_mensual.csv` y documenta la procedencia en `datos/LEEME_inpc.md`. El análisis solo lee el CSV, así que corre en cualquier máquina sin el xlsx.

La base no se copia aquí. El código la lee del repo `tm-precios-salud` (carpeta `data/`). En otra máquina, define la variable de entorno `TM_PRECIOS_DATA` con la carpeta que contiene `base_precios.csv` y `claves_eje_salud_mental_diabetes_40.csv`.

## Cómo correrlo

Desde esta carpeta (`Analisis precios`):

```bash
Rscript R/00_correr_todo.R
```

Solo si cambia la serie del INPC (el CSV ya está en `datos/`):

```bash
Rscript R/01_preparar_inpc.R
```

En otra máquina, por ejemplo:

```bash
TM_PRECIOS_DATA="/ruta/a/tm-precios-salud/data" Rscript R/00_correr_todo.R
```

Escribe un CSV (UTF-8) por tabla en `salidas/` y `salidas/analisis_precios.xlsx`, con una hoja por tabla y una hoja `LEEME` (hojas, lectura principal, resumen de las cifras titulares de 2024-2025 y de cada año, la misma lectura sin reclasificar las insulinas, el anexo, las filas reclasificadas, la cobertura de la prescripción, las entregas de la plataforma, filtros de la lectura y de la serie de contexto, notas sobre la regla y la deflación, sha256 de la base y del INPC, factores por año, fecha de corrida y anclas).

Si la base no reproduce las anclas de `R/config.R`, el script se detiene y muestra cuáles fallaron. Cuando Edu recargue la base, hay que actualizar las anclas a mano después de revisar la diferencia.

## Pruebas

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Usan tablas pequeñas hechas a mano, no la base real. Incluyen la mediana ponderada (casos en que difiere de la mediana por fila y de la media ponderada, cantidades vacías o no positivas, el límite exacto de la mitad del peso), la ponderación por cantidad mínima en contrato abierto, el filtro de canal y el anexo hospitalario, la regla del ciclo bianual (copias de segundo año, periodo, referencia federal combinada, tablas sin duplicar) la separación entre cifras titulares de 2024-2025 y serie de contexto 2019-2026 (marcas `comparada_principal` y `par_principal`, motivos de clave no comparada, resumen de `LEEME` total y por año), la reclasificación de canal de las insulinas y el comparador con OCAMIS (lectura de la hoja, cobertura, compra contra prescripción por año y por clave, anualización del ciclo), este último con un xlsx diminuto que la prueba escribe, no con el archivo real, los conteos de pares del resumen (razón mayor a 5 y a 10, una sola fila estatal) y la razón por eje y clave, el sobrecosto estatal (referencia, piso en cero, ciclo arrastrado, tabla por nivel y las cuatro variantes), el contexto estatal (lectura de CONAPO y del tabulado del censo, también con archivos diminutos, cruce y categorías de cobertura) y las entregas de la plataforma (suma por clave sin canceladas, reparto por estatus, porcentaje sin piezas solicitadas, las 43 claves en la tabla con el lado de precios, desempate del proveedor principal, cruce con los procedimientos de la base, control contra la pestaña de cumplimiento y la corrida sin el archivo), con órdenes hechas a mano y un CSV diminuto.

## Scripts

| Archivo | Qué hace |
|---|---|
| `R/config.R` | Rutas, etiquetas, columna de precio, claves leídas como ambulatorio, umbral de 30 claves, ruta e instituciones de OCAMIS, anclas, año base de deflación, lectura base (2024-2025), lectura de contexto (2019-2026) y lectura principal (con el indicador) |
| `R/cargar.R` | Lee la base con tipos explícitos (claves como texto), valida reglas de `comparable` y anclas, calcula el sha256 |
| `R/filtrar.R` | Define una lectura, filtra filas según sus parámetros (y por canal, para el anexo), colapsa duplicados exactos, agrega las copias de segundo año del ciclo bianual cuando se piden, asigna los grupos de cada comparación y reclasifica el canal de las insulinas |
| `R/01_preparar_inpc.R` | Una sola vez: lee el xlsx del INPC y escribe `datos/inpc_general_mensual.csv` y `datos/LEEME_inpc.md` |
| `R/deflactar.R` | Lee el CSV del INPC, calcula INPC anual y factores a 2025, agrega precios reales a las filas |
| `R/indicadores.R` | Mediana ponderada por cantidad (indicador principal), mediana por fila y media ponderada por clave × grupo × año (nominal y real); regla de clave «comparada» con grupo requerido |
| `R/tablas.R` | Tablas derivadas: sensibilidad, precios sin menudeo, brechas IMSS-ISSSTE y federal-estatal, dispersión, serie real por clave y cobertura |
| `R/anexos.R` | Anexo de canal hospitalario: brecha federal-estatal y claves comparadas solo con filas hospitalarias |
| `R/principal.R` | Cifras titulares de 2024-2025: marca `comparada_principal` y `par_principal` en las tablas de contexto, motivos de clave no comparada, resumen de la hoja `LEEME` (total y por año, y desde una base sola para la sensibilidad sin reclasificar) y razón mediana por eje y por clave |
| `R/ocamis.R` | Comparador con la prescripción de OCAMIS: lectura de la hoja `datos`, cobertura de la prescripción, compra contra prescripción (por año y por clave) y aproximación 2025 contra 2023 |
| `R/sobrecosto.R` | Sobrecosto estatal frente a la referencia federal: tabla por total, año, entidad y clave, variantes y líneas de `LEEME` |
| `R/marginacion.R` | Lectura de CONAPO y del tabulado del censo, cruce de la razón por entidad con marginación y lengua indígena, y cobertura de las 32 entidades |
| `R/entregas.R` | Órdenes de suministro de la plataforma de la Secretaría de Salud: volumen solicitado y entregado por clave, institución y año, cruce con los precios del análisis y con los procedimientos de la base, y control contra la pestaña de cumplimiento |
| `R/exportar.R` | Escribe CSV y XLSX, arma la hoja `LEEME` |
| `R/00_correr_todo.R` | Corre todo en orden |

## Parámetros de una lectura

- `periodo`: `"todo"` (todos los años fiscales, 2027 incluido), `"2019_2026"` (serie de contexto), `"2024_2027"`, `"2024_2025"` (cifras titulares) o `"solo_2025"` (la lectura titular anterior).
- `excluir_entrada_almacen_hgm`: quita las filas comparables con `[ENTRADA_DE_ALMACEN]`. Desde la base del 2026-11-07 las 339 filas del Hospital General de México con esa etiqueta son no comparables (ancla `filas_entrada_almacen = 0`), así que hoy no quita ninguna fila; queda como constancia.
- `excluir_duplicados_exactos`: deja una fila por grupo idéntico en diez campos (clave, institución, proveedor, precio, año, procedimiento, cantidad, contrato, fecha, monto).
- `excluir_menudeo`: quita las filas con `[MENUDEO_FARMACIA]`.
- `solo_ambulatorio`: deja solo `canal == "ambulatorio"`. Encendido en la lectura principal desde el 2026-11-08; la rejilla de `sensibilidad` lo recorre en `FALSE` y `TRUE`.

Toda lectura parte de `comparable == TRUE` y de las claves del universo.

## Comparaciones (parámetro `comparacion`)

- `imss_issste`: IMSS contra ISSSTE (`tipo_institucion`).
- `tres_federales`: IMSS, ISSSTE e IMSS-Bienestar.
- `federal_todas`: cada `tipo_institucion` con `orden_gobierno` federal.
- `entidades`: filas estatales agrupadas por entidad federativa.
- `federal_vs_estatal`: una mediana federal agrupada contra cada entidad.

Una clave queda «comparada» cuando tiene el indicador principal (mediana ponderada) en al menos dos grupos; en `federal_vs_estatal`, uno de ellos debe ser el federal agrupado. Se reporta de dos formas: agrupando todo el periodo y exigiendo el mismo año fiscal. En `claves_comparadas` y `sensibilidad`, las columnas con sufijo `_mediana` repiten la regla con la mediana por fila.

## Tablas

- `medianas`: los tres indicadores por clave × grupo × año, con `n_filas` y `n_sin_cantidad`.
- `medianas_sin_menudeo`: sensibilidad de precios sin menudeo de farmacia. Mismas filas y columnas que `medianas` (comparación × clave × grupo × año), calculadas con los filtros de la serie de contexto (2019-2026) más `excluir_menudeo = TRUE`. Agrega `mediana_ponderada_cantidad_con_menudeo` (el indicador principal de `medianas`) y `razon_sin_entre_con` (sin entre con; vacía si falta alguno). Los grupos cuyas filas eran todas de menudeo quedan con `n_filas = 0` y precios vacíos. La lectura principal incluye el menudeo.
- `claves_comparadas`: regla de clave comparada con el indicador principal y, con sufijo `_mediana`, con la mediana por fila, en la serie 2019-2026 (`comparada_agrupado`, `comparada_mismo_año`, `años_comparados`) y en 2024-2025 (`comparada_principal`, la cifra titular).
- `sensibilidad`: la rejilla completa (5 comparaciones × 5 periodos × 16 combinaciones de interruptores, 400 filas). Columnas `indicador`, `filas_sin_cantidad`, `claves_con_indicador` y los conteos de claves comparadas con el indicador principal y con la mediana por fila (`_mediana`). Las filas con `excluir_menudeo` en `FALSE` y `TRUE` son la sensibilidad con y sin menudeo.
- `brecha_imss_issste`: medianas ponderadas y por fila de ambos institutos; `razon_issste_imss` y `diferencia_issste_menos_imss` con el indicador principal, y `razon_issste_imss_mediana` y `diferencia_issste_menos_imss_mediana` con la mediana por fila.
- `brecha_federal_estatal`: medianas ponderadas y por fila, estatal y federal; `razon_estatal_federal` con el indicador principal y `razon_estatal_federal_mediana` con la mediana por fila. La referencia federal incluye el precio del ciclo bianual en su segundo año: `n_filas_federal_ciclo_arrastrado` y `federal_con_ciclo_arrastrado`. `par_principal` marca los pares de 2024 y 2025.
- `dispersion_por_clave` y `dispersion_por_clave_año`: agregan `mediana_ponderada_cantidad` y las filas por encima de 2x y 5x la mediana ponderada de su clave-año, junto a las que se cuentan contra la mediana por fila.
- `serie_real_por_clave`: mediana ponderada y por fila de cada lado.
- `cobertura_tipo_institucion` y `cobertura_entidad`: filas comparables por clave, con los filtros de la serie de contexto (2019-2026, solo ambulatorio).
- `anexo_canal_hospitalario` y `anexo_canal_hospitalario_claves`: anexo con las filas de canal hospitalario (ver arriba).
- `reclasificacion_canal`: filas de insulina leídas como canal ambulatorio, por clave y orden de gobierno (ver «Canal de las insulinas»).
- `cobertura_prescripcion`, `compra_vs_prescripcion`, `compra_vs_prescripcion_clave` y `compra_2025_vs_presc_2023`: comparador con OCAMIS (ver arriba).
- `razon_por_eje_y_clave`: razón mediana de los pares de la lectura principal por eje y por clave.
- `sobrecosto_estatal`: sobrecosto estatal frente a la referencia federal (ver «Sobrecosto estatal»).
- `cruce_marginacion_entidad` y `cobertura_marginacion_entidad`: contexto estatal (ver «Contexto estatal»).
- `entregas_por_clave`, `entregas_por_clave_institucion`, `entregas_por_clave_año`, `entregas_cruce_procedimientos` y `entregas_control`: entregas de la compra consolidada (ver «Entregas de la compra consolidada»).

## `serie_real_por_clave`

Por clave × año fiscal: mediana ponderada por cantidad y mediana por fila, federal agrupada y estatal agrupada (todas las entidades juntas), con número de filas y filas sin cantidad, en pesos nominales y de 2025.

## Ajustes en `R/config.R`

- `columna_precio`: unidad de comparación. Por omisión `precio_unitario_envase_mxn`, como fija el diccionario de datos; la alternativa es `precio_por_unidad_minima_mxn`.
- `etiquetas_entrada_almacen`: etiquetas que quita el interruptor de almacén.
- `etiqueta_ciclo_bianual`: etiqueta de las filas federales de ciclo bianual (`[CICLO_BIANUAL]`).
- `canal_anexo`: canal que va al anexo (`"hospitalario"`).
- `claves_canal_ambulatorio`: claves leídas como canal ambulatorio (las tres insulinas); `lectura_principal$reclasificar_canal` enciende o apaga la reclasificación.
- `ruta_ocamis`, `año_prescripcion` e `instituciones_ocamis`: archivo de OCAMIS, año de prescripción que se compara (2023) y correspondencia de `tipo_institucion` con la institución de OCAMIS.
- `ruta_marginacion` y `ruta_lengua_indigena`: marginación 2020 de CONAPO y tabulado de lengua indígena del Censo 2020 (contexto estatal).
- `ruta_entregas` y `ruta_cumplimiento_proveedores`: órdenes de suministro y pestaña de cumplimiento de la plataforma de la Secretaría de Salud (entregas; opcionales).
- `lectura_principal$ciclo_bianual_segundo_año`: regla del ciclo bianual en la comparación federal contra estados (`TRUE` desde el 2026-11-08).
- `umbral_claves`: umbral de claves comparadas (30).
- `año_base_deflacion`: año de los pesos constantes (2025).
- `ruta_inpc`: CSV del INPC mensual.
- `lectura_principal$indicador`: indicador principal, `"mediana_ponderada_cantidad"` (decisión del 2026-11-07); la alternativa es `"mediana"`.
