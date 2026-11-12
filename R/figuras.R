# Figures for the final report (TMX CAIS-T2-C1, informe final).
#
# Reads only finished tables of the analysis layer (salidas/*.csv) plus one
# read-only side input (the state geometry); never re-runs or modifies the
# pipeline, and is NOT sourced by R/00_correr_todo.R.
#
#   salidas/brecha_federal_estatal.csv        figures 1 and 3 (par_principal)
#   salidas/cruce_marginacion_entidad.csv     figure 2
#   salidas/serie_real_por_clave.csv          figure 4
#   salidas/compra_vs_prescripcion_clave.csv  figure 5 (ISSSTE, 2023)
#   salidas/cobertura_entidad.csv             figure 3 (axis) and 5 (axis)
#   salidas/cobertura_marginacion_entidad.csv figure 6 (32 states, coverage
#                                             category and CONAPO 2020 grade)
#   INEGI state geometry (ruta_geometria)     figure 6 map
#
# Output (salidas/figuras/):
#   fig1..fig6 *.png  300 dpi, 5.35 in wide = text width of the TMX template
#                     body (Letter, 2267-twip side margins)
#   figuras_meta.csv  number, file, title, subtitle, note, source and the
#                     placeholder substring; the Word build reads it, so the
#                     caption text lives in one place (here).
#
# Title and subtitle are drawn inside the image, as in the template's sample
# figure (which also repeats a short "Figura N. <title>" caption above it and
# a "Fuente:" line below). Set TITULO_EN_IMAGEN <- FALSE to drop them from
# the PNG and leave them only in the Word caption.
#
# Run from the "Analisis precios" folder:  Rscript R/figuras.R

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(ggrepel)
  library(scales)
  library(sf)
})

if (!file.exists("R/config.R")) {
  stop("Corre este script desde la carpeta 'Analisis precios'.", call. = FALSE)
}
TITULO_EN_IMAGEN <- TRUE

dir_salidas <- "salidas"
dir_figuras <- file.path(dir_salidas, "figuras")
dir.create(dir_figuras, showWarnings = FALSE, recursive = TRUE)

ruta_geometria <-
  "/home/castanedaprado/OneDrive/Documentos/map_mex/conjunto_de_datos/00ent.shp"

# ---- Shared look: TMX institutional palette, white background -------------

tmx <- list(
  azul = "#2B3F83", verde = "#44AD49", gris = "#7F7F7F", claro = "#F5F5F5",
  texto = "#1A1A1A", reja = "#E3E3E3"
)

# Calibri is not installed on this machine; Carlito is its metric-compatible
# clone (same widths), so text set here occupies the same space as Calibri.
fuente <- if (nrow(systemfonts::match_fonts("Calibri")) > 0 &&
              grepl("calibri", systemfonts::match_fonts("Calibri")$path,
                    ignore.case = TRUE)) "Calibri" else "Carlito"

ancho_in <- 5.35 # template body text width (7706 twips)

