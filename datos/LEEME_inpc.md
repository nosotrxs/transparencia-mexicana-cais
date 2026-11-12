# INPC general mensual

Insumo para deflactar precios a pesos de 2025 en el análisis de precios. Lo genera `R/01_preparar_inpc.R`; el análisis solo lee el CSV.

## Archivo fuente

- Ruta: `/home/castanedaprado/OneDrive/Documentos/Trabajo/evolucion-sistema-salud/fuentes/descargas-2026-10-05-imss/banxico-sie-sp1-inpc-mensual-1969-2026.xlsx`
- sha256: `e75459873d3d190df75fe2422909430b54220ef0796a8f0ed16b9f8a7732f708`
- Institución (encabezado): Banco de México
- Fecha de consulta (encabezado): 05/10/2026 07:10:52; la carpeta de descarga es del 2026-10-05
- El archivo pertenece al proyecto `evolucion-sistema-salud`; no se modifica.

## Serie

- Identificador: SP1
- Título: IPC Por objeto del gasto Nacional, I n d i c e G e n e r a l
- Periodo disponible: Ene 1969 - Ago 2026
- Periodicidad: Mensual
- Cifra: Indices; unidad: Sin Unidad
- Periodo base: 2Q Jul 2018 (segunda quincena de julio de 2018 = 100)

## CSV

- Archivo: `datos/inpc_general_mensual.csv`; sha256: `e60a1c59c4bb5fe52e3fc0f73fe8b8b1756a80b00c045f7dc5c3c49059d2045f`
- Columnas: `fecha` (primer día del mes), `año`, `mes`, `inpc`.
- Rango: 1969-01-01 a 2026-08-01, 692 meses consecutivos, sin faltantes.
- Comprobación: julio de 2018 vale 99.909099104514, justo debajo de 100, como corresponde a una base en la segunda quincena de ese mes.
- 2026 solo tiene enero a agosto. El análisis usa el promedio de los meses disponibles y lo marca con `inpc_meses`.
