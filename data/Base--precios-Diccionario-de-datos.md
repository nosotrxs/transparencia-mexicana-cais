---
contributors:
  - Edu
type: diccionario-datos
project: "[[TM - OCAMIS - Medicinas|TM - OCAMIS - Medicinas]]"
version: 1.7 (insulinas a canal ambulatorio, etiqueta de ciclo bianual completada en 2025, URL de Colima, CSV de claves con envases corregidos, 20,038 filas, 8,736 comparables, 2026-11-08)
periodo: 2019-2026
---

# Base de precios de medicamentos · Diccionario de datos

Adaptado del esquema de `TM - PODER - Paneles solares/Datos/Base de precios - Diccionario de datos.md`. Cambia el eje: en paneles el problema era homologar bienes heterogéneos, aquí el bien está fijado por la clave del Compendio Nacional de Insumos para la Salud (CNIS) y el problema es aislar el precio por clave dentro de documentos con cientos de partidas.

**Archivo:** `Datos/base_precios.csv`, UTF-8, separador coma, booleanos `TRUE`/`FALSE` en mayúsculas.

> **Nota del 2026-09-14.** El universo de claves cambió: la referencia ya no es `claves_nucleo_30.csv` (52 claves, 4 áreas) sino **`Datos/claves_eje_salud_mental_diabetes_40.csv`** (40 claves, salud mental y diabetes). El esquema de columnas no cambia. Lo que cambia es qué filas pertenecen a la base: quedaron **493**, y las 737 fuera de universo se archivaron en `Datos/_old/`. Los `id_registro` se conservaron sin renumerar, conforme a la regla de identificadores estables de la sección correspondiente, así que la numeración es discontinua a propósito.

> **Nota del 2026-09-19, que actualiza la anterior.** Las **493 filas** de arriba son la foto del 2026-09-14, inmediatamente después del recorte de universo. No son el estado actual. Desde entonces la base creció por extracción, no por relajar el criterio: **648 filas**, **36 de las 40 claves** con al menos un precio, **638 filas de origen federal y 10 de origen estatal**. Ninguna fila queda fuera del universo de 40. El hueco vivo no es de claves sino de periodo: los años fiscales presentes son 2024 (11), 2025 (609), 2026 (6) y 2027 (22), así que **la serie 2019-2023 sigue en cero** y el cruce contra el desabasto de OCAMIS, que llega hasta 2024, todavía no comparte un año útil con esta base. La cobertura celda por celda está medida en el análisis de cobertura del 2026-09-17.

> **Nota del 2026-10-12, que actualiza la anterior.** El universo sube a **43 claves y 23 componentes**: Andrés pidió sumar tres presentaciones de valproato semisódico (`010.000.5488.00`, `010.000.2630.00` y `010.000.5471.00`) al análisis comparativo completo (`adr-0008` del repo del consorcio). Van en el mismo `claves_eje_salud_mental_diabetes_40.csv`, que conserva el nombre porque lo citan 29 scripts y notas. El esquema de columnas no cambia. La base pasa a **691 filas** con 43 filas federales nuevas del tablero de compra consolidada, ciclo 25.26 (`MED-1386` a `MED-1428`, todas `comparable = TRUE`), y la cobertura queda en **39 de 43 claves**: **681 filas federales y 10 estatales**. Las cifras de la nota anterior describen el universo de 40.

> **Nota del 2026-11-07, que actualiza las anteriores.** La base tiene **20,038 filas** (13,844 federales y 6,194 estatales) y **8,736 comparables** (7,743 federales y 993 estatales), con 42 de las 43 claves con al menos un precio comparable y 11 entidades con filas estatales comparables. Falta solo `040.000.2614.00` (clonazepam inyectable). Cambio de este envío: **339 filas del Hospital General de México** (`OCAMIS-FED-09`) con `[ENTRADA_DE_ALMACEN]` pasan a `FALSE`, porque la regla del 2026-10-16 no se les aplicó en la carga (lo señaló Andrés el 2026-11-06). Las 105 filas de `OCAMIS-FED-19` y `OCAMIS-FED-23` con la misma etiqueta siguen `TRUE` porque llevan su corrección escrita en la fila (`[V02 2026-10-24]` y `[V10 2026-10-24]`). La base se entrega también como `base_precios.xlsx`, derivado del CSV; si difieren, manda el CSV. Dos lecturas para el análisis, medidas este día: (1) en los 50 cruces de clave, procedimiento y proveedor donde aparecen el IMSS y el ISSSTE, el precio es idéntico, porque es la misma compra consolidada, y las diferencias de mediana entre las dos instituciones vienen de la mezcla de procedimientos y no del precio. Ponderada por cantidad, la mediana coincide. (2) Las cerca de 4,184 filas comparables iguales en diez campos no son cargas repetidas: cada una corresponde a un renglón distinto del archivo fuente. 4,114 son del Instituto Nacional de Psiquiatría, cuyo archivo no trae fecha ni número de pedido.
>
> **Decisiones de Edu del 2026-11-07** (dudas de Andrés, `task-28` del repo): (1) IVA, opción A (ver la sección de la regla de IVA). (2) Menudeo en farmacia: el indicador principal usa la **mediana ponderada por cantidad**, y las medianas con y sin `[MENUDEO_FARMACIA]` se reportan como sensibilidad. (3) Canal `hospitalario`: queda en la base y **fuera del indicador principal**, por el recorte a primer nivel de atención (`adr-0002`). (4) Ciclo bianual: se aplica la regla 1 a **2,489 filas federales** (897 comparables) con año 2026 que venían de procedimientos de la compra consolidada del ciclo 25.26 (unidad compradora `012NEF001`), que pasan a 2025 con `[CICLO_BIANUAL] [V-2026-11-07]`. La comparación con los estados toma el precio del ciclo contra 2025 y 2026. (5) `010.000.5486.00` y `040.000.4486.00` siguen en el universo (decisión del 2026-10-17). (6) Periodo: se sostiene la serie 2019-2026 declarando los vacíos, con lectura principal en 2024-2025.