tema_tmx <- function(base = 9) {
  theme_minimal(base_size = base, base_family = fuente) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      panel.grid.major = element_line(colour = tmx$reja, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      text = element_text(colour = tmx$texto),
      axis.text = element_text(colour = tmx$texto, size = base - 0.5),
      axis.title = element_text(colour = tmx$texto, size = base),
      plot.title = element_text(face = "bold", size = base + 3,
                                colour = tmx$azul, margin = margin(b = 3)),
      plot.subtitle = element_text(size = base, colour = tmx$texto,
                                   margin = margin(b = 8)),
      plot.caption = element_text(size = 8, colour = tmx$gris, hjust = 0,
                                  margin = margin(t = 8)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      legend.position = "top",
      legend.justification = "left",
      legend.title = element_text(size = base),
      strip.text = element_text(face = "bold", size = base, hjust = 0),
      plot.margin = margin(8, 10, 6, 6)
    )
}

# Decimal point and thousands comma, as TMX writes numbers.
num <- function(x, acc = 0.01) number(x, accuracy = acc, big.mark = ",",
                                      decimal.mark = ".")

etiqueta_componente <- function(x) {
  x <- str_to_sentence(str_to_lower(x))
  recode(x, "Anfebutamona o bupropión" = "Bupropión")
}

# ---- Figure metadata (title, subtitle, note, source) ----------------------

fuente_base <- paste(
  "elaboración propia de Nosotrxs con la base de precios de compra pública",
  "del proyecto (corte del 7 de noviembre de 2026), integrada con respuestas",
  "a solicitudes de acceso a la información, el tablero de la compra",
  "consolidada de la Secretaría de Salud, IPOMEX, la PNT y ComprasMX."
)

meta <- tribble(
  ~numero, ~archivo, ~marcador, ~titulo, ~subtitulo, ~nota, ~fuente,
  1, "fig1_distribucion_razon.png", "distribución de la razón",
  "Distribución de la razón estatal/federal",
  "Razón estatal/federal en los 204 pares entidad-clave-año, años fiscales 2024 y 2025",
  "Razón = mediana ponderada por cantidad del precio por caja en la entidad entre la del ámbito federal agrupado, en el mismo año. Escala logarítmica; la línea vertical marca la paridad (1).",
  paste("Fuente:", fuente_base),
  2, "fig2_razon_por_entidad.png", "razón mediana por entidad",
  "Razón estatal/federal por entidad",
  "Mediana de la razón estatal/federal por entidad, años fiscales 2024 y 2025",
  "Entre paréntesis, el número de pares entidad-clave-año de cada entidad. La línea vertical marca la paridad (1).",
  paste("Fuente:", fuente_base),
  3, "fig3_razon_por_clave.png", "35 claves",
  "Razón estatal/federal por clave",
  "Mediana de la razón estatal/federal en las 35 claves comparadas, años fiscales 2024 y 2025",
  "Entre paréntesis, el número de pares de cada clave. Escala logarítmica; la línea vertical marca la paridad (1).",
  paste("Fuente:", fuente_base),
  4, "fig4_serie_real.png", "precio real por caja",
  "Precio real por caja, federal y estatal",
  "Precio por caja en pesos de 2025, mediana ponderada por cantidad, 2019-2026",
  "Estatal: todas las entidades juntas. Los años sin punto no tienen compras comparables de ese lado. Pocas filas en los primeros años: la serie muestra tendencias, no la brecha año por año.",
  paste("Fuente:", fuente_base,
        "Deflactado con el Índice Nacional de Precios al Consumidor (INPC) del INEGI."),
  5, "fig5_compra_vs_prescripcion.png", "compra y prescripción del ISSSTE en 2023",
  "Compra y prescripción del ISSSTE en 2023, por clave",
  "Cajas compradas contra cajas prescritas por el ISSSTE en 2023, una clave por punto",
  "Compra: filas comparables de la base del año fiscal 2023, de cualquier canal, con la cantidad mínima de los contratos abiertos. Ejes logarítmicos; las claves sin compra o sin prescripción se dibujan sobre la línea punteada. La diagonal marca compra igual a prescripción. Se rotulan las claves con una razón compra/prescripción mayor que 2 o menor que 0.5.",
  paste("Fuente:", fuente_base,
        "Prescripciones del ISSSTE en 2023 reconstruidas por OCAMIS."),
  6, "fig6_mapa_cobertura.png", "mapa de las 32",
  "Cobertura de precios estatales y marginación",
  "Cobertura de precios estatales por entidad y grado de marginación 2020",
  "«Con pares»: con pares entidad-clave-año en 2024-2025. «Con filas comparables, sin par»: con precio comparable pero sin par federal en esos años.",
  paste("Fuente:", fuente_base,
        "Índice y grado de marginación por entidad federativa 2020 de CONAPO; Marco Geoestadístico del INEGI.")
)

titulos <- function(n) {
  m <- meta[meta$numero == n, ]
  if (TITULO_EN_IMAGEN) {
    labs(title = m$titulo, subtitle = m$subtitulo,
         caption = str_wrap(m$nota, 100))
  } else {
    labs(caption = str_wrap(m$nota, 100))
  }
}

guardar <- function(grafica, n, alto_in) {
  ruta <- file.path(dir_figuras, meta$archivo[meta$numero == n])
  ggsave(ruta, grafica, device = ragg::agg_png, width = ancho_in,
         height = alto_in, units = "in", dpi = 300, bg = "white")
  message("Escrita: ", ruta)
}

# Check helper: prints the plotted value next to the draft's figure. Never
# stops: a mismatch is reported, not fixed.
verificar <- function(que, calculado, borrador, tol = 0.005) {
  ok <- isTRUE(all.equal(as.numeric(calculado), as.numeric(borrador),
                         tolerance = tol, scale = 1)) ||
    isTRUE(all(abs(as.numeric(calculado) - as.numeric(borrador)) <= tol))
  message(sprintf("[%s] %s: calculado %s | borrador %s",
                  if (ok) "OK" else "DIFIERE", que,
                  paste(calculado, collapse = ", "),
                  paste(borrador, collapse = ", ")))
  invisible(ok)
}

leer <- function(tabla) {
  read_csv(file.path(dir_salidas, paste0(tabla, ".csv")),
           show_col_types = FALSE, col_types = cols(clave_cnis = "c"))
}

brecha <- leer("brecha_federal_estatal")
pares <- brecha |> filter(par_principal)
cruce <- read_csv(file.path(dir_salidas, "cruce_marginacion_entidad.csv"),
                  show_col_types = FALSE)
cobertura <- leer("cobertura_entidad")

# ---- Figure 1: distribution of the ratio over the 204 headline pairs ------

med1 <- median(pares$razon_estatal_federal)
verificar("F1 pares", nrow(pares), 204, 0)
verificar("F1 mediana", round(med1, 2), 2.65)
verificar("F1 p25 / p75", round(quantile(pares$razon_estatal_federal,
                                         c(.25, .75), names = FALSE), 2),
          c(1.66, 4.24))
verificar("F1 pares > 1", sum(pares$razon_estatal_federal > 1), 187, 0)
verificar("F1 pares > 5 / > 10", c(sum(pares$razon_estatal_federal > 5),
                                   sum(pares$razon_estatal_federal > 10)),
          c(36, 12), 0)
verificar("F1 razón máxima", round(max(pares$razon_estatal_federal), 2), 33.25)

cortes_log <- c(0.25, 0.5, 1, 2, 5, 10, 20, 40)
f1 <- ggplot(pares, aes(razon_estatal_federal)) +
  geom_histogram(binwidth = 0.1, boundary = 0, fill = tmx$azul,
                 colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = 1, colour = tmx$texto, linewidth = 0.5) +
  geom_vline(xintercept = med1, colour = tmx$verde, linewidth = 0.6,
             linetype = "dashed") +
  annotate("text", x = med1 * 1.06, y = Inf, vjust = 1.4, hjust = 0,
           family = fuente, size = 3, colour = tmx$texto,
           label = paste0("Mediana: ", num(med1))) +
  annotate("text", x = 0.97, y = Inf, vjust = 1.4, hjust = 1,
           family = fuente, size = 3, colour = tmx$gris,
           label = "El estado pagó\nmenos o igual") +
  scale_x_log10(breaks = cortes_log, labels = function(x) num(x, 0.01) |>
                  str_remove("\\.?0+$")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Razón estatal/federal (escala logarítmica)",
       y = "Pares entidad-clave-año") +
  titulos(1) +
  tema_tmx() +
  theme(panel.grid.major.x = element_blank())
guardar(f1, 1, 3.6)

# ---- Figure 2: median ratio by state with the number of pairs -------------

esperado_f2 <- tribble(
  ~entidad, ~pares_b, ~mediana_b,
  "Aguascalientes", 8, 5.53, "Coahuila de Zaragoza", 29, 4.73,
  "Puebla", 8, 3.64, "Campeche", 11, 3.52, "México", 24, 3.43,
  "Colima", 27, 3.19, "Ciudad de México", 10, 2.87, "Tlaxcala", 3, 2.65,
  "Jalisco", 48, 1.87, "Chihuahua", 36, 1.47
)
# Recompute from the pairs too, to tie table 2 (cruce) to table 1 (brecha).
f2_desde_pares <- pares |>
  group_by(entidad = entidad_federativa) |>
  summarise(pares_p = n(), mediana_p = median(razon_estatal_federal))
f2_chk <- esperado_f2 |> left_join(cruce, by = "entidad") |>
  left_join(f2_desde_pares, by = "entidad")
verificar("F2 pares por entidad (cruce)", f2_chk$pares, f2_chk$pares_b, 0)
verificar("F2 medianas por entidad (cruce)", round(f2_chk$brecha_mediana, 2),
          f2_chk$mediana_b)
verificar("F2 medianas cruce = medianas desde brecha",
          round(f2_chk$brecha_mediana, 3), round(f2_chk$mediana_p, 3), 0.001)

nombre_corto <- c("Coahuila de Zaragoza" = "Coahuila",
                  "México" = "Estado de México")
f2_datos <- cruce |>
  mutate(nombre = recode(entidad, !!!nombre_corto),
         nombre = forcats::fct_reorder(nombre, brecha_mediana),
         etiqueta = paste0(num(brecha_mediana), "  (", pares, ")"))
f2 <- ggplot(f2_datos, aes(brecha_mediana, nombre)) +
  geom_col(fill = tmx$azul, width = 0.7) +
  geom_vline(xintercept = 1, colour = tmx$texto, linewidth = 0.5) +
  geom_text(aes(label = etiqueta), hjust = -0.08, family = fuente,
            size = 3, colour = tmx$texto) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.18)),
                     labels = function(x) num(x, 1)) +
  labs(x = "Razón estatal/federal, mediana", y = NULL) +
  titulos(2) +
  tema_tmx() +
  theme(panel.grid.major.y = element_blank())
