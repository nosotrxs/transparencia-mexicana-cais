# transparencia-mexicana-cais

Base de datos de precios de medicamentos contratados por el sector público de salud en México, con su diccionario, la capa de análisis y el código que la produce. Proyecto CAIS-T2-C1 (Fondo AC4ALL, Transparencia Mexicana).

## Contenido

| Ruta | Qué es |
|---|---|
| `data/base_precios.csv`, `data/base_precios.xlsx` | Base de precios |
| `data/Base--precios-Diccionario-de-datos.md` | Diccionario de datos de la base |
| `data/claves_eje_salud_mental_diabetes_40.csv` | Claves del eje de salud mental y diabetes (43 filas; conserva el nombre de 40) |
| `data/base_solicitudes.csv` | Registro de las solicitudes de acceso a la información |
| `data/cero_desabasto_reportes_claves.csv` | Reportes de Cero Desabasto para las claves del eje |
| `salidas/` | Capa de análisis: `analisis_precios.xlsx`, sus tablas en CSV y las figuras |
| `datos/` | Insumos externos: INPC, índice de marginación de CONAPO y Censo 2020 de INEGI |
| `R/`, `tests/` | Código del análisis y sus pruebas |
| `README_analisis.md` | Documentación del análisis |