> **Nota del 2026-11-08, que actualiza las anteriores.** Tres correcciones por la revisión de Andrés del 2026-11-08, sin cambio en los totales (20,038 filas, 8,736 comparables). (1) **Canal de las insulinas:** las 1,190 filas de `010.000.4158.00` (glargina), `010.000.1050.00` y `010.000.1051.00` (humanas), más las dos de `4158.01` y `1051.01` que están `FALSE`, pasan de `hospitalario` a `ambulatorio` (263 comparables: 211 federales y 41 estatales de glargina, 11 de insulina humana. Otras 4 estatales de glargina ya eran `ambulatorio`). La carga las había clasificado con la regla mecánica `es_hospitalario()` (forma «INYECTABLE» o envase con «ámpula»), no por criterio clínico, y son medicamentos que se surten en primer nivel. Se retiró la etiqueta `[CANAL_HOSPITALARIO]` de esas filas y llevan `[CANAL_RECLASIFICADO] [V-2026-11-08]`. El canal `hospitalario` queda solo para la olanzapina inyectable `010.000.4489.00` y la risperidona de liberación prolongada `040.000.3268.00` (1,002 comparables). (2) **Ciclo bianual:** 3,073 filas federales con año 2025 de procedimientos de la compra consolidada del ciclo 25.26 (`012NEF001` con año 2025 o 2026 en el identificador) no llevaban `[CICLO_BIANUAL]` porque la reimputación del 2026-11-07 solo etiquetó las que venían de 2026. Ahora la llevan, sin cambiar el año (842 comparables: 711 del IMSS-Bienestar, 52 del INPRFM, 34 del ISSSTE). 19 filas `FALSE` del mismo ciclo sin año toman 2025. **No se tocan** las 144 filas de `012NEF001` cuyo identificador no trae 2025 ni 2026 (15 procedimientos de 2024: 121 filas en 2024 y 23 en 2025). Las únicas comparables de 2025 entre ellas son 19, de las adjudicaciones directas `AA-12-NEF-012NEF001-I-186-2024` y `-190-2024` de diciembre de 2024 (90 filas entre las dos: 13 del IMSS-Bienestar, 5 del INPRFM y 1 del INCAN): no hay con qué confirmar que su precio rija el ciclo 25.26. (3) **Colima:** las 162 filas de `OCAMIS-EST-22` (143 comparables) tenían `url_documento` vacío; toman la URL del portal de la PNT, como el resto de respuestas a solicitudes, con la nota de que el respaldo es `ANEXO 165.xlsx` del folio 1351493826000165. Además, `claves_eje_salud_mental_diabetes_40.csv` queda con `container_name` corregido en las diez claves de la nota del 2026-10-17 (quince renglones, contando los pares `.00`/`.01`), que hasta ahora solo se habían corregido en la base.

**Grano:** una fila = **una clave-presentación dentro de un contrato o partida**. Formato largo. Si un fallo consolidado adjudica 40 claves del universo, son 40 filas con el mismo `id_procedimiento`. Nunca una matriz clave × entidad: la estadística (mediana, dispersión) se calcula después.

**Periodo y matriz objetivo (decisión de Edu, 2026-09-07).** La investigación cubre **2019 hasta la actualidad**. El objetivo declarado es tener las 40 claves para cada año y cada entidad, es decir 40 × 8 años × 33 ámbitos (32 entidades más el federal), 10,560 celdas. Ninguna extracción va a llenar esa matriz por completo: la cobertura efectiva por celda es un resultado del proyecto y se documenta como tal, no se promete. Consecuencia operativa: **toda extracción se corre por año**, y `año_fiscal` nunca queda vacío en una fila comparable.

**Cantidad obligatoria (decisión de Edu, 2026-09-07).** Toda fila comparable trae las tres cifras juntas: **cantidad comprada, costo total y precio unitario**. Una fila con precio unitario pero sin cantidad no describe una compra, describe un catálogo, y no permite calcular gasto ni precio ponderado por volumen. Las tres tienen que cerrar aritméticamente entre sí.

## Columnas