guardar(f2, 2, 3.7)

# ---- Figure 3: median ratio for the 35 compared keys, by axis -------------

ejes <- cobertura |> distinct(clave_cnis, area)
f3_datos <- pares |>
  group_by(clave_cnis, componente) |>
  summarise(pares = n(), mediana = median(razon_estatal_federal),
            .groups = "drop") |>
  left_join(ejes, by = "clave_cnis") |>
  mutate(etiqueta = paste0(etiqueta_componente(componente), " ",
                           str_sub(clave_cnis, 9), " (", pares, ")"),
         etiqueta = forcats::fct_reorder(etiqueta, mediana))

verificar("F3 claves comparadas", nrow(f3_datos), 35, 0)
chk3 <- tribble(
  ~clave_cnis, ~p, ~m,
  "040.000.2612.00", 9, 8.29, "040.000.2499.00", 6, 7.90,
  "040.000.6298.00", 1, 7.41, "040.000.2500.00", 6, 6.07,
  "010.000.5489.00", 10, 4.31, "040.000.3305.00", 3, 3.93,
  "010.000.4158.00", 9, 3.88, "010.000.5471.00", 3, 1.00,
  "040.000.3262.00", 3, 0.97, "040.000.4486.00", 1, 0.84,
  "040.000.3259.00", 3, 0.78, "010.000.5485.00", 1, 0.60
) |> left_join(f3_datos, by = "clave_cnis")
verificar("F3 pares de las claves de la tabla del borrador", chk3$pares,
          chk3$p, 0)
