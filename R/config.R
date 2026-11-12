# Configuration for the price analysis: every path, tag and constant lives here.
# The data folder defaults to the tm-precios-salud repo on Fedora and can be
# overridden on any machine with the environment variable TM_PRECIOS_DATA.

config <- list(
  ruta_datos = Sys.getenv(
    "TM_PRECIOS_DATA",
    unset = "/home/castanedaprado/repos/tm-precios-salud/data"
  ),
  archivo_base = "base_precios.csv",
  archivo_universo = "claves_eje_salud_mental_diabetes_40.csv",
  dir_salidas = "salidas",

  # Monthly general INPC (Banxico SIE, series SP1), written by
  # R/01_preparar_inpc.R. Relative to the "Analisis precios" folder.
  ruta_inpc = "datos/inpc_general_mensual.csv",
  # Prices are also reported in pesos of this year (decision of 2026-11-06).
  año_base_deflacion = 2025L,

  # Unit of comparison. The data dictionary (section "Decisiones tomadas en la
  # primera carga", point 0) makes the price per package the primary unit;
  # "precio_por_unidad_minima_mxn" is the derived alternative.
  columna_precio = "precio_unitario_envase_mxn",

  # Tags read from notas_metodologicas. Since the base of 2026-11-07 the 339
  # HGM rows tagged "[ENTRADA_DE_ALMACEN]" are non-comparable (anchor
  # filas_entrada_almacen = 0), so the switch excludes no row today; it stays
  # as a record. The dictionary also lists the variant "[ENTRADA_ALMACEN]"
  # (105 comparable rows, INCAN and SEMAR, kept comparable with their written
  # correction); add it here to widen the switch.
  etiquetas_entrada_almacen = c("[ENTRADA_DE_ALMACEN]"),
  etiqueta_menudeo = "[MENUDEO_FARMACIA]",
  # Federal award of a two-year cycle, imputed to its first year (dictionary,
  # rule 1). See copias_segundo_año_ciclo() in filtrar.R.
  etiqueta_ciclo_bianual = "[CICLO_BIANUAL]",
  # Channel reported apart, in the annex tables (decision of 2026-11-08).
  canal_anexo = "hospitalario",
  # Keys read as ambulatory channel whatever the base's `canal` says (Andrés,
  # 2026-11-08): insulins are dispensed in first-level care, though the base
  # files most of their federal rows as hospital. Applied once, to a copy of
  # the base, by reclasificar_canal() (filtrar.R) before any channel filter;
  # the switch is lectura_principal$reclasificar_canal. Names: component.
  claves_canal_ambulatorio = c(
    "insulina glargina" = "010.000.4158.00",
    "insulina humana" = "010.000.1050.00",
    "insulina humana" = "010.000.1051.00"
  ),

  umbral_claves = 30,

  # OCAMIS prescriptions (quality comparator, Andrés 2026-11-08): sheet
  # "datos", one row per ISO week x institution x state x key, quantities in
  # boxes. Relative to the "Analisis precios" folder; read-only. The data end
  # in early 2024, so 2023 is the last complete year.
  ruta_ocamis = "../OCamis Abasto/ocamis_43_claves_semana_institucion_estado.xlsx",
  año_prescripcion = 2023L,
  # Base tipo_institucion -> OCAMIS institución.
  instituciones_ocamis = c(IMSS = "IMSS (Ordinario)", ISSSTE = "ISSSTE"),

  # State context (R/marginacion.R), relative to the "Analisis precios"
  # folder, read-only: CONAPO 2020 marginalisation by state, and the INEGI
  # 2020 census tabulation of indigenous-language speakers (sheet "02").
  ruta_marginacion = "datos/conapo_marginacion_2020.csv",
  ruta_lengua_indigena = "datos/inegi_censo2020/cpv2020_b_eum_05_etnicidad.xlsx",

  # Supply orders of the federal consolidated purchase (SSA, "Plataforma de
  # monitoreo de medicamentos", extraction of 2026-11-09; R/entregas.R),
  # relative to the "Analisis precios" folder, read-only. Volumes only, no
  # prices. When the orders file is absent the run skips the delivery tables;
  # the supplier tab only feeds the cross-check entregas_control.
  ruta_entregas = "../Plataforma entrega medicamentos/datos/ordenes_suministro.csv",
  ruta_cumplimiento_proveedores =
    "../Plataforma entrega medicamentos/datos/cumplimiento_proveedores.csv",

  # Values the loader must reproduce on the base of 2026-11-07 (Edu's PR #2:
  # 339 HGM warehouse-entry rows set to non-comparable, 2,489 federal rows of
  # the 25-26 consolidated cycle reimputed from 2026 to 2025). They describe
  # one version of the file: update them when the base is reloaded.
  anclas = list(
    filas = 20038,
    filas_comparables = 8736,
    claves_con_precio = 42,
    claves_sin_precio = "040.000.2614.00",
    claves_imss_issste = 25,
    claves_imss_issste_2025 = 19,
    entidades_estatales = 11,
    filas_entrada_almacen = 0
  )
)