| # | Columna | Tipo | Regla |
|---|---|---|---|
| 1 | `id_registro` | texto | `MED-0001` correlativo. No se reutiliza ni al borrar |
| 2 | `fuente` | vocabulario | `Monitoreo compra consolidada`, `ComprasMX`, `CompraNet`, `PNT`, `IMSS portal`, `Birmex`, `Portal estatal (Estado)`, `Solicitud PNT`. `Solicitud PNT` (antes `Solicitud`, sin filas, renombrado el 2026-10-16 por decisión de Edu) marca lo que llegó como respuesta a una solicitud de acceso, por la PNT o por correo, y lo separa de `PNT`, que es lo publicado en el portal. El primero se agregó en la v0.3: es el tablero `monitoreocompra.salud.gob.mx` y no encajaba en ninguno de los valores anteriores |
| 3 | `id_contrato_fuente` | texto | Identificador nativo de la fuente (`C-2025-...`, número de contrato PNT, etc.) |
| 4 | `id_procedimiento` | texto | Número de licitación o procedimiento que cita el documento. Es la llave para agrupar contratos hermanos y para el diff entre fuentes (Parte II.4 del protocolo) |
| 5 | `duplicado_de` | texto | `id_registro` de la fila principal si la misma partida aparece en dos fuentes. Recíproco. Solo la principal lleva `comparable = TRUE`. Para ser duplicado, el `id_procedimiento` de las dos filas tiene que coincidir: misma clave, institución, proveedor, precio y año con otro procedimiento son dos compras distintas y las dos quedan `TRUE` (decisión de Edu, 2026-10-24) |
| 6 | `url_documento` | URL | Enlace a la fuente viva. Si no hay hipervínculo, indicar el buscador y los datos para localizarlo. Nunca vacío |
| 7 | `orden_gobierno` | vocabulario | `federal`, `estatal`, `municipal` |
| 8 | `entidad_federativa` | vocabulario cerrado | Los 32 nombres del catálogo `3. Assets/Datos/PNT/catalogo_entidades_federativas.csv` más `Federal`. Normalizar al escribir, no después |
| 9 | `institucion_compradora` | texto | Nombre del sujeto obligado tal como aparece en el catálogo PNT o en el CSV de ComprasMX |
| 10 | `tipo_institucion` | vocabulario | `IMSS`, `ISSSTE`, `IMSS-Bienestar`, `SSA-Birmex`, `Institutos nacionales`, `Pemex-Sedena-Semar`, `Servicios estatales de salud`, `ISSSTE estatal (ISSEMYM, ISSSTESON...)`, `DIF`, `Seguridad publica`, `Municipio`, `Otro` |
| 11 | `proveedor` | texto | Razón social |
| 12 | `rfc_proveedor` | texto | Solo si viene en la fuente. No traer de memoria |
| 13 | `clave_cnis` | texto | Formato `010.000.5165.00`. **Obligatoria para `comparable = TRUE`** |
| 14 | `componente` | vocabulario | Uno de los 29 de `claves_nucleo_30.csv` |
| 15 | `area` | vocabulario | `Diabetes`, `Hipertensión`, `Dislipidemias`, `Salud mental` |
| 16 | `presentacion` | texto | Copiada de `claves_nucleo_30.csv` para la clave (concentración y envase) |
| 17 | `unidades_por_envase` | número | Tabletas, cápsulas, mililitros o UI por envase, según la clave |
| 18 | `unidad_minima` | vocabulario | `tableta`, `capsula`, `gragea`, `comprimido`, `ml`, `UI`, `cartucho`, `pluma`, `frasco` |
| 19 | `canal` | vocabulario | `ambulatorio`, `hospitalario`. Las presentaciones inyectables de liberación prolongada y frascos hospitalarios van en `hospitalario` y no se comparan con el canal ambulatorio. Las insulinas en frasco ámpula (`4158.00`, `1050.00`, `1051.00`) son `ambulatorio` desde el 2026-11-08: se surten en primer nivel, y la regla mecánica de la carga las había puesto en `hospitalario` |
| 20 | `descripcion_original` | texto | Texto literal de la partida en el documento, sin corregir |
| 21 | `cantidad_envases` | número | **Obligatoria para `comparable = TRUE`.** Cantidad de envases adjudicada. En contrato abierto es la cantidad mínima, y se etiqueta `[CONTRATO_ABIERTO]` |
| 21b | `cantidad_maxima_envases` | número | Solo en contrato abierto: la cantidad máxima. En el acta del Instituto Nacional de Geriatría verificada el 2026-09-07 el formato es mínimo y máximo (750 y 1250), y el importe se publica para los dos extremos |
| 21c | `cantidad_unidades_minimas` | número | `cantidad_envases × unidades_por_envase`. Calculada. Es la cifra comparable entre presentaciones distintas del mismo componente |
| 22 | `precio_unitario_envase_mxn` | número | **Obligatoria.** Precio por envase tal como consta en el documento |
| 23 | `precio_por_unidad_minima_mxn` | número | `precio_unitario_envase_mxn / unidades_por_envase`. Calculada, 4 decimales |
| 24 | `monto_partida_mxn` | número | **Obligatoria.** Importe total de la partida. Cierra con `cantidad_envases × precio_unitario_envase_mxn`, tolerancia 1% |
| 25 | `iva` | vocabulario | `0%`, `16%`, `no consta`. Confirmado en el sondeo P1 (ver sección final): medicamentos (claves de grupo 010.xxx y 040.xxx, la totalidad del núcleo de 52) a tasa 0%. La tasa general del 16% sí aparece en la misma acta cuando el bien es de otro grupo de clave (material de curación, dispositivos), fuera del núcleo del proyecto. Si la fuente trae montos con y sin impuesto y difieren, anotar |
| 26 | `tipo_compra` | vocabulario | `consolidada`, `individual` |
| 27 | `mecanismo_procedimiento` | vocabulario | `adjudicacion_directa`, `invitacion_restringida`, `licitacion_publica`, `no consta` |
| 28 | `año_fiscal` | número | Año del ejercicio al que se imputa el precio |
| 29 | `fecha_documento` | fecha ISO | Fecha del fallo, contrato u orden. Vacío si no consta |
| 30 | `comparable` | booleano | Ver regla abajo |
| 31 | `notas_metodologicas` | texto | Registro **acumulativo**, tramos separados por ` | ` en orden cronológico. Etiquetas entre corchetes al inicio de cada tramo |
| 32 | `fecha_carga` | fecha ISO | Cuándo se escribió o modificó la fila |

## Decisiones tomadas en la primera carga (v0.3, 2026-09-08)

Dos cosas que el diccionario dejaba abiertas y que la carga obligó a cerrar. Las dos son decisiones metodológicas, no detalles de implementación, así que quedan acá y no enterradas en el script.

**0. Ratificado por Edu el 2026-09-08.** La unidad primaria es el **precio por envase por clave** (decisión 1 del Prompt 1). `precio_por_unidad_minima_mxn` queda como columna derivada, para comparar presentaciones distintas del mismo componente, nunca como unidad de reporte.

Y `unidades_por_envase` se toma del **Compendio Nacional de Insumos para la Salud** (decisión 3 del Prompt 1), con este argumento de Edu: **la clave ya lleva incluida la presentación**, así que el envase no es un atributo suelto que el documento pueda redefinir, es parte de la identidad del bien. Si dos documentos declaran envases distintos para la misma clave, uno de los dos está mal.

**Excepción obligatoria:** cuando un documento declare un envase distinto al del Compendio para la misma clave, la fila se etiqueta `[ENVASE_DISCREPANTE]` con los dos valores, y **no se corrige en silencio**. Una discrepancia de envase es un hallazgo, no un error de captura: puede indicar una clave mal asignada por la institución compradora, y eso cambia el precio unitario comparable.

**1. Imputación de año en ciclos bianuales.** Los ciclos del tablero federal son bianuales: `25.26` cubre los ejercicios 2025 y 2026. **Se imputa al primer año del ciclo** y la fila se etiqueta `[CICLO_BIANUAL]` aclarando que el precio aplica a los dos.

La alternativa era duplicar la fila en los dos años, y se descartó porque **inflaría el gasto al doble**: el precio se adjudica una vez para el ciclo completo, no una vez por año.

**Redacción para el análisis** (pedida por Edu el 2026-09-08, para poder explicarlo sin ambigüedad en el informe final):

> El Sector Salud federal no compra por año fiscal, compra por ciclo bianual. El ciclo identificado como `25.26` adjudica un precio único que rige durante los ejercicios 2025 y 2026. Para no contar dos veces el mismo gasto, cada adjudicación se registra una sola vez, imputada al primer año del ciclo, y se marca con la etiqueta `[CICLO_BIANUAL]`. **Por eso, en la capa federal, el segundo año de cada ciclo aparece sin registros propios: no es un hueco de información, es la estructura de la compra.** Cualquier lectura de cobertura por año en esta capa tiene que agrupar por ciclo, no por ejercicio. En la capa estatal, en cambio, la compra sí es anual, así que ahí el año fiscal se lee directo.