verificar("F3 medianas de las claves de la tabla del borrador",
          round(chk3$mediana, 2), chk3$m)
por_eje <- pares |> left_join(ejes, by = "clave_cnis") |> group_by(area) |>
  summarise(n = n(), m = round(median(razon_estatal_federal), 2))
verificar("F3 pares por eje (diabetes, salud mental)", por_eje$n, c(43, 161), 0)
verificar("F3 mediana por eje (diabetes, salud mental)", por_eje$m,
          c(2.38, 2.68))
verificar("F3 rango glargina por entidad",
          round(range(pares$razon_estatal_federal[
            pares$clave_cnis == "010.000.4158.00"]), 2), c(1.85, 6.01))

f3 <- ggplot(f3_datos, aes(mediana, etiqueta, colour = area)) +
  geom_vline(xintercept = 1, colour = tmx$texto, linewidth = 0.5) +
  geom_segment(aes(x = 1, xend = mediana, yend = etiqueta), linewidth = 0.6) +
  geom_point(size = 2) +
  geom_text(aes(label = num(mediana),
                hjust = if_else(mediana < 1, 1.35, -0.35)),
            family = fuente, size = 2.6, show.legend = FALSE) +
  scale_colour_manual(values = c("Salud mental" = tmx$azul,
                                 "Diabetes" = tmx$verde),
                      name = NULL) +
  scale_x_log10(breaks = c(0.5, 1, 2, 4, 8),
                labels = function(x) str_remove(num(x), "\\.?0+$"),
                expand = expansion(mult = c(0.12, 0.12))) +
  labs(x = "Razón estatal/federal, mediana (escala logarítmica)", y = NULL) +
  titulos(3) +
  tema_tmx(8.5) +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(size = 7.5))
