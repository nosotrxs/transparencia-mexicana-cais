# Respuestas a las solicitudes de acceso a la información

Documentos que entregaron los sujetos obligados a las solicitudes del proyecto, con corte al 12 de noviembre de 2026. Son 79 solicitudes (50 estatales y 29 federales) de las 82 registradas en `data/base_solicitudes.csv`. Las tres restantes no tienen respuesta ni recurso.

Los archivos pesan cerca de 1 GB y algunos superan el límite de 100 MB por archivo de GitHub, así que no van dentro del repositorio. Se publican como un zip por solicitud en el release [`respuestas-2026-11-12`](https://github.com/nosotrxs/transparencia-mexicana-cais/releases/tag/respuestas-2026-11-12).

## Índice

`indice.csv` tiene una fila por solicitud:

| Columna | Qué es |
|---|---|
| `id` | Identificador de la solicitud, igual que en `data/base_solicitudes.csv` |
| `folio` | Folio de la Plataforma Nacional de Transparencia o del sistema estatal |
| `ambito`, `entidad_federativa`, `institucion` | Sujeto obligado |
| `estatus`, `fecha_respuesta`, `tipo_respuesta`, `entrega_precio` | Estado de la solicitud al corte, tomado de la base de solicitudes |
| `n_archivos`, `tamano_mb` | Número de archivos y peso del zip |
| `archivos` | Lista de archivos dentro del zip, separados por ` \| ` |
| `descarga` | Liga directa al zip |

## Qué trae cada zip

- Los documentos de respuesta tal como los entregó el sujeto obligado (oficios, acuerdos, anexos en Excel, contratos, zips originales) y los que se bajaron de las ligas que puso en su respuesta (Drive, SharePoint, SIPOT).
- `acuse_solicitud/`: acuse de presentación de la solicitud, cuando se conserva.
- `acuse_queja_*.pdf` y carpetas `envio_*`: quejas (recursos de revisión) presentadas y su texto, y documentos del órgano garante cuando los hay.

No incluyen las notas de trabajo, el texto extraído por OCR ni las capturas de pantalla del proceso. Los documentos se publican sin modificar. Los escaneados no tienen capa de texto.