Consecuencia práctica al leer la matriz: **2026 aparece vacío en la capa federal aunque esté cubierto por el ciclo `25.26`**, y 2028 lo estará por el `27.28`.

**2. Ausencia de documento por fila.** El tablero publica dato estructurado sin hipervínculo por registro, y el filtro por cadena de consulta no funciona del lado del servidor (verificado en `staging/verificacion_monitoreocompra.md`). Toda fila de esta fuente lleva `[SIN_HIPERVINCULO]` con las tres coordenadas para localizarla a mano: ciclo, número de procedimiento y clave. `url_documento` apunta al portal, no a un enlace profundo. Es honesto pero no navega directo, y conviene decirlo así en la entrega.

Nota sobre `comparable` en esta fuente: la clave del Compendio Nacional de Insumos para la Salud viene como **campo explícito del conjunto de datos**, no inferida del nombre del componente, así que cumple la condición 1 de la regla de abajo. La condición se escribió pensando en documentos, y un campo estructurado de la fuente oficial la satisface igual o mejor.

## Regla de `comparable`

`TRUE` solo si se cumplen las cinco:

1. `clave_cnis` exacta **leída en el documento**, no inferida del nombre del componente.
2. `cantidad_envases` con valor.
3. `precio_unitario_envase_mxn` con valor.
4. `monto_partida_mxn` con valor.
5. `año_fiscal` con valor.

Y las tres cifras cierran: `cantidad_envases × precio_unitario_envase_mxn ≈ monto_partida_mxn`, tolerancia 1%. Si no cierran, la fila queda `FALSE` con etiqueta `[NO_CUADRA]` y las cifras tal como se leyeron, sin corregirlas a mano. En el proyecto anterior una expresión regular sobre texto de Reconocimiento Óptico de Caracteres (OCR) capturó la línea equivocada en 31 de 33 documentos, y lo que lo detectó fue precisamente esta validación.

Casos donde solo hay dos de las tres cifras: se cargan `FALSE` con `[SIN_CANTIDAD]` o `[SIN_MONTO]` y pasan a la cola de solicitudes. Son filas útiles (documentan que la compra existe) pero no entran en ninguna estadística de precio ni de gasto.

`FALSE` en todo lo demás, **sin borrar la fila**: una compra real que no se pudo desagregar es un dato sobre la opacidad y forma parte del entregable. Lo que sí se excluye (y se anota en la tabla de exclusiones, no en la base) es lo que no es compra del bien: servicios de distribución, consultoría, seguros, capacitación.

Control automático antes de cada entrega: ninguna fila `TRUE` sin `clave_cnis`, sin cantidad, sin precio, sin monto o sin año. `precio_por_unidad_minima_mxn` y `cantidad_unidades_minimas` recalculados, no copiados. Validación aritmética re-corrida sobre el total de filas `TRUE`.

## Etiquetas de `notas_metodologicas`