guardar(f3, 3, 6.6)

# ---- Figure 4: real price per box, federal vs state, 2019-2026 ------------

claves_f4 <- c("010.000.4158.00" = "Insulina glargina · 010.000.4158.00",
               "010.000.5165.00" = "Metformina · 010.000.5165.00",
               "040.000.2612.00" = "Clonazepam 2 mg · 040.000.2612.00")
serie <- leer("serie_real_por_clave") |>
  filter(clave_cnis %in% names(claves_f4), between(año_fiscal, 2019, 2026)) |>
  select(clave_cnis, año_fiscal,
         Federal = mediana_ponderada_cantidad_federal_real_2025,
         Estatal = mediana_ponderada_cantidad_estatal_real_2025) |>
  complete(clave_cnis, año_fiscal = 2019:2026) |>
  pivot_longer(c(Federal, Estatal), names_to = "lado", values_to = "precio") |>
  mutate(panel = factor(claves_f4[clave_cnis], levels = claves_f4))

s <- function(cl, ld, an) serie$precio[serie$clave_cnis == cl &
                                         serie$lado == ld &
                                         serie$año_fiscal %in% an]
verificar("F4 glargina federal 2021 / 2025",
          round(s("010.000.4158.00", "Federal", c(2021, 2025)), 2),
          c(115.73, 62.00))
verificar("F4 glargina estatal 2023 / 2025",
          round(s("010.000.4158.00", "Estatal", c(2023, 2025)), 2),
          c(351.97, 152.82))
verificar("F4 glargina estatal, rango sin 2023 (2019-2025)",
          round(range(s("010.000.4158.00", "Estatal",
                         c(2019:2022, 2024:2025)), na.rm = TRUE), 2),
          c(138.61, 161.18))
verificar("F4 metformina federal, rango 2019-2025",
          round(range(s("010.000.5165.00", "Federal", 2019:2025),
                      na.rm = TRUE), 2), c(6.63, 10.28))
verificar("F4 metformina estatal, rango 2019-2025",
          round(range(s("010.000.5165.00", "Estatal", 2019:2025),
                      na.rm = TRUE), 2), c(12.04, 18.45))
verificar("F4 clonazepam federal, rango 2019-2025",
          round(range(s("040.000.2612.00", "Federal", 2019:2025),
                      na.rm = TRUE), 2), c(5.46, 9.76))
verificar("F4 clonazepam estatal, rango 2019-2025",
          round(range(s("040.000.2612.00", "Estatal", 2019:2025),
                      na.rm = TRUE), 2), c(21.64, 78.71))

colores_lado <- c(Federal = tmx$azul, Estatal = tmx$verde)
fin_serie <- serie |> filter(!is.na(precio)) |> group_by(panel, lado) |>
  slice_max(año_fiscal, n = 1)