config$ruta_base <- file.path(config$ruta_datos, config$archivo_base)
config$ruta_universo <- file.path(config$ruta_datos, config$archivo_universo)

periodos_validos <- c("todo", "2019_2026", "2024_2027", "2024_2025",
                      "solo_2025")

comparaciones_validas <- c(
  "imss_issste", "tres_federales", "federal_todas", "entidades",
  "federal_vs_estatal"
)

interruptores <- c(
  "excluir_entrada_almacen_hgm", "excluir_duplicados_exactos",
  "excluir_menudeo", "solo_ambulatorio"
)

# Row filters of the principal (headline) reading (my label: "lectura base"):
# fiscal years 2024 and 2025, ambulatory channel only, no other exclusion.
# sensibilidad counts how many of these parameters each row changes.
# periodo = "2024_2025": Andrés, 2026-11-08 (late), as Edu proposed (decision
# (6) of 2026-11-07 in the data dictionary); it replaces "solo_2025". The
# same-year rule stays: a state-key pair is compared within its own fiscal
# year, and a key counts as compared if it is compared in 2024 or in 2025.
# solo_ambulatorio = TRUE: Andrés, 2026-11-08, following Edu's decision (3) of
# 2026-11-07 in the data dictionary (hospital channel out of the principal
# indicator, first-level-of-care scope, adr-0002 of the repo). Hospital rows
# are compared apart in anexo_canal_hospitalario.
lectura_base <- list(
  periodo = "2024_2025",
  excluir_entrada_almacen_hgm = FALSE,
  excluir_duplicados_exactos = FALSE,
  excluir_menudeo = FALSE,
  solo_ambulatorio = TRUE
)

# Context series (Andrés, 2026-11-08): the same filters over fiscal years
# 2019-2026. Every table by year (medians, series, dispersion, gaps, coverage,
# hospital annex) uses it; fiscal 2027 (cycle 27.28) stays in the base but out
# of these tables. The headline rows are marked inside them (principal.R).
lectura_contexto <- utils::modifyList(lectura_base, list(periodo = "2019_2026"))

# Label of the pooled federal group in federal_vs_estatal.
etiqueta_federal <- "Federal (agrupado)"

# Group that must be among the compared groups for a key to count as
# "comparada", per comparison. Comparisons not listed require none.
grupos_requeridos <- list(federal_vs_estatal = etiqueta_federal)

# Principal reading, decided by Andrés on 2026-11-06: federal vs states, and a
# key counts as "comparada" when, in the same fiscal year, it has the pooled
# federal median and the median of at least one entidad. The pooled-period
# count stays as a secondary column. Row filters are those of lectura_base
# (fiscal 2024-2025); the context tables use lectura_contexto.
#
# Indicator: the quantity-weighted median price (mediana_ponderada_cantidad),
# decided by Edu on 2026-11-07 (record 2026-11-07-sincronizacion-de-la-boveda-
# correccion-hgm-y-xlsx in tm-precios-salud) and accepted by Andrés the same
# day. The per-row median ("mediana") stays in every table as sensitivity, and
# the indicator with and without retail-pharmacy rows (excluir_menudeo) is
# reported in sensibilidad. Allowed values: indicadores_validos (indicadores.R).
#
# ciclo_bianual_segundo_año: in federal_vs_estatal a federal price of a
# biannual cycle is also the federal reference of the cycle's second year
# (Andrés, 2026-11-08; Edu's decision (4) of 2026-11-07). Only that reference
# reads it; medians, series, dispersion and coverage keep one row per award.
#
# reclasificar_canal: the keys of config$claves_canal_ambulatorio count as
# ambulatory channel (Andrés, 2026-11-08). FALSE reads the base's `canal` as
# is; the LEEME sheet reports the headline both ways.
lectura_principal <- list(
  comparacion = "federal_vs_estatal",
  regla_comparada = "mismo_año",
  grupo_requerido = etiqueta_federal,
  indicador = "mediana_ponderada_cantidad",
  ciclo_bianual_segundo_año = TRUE,
  reclasificar_canal = TRUE,
  filtros = lectura_base
)