| Etiqueta | Cuándo |
|---|---|
| `[SIN_CLAVE]` | El documento nombra el principio activo pero no la clave CNIS. La fila queda `FALSE` hasta que un documento la confirme |
| `[CLAVE_INFERIDA]` | Se propuso la clave por concentración y envase pero no está escrita. `FALSE` |
| `[PARTIDA_AGRUPADA]` | Varias claves en un solo importe sin desglose |
| `[SERVICIO_INTEGRAL]` | Medicamento empaquetado con logística, distribución o dispensación (típico de "abasto integral" estatal). El precio no es del bien |
| `[CONTRATO_ABIERTO]` | Monto máximo publicado, no ejercido. Usar precio unitario, nunca monto/cantidad |
| `[SIN_HIPERVINCULO]` | El registro no trae documento. Candidata a solicitud |
| `[SIN_MONTO]` | Registro publicado sin monto o sin importe de partida |
| `[SIN_CANTIDAD]` | Hay precio unitario pero el documento no publica la cantidad adquirida |
| `[NO_CUADRA]` | Cantidad, precio unitario e importe no cierran con 1% de tolerancia |
| `[DOC_NO_CORRESPONDE]` | El adjunto no es el contrato reportado |
| `[CANAL_HOSPITALARIO]` | Presentación hospitalaria, no comparar con ambulatoria |
| `[RESCATE_OCR]` | Precio obtenido en segunda lectura de un documento ya descargado |
| `[CIFRA_RECONSTRUIDA]` | La cifra **no se leyó** del documento: se derivó por cierre aritmético contra otras cifras que sí se leyeron. Obligatorio explicitar en la nota cuál es el cálculo y por qué caminos independientes se confirmó. No se usa nunca para una cifra que solo cierra por un camino |
| `[ENVASE_DISCREPANTE]` | El documento declara un envase distinto al del Compendio para la misma clave. Se anotan los dos valores y no se corrige en silencio: puede indicar clave mal asignada por la institución compradora |
| `[VERIFICADO_EDU]` | Revisado a mano contra el documento |
| `[ENVASE_CORREGIDO 2026-10-16]` | `unidades_por_envase` se tomó de la descripción de la propia fila y se recalcularon los derivados. El CSV de claves invierte el envase de `.00` y `.01` en 3259, 4483, 4486, 5485 y 5486 respecto del portal de compra consolidada y de las instituciones. Afectó a 113 filas de la base del 2026-10-12 y a 841 de las respuestas del 2026-10-16. El CSV de claves no se corrigió: queda para OCAMIS |
| `[ENTRADA_ALMACEN]`, `[ENTRADA_DE_ALMACEN]` | La fuente es un registro de entradas a almacén, no un contrato. `FALSE` (decisión de Edu, 2026-10-16) |
| `[SIN_CONTRATO_NI_PROVEEDOR]` | Tabla con precio, cantidad e importe pero sin proveedor ni contrato (OCAMIS-EST-10). `FALSE` (decisión de Edu, 2026-10-16) |
| `[ORDEN_DE_SUMINISTRO]` | Orden de suministro derivada de un contrato marco, normalmente sin importe por partida |
| Otras de la carga del 2026-10-16 | `OBSERVACION`, `INFERIDO`, `POSIBLE_DUPLICADO_CON_BASE`, `POSIBLE_DUPLICADO_ENTRE_HOJAS`, `FILA_REPETIDA_EN_FUENTE`, `PRECIO_ATIPICO`, `UNIDAD_PRECIO_DUDOSA`, `CLAVE_DESCRIPCION_NO_COINCIDE` / `CLAVE_DESC_NO_COINCIDE`, `CLAVE_EN_DESCRIPCION`, `CLAVE_RECOMPUESTA`, `CLAVE_NO_ESTANDAR`, `ENVASE_DEL_CATALOGO`, `SIN_ANIO`, `ANO_INCIERTO`, `CANTIDAD_FRACCIONARIA`, `VALOR_NO_POSITIVO`. Definidas en `staging/respuestas_pnt_2026-10-16_A_resumen.md` y `_B_resumen.md`. Pendiente unificar los pares con dos nombres |
| `[DUPLICADO 2026-10-16]` | Repite una adjudicación ya cargada desde otra capa (misma clave, institución, proveedor, precio y número de procedimiento). `FALSE`, con `duplicado_de` lleno. Añadida en v1.5. El procedimiento es requisito desde el 2026-10-24 (decisión de Edu) |
| `[MAPEO_DESCRIPCION]` | Clave CNIS asignada por la descripción cuando coinciden principio activo, concentración y forma, aunque el documento no declare envase y haya dos claves (`.00` y `.01`) que difieren solo en él. Se asigna `.00` por convención y `unidades_por_envase` queda vacío. `FALSE`. Decisión de Edu, 2026-10-24 |
| `[DUPLICADO 2026-10-24]` | Asignación por instituto que repite el gasto de una partida consolidada ya cargada como fila principal (misma clave, proveedor, precio y número de procedimiento). `FALSE`, con `duplicado_de` lleno. Primer uso: licitación consolidada LA-006000993-E4-2019 (OCAMIS-FED-28b). Decisión de Edu, 2026-10-24. Si el procedimiento no coincide no es duplicado: 227 filas de OCAMIS-FED-02 que apuntaban al tablero con otro procedimiento volvieron a `TRUE` el 2026-10-24 con la nota `[X04 2026-10-24]` |
| `[MENUDEO_FARMACIA]` | Proveedor de menudeo, farmacia comercial (RFC `FGG0309129E1`, FARMACIA GYG). Sigue `TRUE`: el análisis reporta tres medianas por clave (con, sin y ponderada por cantidad). Añadida en v1.5 |
| `[ENVASE_CORREGIDO 2026-10-16b]` | Envase o clave corregidos tras «Cabos sueltos de datos 2026-10-16». Añadida en v1.5 |
| `[CLAVE_EXCLUIDA_COMPENDIO 2025-12-30]` | Compra de 2026 de `040.000.4486.00` o `010.000.5486.00`, claves excluidas del Compendio por el DOF 2025-12-30 (sidof 5777510). Siguen en el universo y la fila conserva su valor de `comparable` (decisión de Edu, 2026-10-17) |
| `[VERIF_CIEGA 2026-10-18]` | Cifras transcritas a mano sobre la imagen de un escaneo y confirmadas por una segunda lectura independiente del mismo recorte, sin ver la primera. Primer uso: contratos del ISSEMYM en IPOMEX (`fuente = Portal estatal (México)`). La fila arranca con su id de staging (`[IPOMEX-0001]`) |
| `[CANTIDAD_100PCT_CLAVE]` | El anexo del contrato imprime la cantidad del 100 % de la clave aunque la partida se reparte entre proveedores (ISSEMYM, CIR021/016 y 017 de 2019-2020). La fila carga el 100 %, y la parte del proveedor va calculada en la nota. El precio unitario no depende del reparto |
| `[CANTIDAD_FUENTE_AMBIGUA]` | El anexo no dice si la cantidad es el 100 % de la clave o solo la parte del proveedor. El precio unitario no depende de eso |
| `[DIGITO_CORREGIDO_POR_CIERRE]` | Una cifra borrosa se fijó porque es la única lectura que cierra cantidad × precio = importe. Se documenta el cálculo en la nota |
| `[CLAVE_POR_DESCRIPCION]` | El documento no imprime la clave CNIS y la clave se asignó por la descripción completa (principio activo, concentración, forma y envase), documentada en la nota. Si la descripción no distingue `.00` de `.01` o la concentración, la fila lleva `[CLAVE_INFERIDA]` y va `FALSE`. Añadida el 2026-10-18 (OCAMIS-EST-38) |
| `[ADJUDICACION_SUGERIDA_EN_DICTAMEN]` | El ganador sale del dictamen base para el fallo, firmado, y no del acta de fallo, que no se entregó. Sigue `TRUE` (decisión del 2026-10-18 por recomendación): el precio es el de la oferta ganadora firmada |
| `[PRECIO_NO_ADJUDICADO]` | Oferta de un licitante que no ganó la partida. `FALSE`. Sirve para documentar la dispersión de ofertas |
| `[ADJUDICACION_NO_CONFIRMADA]` | El precio sale de una propuesta o cotización sin documento que confirme que esa partida se adjudicó. `FALSE`. Añadida en v1.5 |
| `[ADJUDICACION_POR_CIERRE_DE_MONTO]` | La adjudicación se infiere porque las partidas de la propuesta suman exactamente el monto del contrato. Añadida en v1.5 |
| `[CLAVE_CORTA]` | El documento imprime la clave abreviada (p. ej. `1042.00`) sin el prefijo de grupo. Añadida en v1.5 |

## Archivos auxiliares

- `Datos/exclusiones.csv`: `id_contrato_fuente, fuente, motivo, fecha`. Todo lo descartado en el triage textual, con motivo. Esperar 3% a 10% del universo.
- `Datos/staging/<agente>_<fecha>.csv`: cada agente escribe en su propio archivo con el mismo esquema. El merge a `base_precios.csv` es serial y lo hace una sola sesión, después de validar esquema y duplicados.
- `Datos/claves_nucleo_30.csv`: universo. Columnas `clave_cnis`, `clave_cnis_num` (sin puntos, para grep en textos OCR), `componente`, `presentacion`, `envase`, `forma_farmaceutica`, `area`, `prioridad_ocamis`, `reportes_desabasto_2019_2024`.

## Pendiente de cerrar en el Prompt 1