# Lines break at years without data (NA kept), so a gap is not drawn as a
# trend; points mark the years with a price.
f4 <- ggplot(serie, aes(año_fiscal, precio, colour = lado)) +
  geom_line(linewidth = 0.7, na.rm = TRUE) +
  geom_point(size = 1.6, na.rm = TRUE) +
  geom_text(data = fin_serie, aes(label = lado), hjust = -0.2,
            family = fuente, size = 2.8, fontface = "bold") +
  facet_wrap(~panel, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = colores_lado, guide = "none") +
  scale_x_continuous(breaks = 2019:2026,
                     expand = expansion(add = c(0.3, 1.1))) +
  scale_y_continuous(labels = function(x) paste0("$", num(x, 1)),
                     limits = c(0, NA),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(x = NULL, y = "Pesos de 2025 por caja") +
  titulos(4) +
  tema_tmx() +
  theme(panel.spacing.y = unit(10, "pt"))
guardar(f4, 4, 6.2)

# ---- Figure 5: ISSSTE purchase vs prescription, same year (2023), by key ---

c5 <- leer("compra_vs_prescripcion_clave") |>
  filter(institucion == "ISSSTE", año == 2023)
ambas5 <- filter(c5, ambas)
r5 <- function(cl) round(ambas5$razon_compra_prescripcion_minimo[
  ambas5$clave_cnis == cl], 2)
verificar("F5 ISSSTE 2023 claves con ambas", nrow(ambas5), 21, 0)
verificar("F5 ISSSTE 2023 razón mediana",
          round(median(ambas5$razon_compra_prescripcion_minimo), 2), 0.99)
verificar("F5 glibenclamida, metformina, glargina",
          c(r5("010.000.1042.00"), r5("010.000.5165.00"),
            r5("010.000.4158.00")), c(0.99, 0.98, 0.97))
verificar("F5 pioglitazona, linagliptina, clonazepam 2613, litio",
          c(r5("010.000.4149.00"), r5("010.000.5621.00"),
            r5("040.000.2613.00"), r5("040.000.3255.00")),
          c(0.79, 0.59, 3.04, 3.80))
p5 <- function(cl) c5$cajas_prescritas[c5$clave_cnis == cl &
                                         c5$cajas_compradas_minimo == 0]
verificar("F5 prescritas sin compra: fluoxetina 4483.00, olanzapina 5486.00",
          c(p5("010.000.4483.00"), p5("010.000.5486.00")),
          c(589524, 193062), 0)

piso <- 1 # zeros are drawn on this floor line of the log axes
f5_datos <- c5 |>
  left_join(cobertura |> distinct(clave_cnis, area), by = "clave_cnis") |>
  mutate(x = pmax(cajas_prescritas, piso), y = pmax(cajas_compradas_minimo, piso),
         razon = if_else(cajas_prescritas > 0,
                         cajas_compradas_minimo / cajas_prescritas, Inf),
         # Far from the diagonal: ratio above 2 or below 0.5, zeros included.
         lejos = razon > 2 | razon < 0.5,
         etiqueta = if_else(lejos,
                            paste0(etiqueta_componente(componente), " ",
                                   str_sub(clave_cnis, 9)), NA_character_),
         # Labels of keys above the diagonal go up-left, away from the
         # cluster along it (log10 units); the floor labels stay free.
         nx = if_else(is.finite(razon) & razon > 1, -0.7, 0),
         ny = if_else(is.finite(razon) & razon > 1, 0.25, 0))
cortes5 <- 10^(0:7)
lab5 <- function(x) ifelse(x <= piso, "0",
                           ifelse(x >= 1e6, paste0(num(x / 1e6, 1), " M"),
                                  num(x, 1)))
f5 <- ggplot(f5_datos, aes(x, y, colour = area)) +
  geom_abline(slope = 1, intercept = 0, colour = tmx$gris, linewidth = 0.5) +
  geom_hline(yintercept = piso, colour = tmx$gris, linetype = "dotted") +
  geom_vline(xintercept = piso, colour = tmx$gris, linetype = "dotted") +
  geom_point(size = 2, alpha = 0.9) +
  geom_text_repel(aes(label = etiqueta), family = fuente, size = 2.5,
                  min.segment.length = 0, box.padding = 0.5,
                  point.padding = 0.3, max.overlaps = Inf, seed = 17,
                  nudge_x = f5_datos$nx, nudge_y = f5_datos$ny,
                  show.legend = FALSE,
                  segment.size = 0.25, na.rm = TRUE) +
  annotate("text", x = 5e6, y = 1.2e7, label = "Compra = prescripción",
           hjust = 1, vjust = 0, family = fuente, size = 2.6,
           colour = tmx$gris) +
  scale_colour_manual(values = c("Salud mental" = tmx$azul,
                                 "Diabetes" = tmx$verde), name = NULL) +
  scale_x_log10(breaks = cortes5, labels = lab5) +
  scale_y_log10(breaks = cortes5, labels = lab5) +
  coord_cartesian(xlim = c(0.7, 2e7), ylim = c(0.7, 2e7)) +
  labs(x = "Cajas prescritas en 2023 (OCAMIS)",
       y = "Cajas compradas en 2023 (cantidad mínima)") +
  titulos(5) +
  tema_tmx()
guardar(f5, 5, 5.4)

# ---- Figure 6: coverage x marginalisation, 32 states ----------------------

niveles_cob <- c("Con pares", "Con filas comparables, sin par",
                 "Con filas, ninguna comparable", "Sin filas")
cob6 <- read_csv(file.path(dir_salidas, "cobertura_marginacion_entidad.csv"),
                 show_col_types = FALSE, col_types = cols(cve_ent = "c")) |>
  mutate(grado = factor(grado_marginacion_2020,
                        levels = c("Muy bajo", "Bajo", "Medio", "Alto",
                                   "Muy alto")),
         cobertura = factor(cobertura, levels = niveles_cob))
stopifnot(nrow(cob6) == 32, !anyNA(cob6$grado), !anyNA(cob6$cobertura))
for (nv in niveles_cob) {
  ents <- cob6$entidad[cob6$cobertura == nv]
  message(sprintf("F6 %s (%d): %s", nv, length(ents),
                  paste(sort(ents), collapse = "; ")))
}
verificar("F6 conteo por categoría", as.integer(table(cob6$cobertura)),
          c(10, 1, 3, 18), 0)
verificar("F6 muy alto sin datos comparables (Chiapas, Guerrero, Oaxaca)",
          sum(cob6$grado == "Muy alto" & cob6$cobertura != "Con pares"), 3, 0)

geo <- st_read(ruta_geometria, quiet = TRUE) |>
  st_simplify(dTolerance = 2500, preserveTopology = TRUE) |>
  left_join(cob6, by = c("CVE_ENT" = "cve_ent"))
stopifnot(nrow(geo) == 32, !anyNA(geo$cobertura))
puntos <- st_point_on_surface(geo)

colores_cob <- setNames(c(tmx$azul, tmx$verde, tmx$gris, tmx$claro),
                        niveles_cob)
f6 <- ggplot() +
  geom_sf(data = geo, aes(fill = cobertura), colour = "white",
          linewidth = 0.25) +
  geom_sf(data = geo |> filter(cobertura == "Sin filas"), fill = NA,
          colour = "#BFBFBF", linewidth = 0.25) +
  geom_sf(data = puntos, aes(size = grado), shape = 21, fill = "white",
          colour = tmx$texto, stroke = 0.45) +
  scale_fill_manual(values = colores_cob, name = "Cobertura de precios",
                    drop = FALSE) +
  scale_size_manual(values = c(0.6, 1.2, 1.9, 2.7, 3.6),
                    name = "Grado de marginación 2020", drop = FALSE) +
  guides(fill = guide_legend(order = 1, ncol = 1,
                             override.aes = list(colour = "#BFBFBF")),
         size = guide_legend(order = 2, ncol = 1)) +
  coord_sf(datum = NA) +
  titulos(6) +
  tema_tmx() +
  theme(legend.position = "right", legend.justification = "top",
        legend.key.size = unit(10, "pt"),
        legend.text = element_text(size = 7.5),
        legend.title = element_text(size = 8, face = "bold"),
        panel.grid.major = element_blank())
guardar(f6, 6, 3.5)

write_csv(meta, file.path(dir_figuras, "figuras_meta.csv"))
message("Fuente tipográfica usada: ", fuente)