- ~~Confirmar que clave, cantidad, precio unitario e importe coexisten en los documentos de alto rendimiento~~ **Cerrado el 2026-09-08 con la carga: las cuatro coexisten en 1,214 filas y el cierre aritmético se cumple en el 100% con desvío máximo de 0.000000%.** El resto del punto sigue vigente para otras fuentes: Ya verificado en dos fuentes el 2026-09-07: el tablero de monitoreo de compra consolidada trae las cuatro en dato estructurado (1,214 filas del núcleo, validación cantidad × precio = valor sostenida), y el acta de fallo del Instituto Nacional de Geriatría las trae en tabla con capa de texto.
- ~~Confirmar tasa de IVA aplicada en los documentos.~~ **Cerrado el 2026-09-08 en el sondeo de 10 documentos (ver sección final): 0% para medicamentos, confirmado en 8 de 9 bloques de proveedor de una misma acta, con un caso de 16% en un bien de otro grupo de clave (fuera del núcleo).**
- ~~Decidir si `unidades_por_envase` se toma de `claves_nucleo_30.csv` (envase declarado en el CNIS) o del documento cuando difieran.~~ **Cerrado (ver decisión 0 arriba): se toma del Compendio. El sondeo del 2026-09-08 no encontró ninguna discrepancia de envase en las 6 filas verificadas, así que la excepción `[ENVASE_DISCREPANTE]` queda documentada pero sin casos activados todavía.**

## Sondeo de unidad de comparación (P1, 2026-09-08)

Paso 1 del protocolo de extracción: antes de escalar la carga, se somete la unidad de comparación (precio por envase por clave, envase tomado del Compendio, año imputado al primer año del ciclo bianual) a 10 documentos reales, y se cierra la única decisión que seguía abierta, la regla de IVA. Los tres primeros puntos ya habían quedado fijados de hecho al cargar el tablero de monitoreo (1,214 filas); este sondeo los pone a prueba contra documentos de compra por partida, que es un tipo de fuente distinto.

**Limitación territorial, declarada y no resuelta en este paso.** La v1.0 del prompt pedía 3 documentos de institución de salud estatal y 3 órdenes de compra municipales como "formato de oro" del protocolo, tomados del buscador temático de la Plataforma Nacional de Transparencia (PNT). Ese buscador está **caído por falla del servidor**, verificado el 2026-09-08 con el desafío de Cloudflare resuelto a mano: el endpoint de consulta aborta a los 90 segundos y la interfaz normal tampoco responde. Los 10 documentos de este sondeo son, por lo tanto, **exclusivamente federales**. La variedad territorial (formato de acta estatal o municipal, que puede tener su propia lógica de IVA, de envase o de unidad) **queda sin probar** y se cubre en el Prompt 4 cuando haya una vía de acceso a la capa estatal. Esto no es un sondeo completo del protocolo, es un sondeo de la capa federal.

### Los 10 documentos

| # | Institución | Documento (expediente ComprasMX) | Año | Clave núcleo escrita | Cantidad | Precio unitario | Importe | Cierre aritmético (1%) | IVA | Envase coincide con Compendio | Canal | Páginas hasta la tabla | Escaneado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ISSSTE (Oficina Poniente) | Abasto y Suministro en Fármacos Gadec, `C-2025-00067556`, ActaFalloMed.pdf | 2025 | No (solo partida numérica y nombre de componente en una nota de cancelación; sin clave CNIS) | No | No | Agregado por proveedor, no por clave | No aplica | No consta | No aplica | No consta | No aplica (tabla resumen sin desglose, hacia el final del acta) | No (texto nativo completo, 98,517 caracteres) |
| 2 | Instituto Nacional de Geriatría | Boehringer Ingelheim México, `C-2025-00014656`, único documento disponible es el Anexo Técnico | 2025-2026 | No consta (no se descargó ni existe en la fuente un acta de fallo u oficio para este expediente, solo el anexo) | No | No | No | No aplica | No consta | No aplica | No consta | No aplica | Sí (36 páginas, 36 caracteres de texto extraído) |
| 3 | Instituto Nacional de Geriatría | Comercializadora de Múltiples Productos Zagal, `C-2026-00050805`, acta_de_fallo-firmada.pdf | 2026 | Sí (6 claves del núcleo de 37 claves totales en el acta; 5 adjudicadas, 1 desechada) | Sí (mínimo y máximo, contrato abierto) | Sí | Sí (mínimo y máximo) | Sí, exacto en las 5 filas adjudicadas (0% de desvío) | **0% explícito en 8 de 9 bloques de proveedor con medicamento; 16% en el único bloque con material de curación (tiras reactivas, clave 080.889.2533, fuera del núcleo)** | Sí en las 5 claves verificadas | Ambulatorio | ≈7 (tabla comparativa de precios ofertados), ≈10 (tabla de fallo por proveedor), de 21 | No (texto nativo completo, 1,227 líneas) |
| 4 | CENAPRECE | Laboratorios PISA, `C-2025-00052964` | 2025 | No consta (los tres documentos descargados son de imagen, sin capa de texto legible) | No | No | No | No aplica | No consta | No aplica | No consta | No aplica | Sí (los tres documentos, 26-76 caracteres de texto extraído cada uno) |
| 5 | Instituto Nacional de Geriatría | Prevención y Soluciones K-B, `C-2025-00067550`, ACTA_FALLO.pdf | 2025 | No consta | No | No | No | No aplica | No consta | No aplica | No consta | No aplica | Sí (236 bytes de texto, ya medido antes de este sondeo; sin intento de OCR, según instrucción explícita) |
| 6 | Instituto Nacional de Geriatría | Sanofi Pasteur, `C-2025-00007756` | 2025 | Sí, pero solo en anexos de junta de aclaraciones y de demanda agregada (259 menciones), no en un acta de fallo | No | No | No | No aplica | No consta | No aplica | No consta | No aplica | No (los documentos disponibles tienen texto, pero ninguno de los descargados es el acta de fallo: `[DOC_NO_CORRESPONDE]`) |
| 7 | BIRMEX, para IMSS + IMSS Bienestar + ISSSTE · **corregido en la revisión: se carga desglosado en 3 filas, una por institución** | Farmacéutica Medikamenta, `C-2026-00011172`, oficio de adjudicación BIRMEX/DAF/601/2026 | 2026 | Sí (1 clave, compra emergente de clave única) | Sí (mínimo y máximo, contrato abierto) | Sí | Sí (mínimo y máximo) | Sí, exacto | No consta (el oficio no desglosa impuesto en ningún renglón) | Sí (30 tabletas) | Ambulatorio | 1 | Sí, **rescatado con un intento de OCR (pdftoppm 300 ppp + tesseract -l spa), éxito** |
| 8 | Instituto Nacional de Geriatría | Grupo Gesber, `C-2025-00066941`, ACTA_FALLO.pdf | 2025 | No consta | No | No | No | No aplica | No consta | No aplica | No consta | No aplica | Sí (236 bytes de texto, ya medido antes de este sondeo; sin intento de OCR, según instrucción explícita) |
| 9 | IMSS, UMAE Hospital Regional de Especialidades No. 25, Monterrey, Nuevo León | Adita Arteaga Trejo, `C-2023-00118342`, FALLO_114.pdf | 2023 | Sí (clave núcleo 010.000.5489.00, quetiapina, en 2 de 84 partidas) | No | No | No | No aplica | No consta | No se pudo verificar (el acta no da presentación) | Hospitalario (hospital de especialidades) | 1 | Sí, **rescatado con un intento de OCR, éxito en la lectura, pero el formato de esta acta (adjudicación directa nacional a nivel hospital regional) no publica cantidad, precio ni importe: solo partida, proveedor, clave y % asignado** |
| 10 | Instituto Nacional de Enfermedades Respiratorias Ismael Cosío Villegas | Ambiderm, `C-2024-00147029`, JUSTIFICACIÓN_CASO_22_EXTRA_2024 | 2024 | Sí (1 clave del núcleo, insulina humana 010.000.1051.01, de 12 claves con formato CNIS en el documento) | Sí (131 mínimo, 327 máximo, legible) | **No con certeza**: carácter corrupto en la extracción de texto (`$fil.00`); el intento único de OCR sobre la página no lo recuperó | Sí (mínimo $7,841.14, máximo $19,602.86) | No verificable con el precio tal como consta (ilegible); el precio derivado de importe/cantidad (~$59.90) sí cierra, pero no se declara como leído | No consta (el documento es una justificación de investigación de mercado para adjudicación directa por excepción, no un acta de fallo con Subtotal/IVA/Total) | No se pudo comparar (el nombre del envase no aparece completo en el fragmento legible) | Hospitalario (envase en frasco ámpula) | ≈5 de 19 | Texto nativo con corrupción parcial en columnas numéricas: no es un escaneo puro (153,233 caracteres extraídos), pero tampoco es confiable línea por línea |

### La regla de IVA, con evidencia

**Se sostiene la hipótesis del diccionario, con una condición más precisa que la que se planteó al abrir la decisión.** No es que "los documentos" declaren 0% o 16% según la fuente o la institución: es que **el tipo de bien** determina la tasa. En la misma acta de fallo (Comercializadora Zagal, `C-2026-00050805`), **9 de los 10 bloques** de proveedor con medicamentos (claves de grupo `010.xxx` y `040.xxx`, que es la totalidad del núcleo de 52 claves del proyecto) declaran IVA en cero, ocho como `$0.00` y uno como guion, subtotal igual a total. El único bloque de los 10 con IVA distinto de cero es el del proveedor que vendió tiras reactivas para glucómetro (clave `080.889.2533`, material de curación/diagnóstico, no medicamento): ahí el IVA es de $1,104.00 sobre $6,900.00 y de $1,840.00 sobre $11,500.00, exactamente 16% en los dos casos ($6,900 × 0.16 = $1,104; $11,500 × 0.16 = $1,840). Esto confirma y explica el hallazgo previo de Edu sobre el acta del Instituto Nacional de Geriatría (`C-2026-00050805`... el mismo documento, cuatro bloques en $0.00) y es consistente con que México aplica tasa 0% de IVA a medicamentos y tasa general del 16% al resto de los bienes, incluido material de curación. ⚠️ **El P1 atribuyó esa regla al "artículo 2-A de la Ley del IVA" y esa cita NO está verificada:** no hay texto de esa ley en la bóveda ni en ningún documento de disco leído en la sesión. Es el mismo tipo de afirmación por asociación desde memoria que ya apareció con el artículo 65. **Lo verificado es la evidencia documental** (los diez bloques del acta), no el fundamento legal. Antes de citar el artículo en un informe o en una solicitud, hay que confirmarlo.

**Decisión:** la columna `iva` queda en **`0%` por defecto para toda fila cuya `clave_cnis` sea del núcleo de 52 (grupos `010.xxx` y `040.xxx`)**, sin necesidad de caso por caso dentro de ese universo. La regla de caso por caso que preveía el prompt **no se activa para medicamentos**, pero **si el proyecto en algún momento incorpora bienes de otro grupo de clave** (material de curación, dispositivos), esa fila sí necesita verificación individual, porque ahí la tasa general del 16% es la que aplica. Cuando el documento no desglosa IVA en absoluto (caso Medikamenta/BIRMEX, un oficio sin tabla de Subtotal/IVA/Total), la columna queda en `no consta`, no se asume 0% por generalización.

### Ambigüedad de la regla de IVA que hay que resolver

La regla quedó escrita con dos cláusulas que se contradicen en el caso mayoritario:

1. `iva = 0%` por defecto para toda fila cuya clave sea del núcleo (grupos `010.xxx` y `040.xxx`).
2. Cuando el documento **no desglosa IVA en absoluto**, la columna queda en `no consta` y no se asume 0% por generalización.

El tablero de monitoreo de compra consolidada **no publica ningún campo de impuesto**, así que cae en la cláusula 2. Resultado actual medido: **1,217 de 1,222 filas tienen `iva = no consta`**, incluidas las 1,214 del tablero. Es decir, la cláusula 1 casi no se aplica y la regla "0% por defecto" es, en la práctica, letra muerta.

| Fuente | `0%` | `no consta` |
|---|---|---|
| ComprasMX (documentos leídos) | 5 | 3 |
| Monitoreo compra consolidada | 0 | 1,214 |

**Por qué no es grave y por qué igual hay que decidirlo.** Si la tasa es efectivamente 0% para medicamentos, entonces el precio publicado **es** el precio, con o sin la columna, y la comparabilidad entre fuentes no se rompe. El riesgo real no es aritmético, es de interpretación: dejar 1,214 filas en `no consta` sugiere una incertidumbre sobre el impuesto que la evidencia documental no respalda.

Las dos salidas posibles, y es decisión de Edu:

- **A.** Mantener `no consta` cuando la fuente no publica el campo, y explicar en el informe que para medicamentos la tasa es 0% y por eso el precio es comparable. Más conservador, y no requiere tocar nada.
- **B.** Poner `0%` en toda fila del núcleo, con una nota que diga que la tasa se infiere del tipo de bien y no del documento. Más limpio de leer, pero mete una inferencia dentro de un campo de dato.

Mientras no se decida, queda la opción A, que es el estado actual.

**Decidido el 2026-11-07 (Edu): opción A.** La columna queda en `no consta` cuando la fuente no publica el impuesto, y la nota metodológica explica que los medicamentos tributan a tasa 0%, por lo que el precio es comparable entre órdenes de gobierno.

### Las otras tres decisiones, puestas a prueba

- **Unidad primaria (precio por envase por clave):** se sostiene sin conflicto en las 6 filas comparables de este sondeo. Ningún documento reportó el precio en una unidad distinta al envase completo.
- **Envase desde el Compendio:** se sostiene. Las 6 filas comparables tienen envase declarado en el documento y coincide exactamente con `claves_nucleo_30.csv` en las 5 filas donde el documento declara el envase con claridad (la sexta, Medikamenta, también coincide: "envase con 30 tabletas" en el oficio y en el Compendio). **No apareció ningún caso `[ENVASE_DISCREPANTE]`** en este sondeo: la excepción queda documentada y vigente, pero sin evidencia todavía que la active.
- **Ciclos bianuales:** no se pudo poner a prueba en este sondeo. Ninguno de los 10 documentos declara un ciclo bianual tipo `25.26`; esa estructura es propia del tablero de monitoreo de compra consolidada (fuente ya cargada con 1,214 filas), no de las actas de fallo de ComprasMX. La decisión sigue firme sobre la evidencia original, sin contradicción nueva ni confirmación nueva.

### Corrección aplicada en la revisión del P1 (2026-09-08, sesión principal)

El P1 cargó el oficio de BIRMEX como **una sola fila** con `institucion_compradora = "IMSS, IMSS Bienestar e ISSSTE"`, y lo justificó bien: el desglose por institución se había degradado en el reconocimiento óptico de caracteres y prefirió no inventar una cifra. Fue la decisión correcta con la evidencia que tenía.

La revisión rehizo el reconocimiento óptico con `-c preserve_interword_spaces=1` y la segunda tabla del oficio ("Cantidades que se desglosan de la siguiente manera") **sí es legible**. Faltaba **una sola celda**, el mínimo del ISSSTE, y se reconstruyó por tres caminos independientes que cierran al peso:

| Camino | Comprobación |
|---|---|
| Cierre de la suma de mínimos | 255,315 + 284,928 + X = 600,001 → **X = 59,758** |
| Regla del 40%, que cumplen los otros dos institutos | 149,394 × 0.4 = 59,757.6 → **59,758**. IMSS 255,315/638,286 = 0.40000 e IMSS Bienestar 284,928/712,320 = 0.40000 |
| Cierre de importes contra la primera tabla | (255,315 + 284,928 + 59,758) × $24.00 = **$14,400,024.00**, el importe mínimo leído en el oficio |
| Cierre de máximos | 638,286 + 712,320 + 149,394 = **1,500,000**, el máximo leído |

De paso quedó explicado el "1" extraño del total: viene de **dos redondeos hacia arriba** (255,314.4 → 255,315 y 59,757.6 → 59,758). Al principio pareció un error de lectura, y no lo era.

**Por qué importaba corregirlo, más allá de la precisión:** una fila que agrega tres instituciones rompe dos cosas del diccionario. El análisis por institución, que es un eje del proyecto, y la deduplicación por `id_procedimiento`. El grano de la base es una clave-presentación **dentro de un contrato o partida**, y acá había tres partidas distintas.

Resultado: 3 filas en lugar de 1, con `[CIFRA_RECONSTRUIDA]` en la del ISSSTE y solo en su cantidad mínima, porque su máximo sí está leído.

### Hallazgos nuevos para el Prompt 2 (trampas que este sondeo pagó, para no repetirlas)

1. **Un documento titulado "JUSTIFICACIÓN" puede ser una investigación de mercado para sustentar una adjudicación directa por excepción, no el acta de fallo con el precio ya adjudicado.** El caso 10 (Ambiderm/INER) es justo eso: la tabla de precios que trae es la que sustenta la excepción a la licitación pública, no necesariamente el precio final pagado. Hay que distinguir el tipo de documento antes de tratar cualquier tabla como precio de compra.
2. **Las actas de "Comunicación de Fallo" de adjudicación directa nacional a nivel de hospital regional del IMSS (formato UMAE) no traen cantidad, precio ni importe:** solo publican partida, proveedor, clave/CUCOP+, unidad de medida y porcentaje asignado (caso 9). El detalle económico vive en el pedido o contrato derivado, que no se descarga junto con el acta en ComprasMX. Esto es distinto de las actas de compra consolidada a nivel de instituto federal (Instituto Nacional de Geriatría, BIRMEX), que sí traen precio unitario, cantidad mínima/máxima e importe en la misma acta.
3. **Existe un tercer estado de "escaneado", entre texto nativo limpio y escaneo puro:** un PDF puede tener una capa de texto con miles de caracteres extraíbles y aun así tener las columnas numéricas corrompidas por un mapeo de fuente defectuoso (caso 10). El filtro binario de bytes de texto (`pdftotext` devuelve casi nada = escaneado) no detecta este caso, porque el conteo total de caracteres es alto. El Prompt 2 necesita un chequeo adicional: si una columna numérica clave (precio unitario) sale con caracteres no numéricos, tratar la fila como ilegible aunque el documento tenga texto.
4. **Un mismo proveedor puede tener dos expedientes de ComprasMX distintos en la misma carpeta, con títulos que sugieren cosas diferentes** ("compra consolidada" vs. "compra de claves desconsolidadas"), aunque ambos pertenezcan a la misma institución. Hay que leer el título interno de cada acta, no asumir que el título del expediente en el índice describe todos los documentos de la carpeta.
5. **Confirmado: los anexos técnicos y formatos de propuesta económica siguen siendo plantillas sin datos** (casos 2 y 4 de este sondeo), consistente con lo ya medido antes de este prompt. No vale la pena gastar el intento de OCR en ellos salvo que sea el único documento disponible del expediente.
