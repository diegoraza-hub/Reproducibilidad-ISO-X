# Reproducibilidad ISO y exportaciones (WBES)

Este repositorio contiene el código y los outputs necesarios para reproducir los resultados reportados en el manuscrito “ISO y exportaciones” (margen extensivo e intensivo) utilizando datos de la World Bank Enterprise Surveys (WBES). Por restricciones de redistribución, los microdatos originales no se incluyen en este repositorio.

## Contenido del repositorio

Estructura de carpetas:

- `env/`: especificación del entorno reproducible
- `scripts/`: script principal de reproducción
- `outputs/`: outputs reproducibles (modelos y diagnósticos)
- `tables/`: tablas en formato CSV para el manuscrito y apéndices
- `data_processed/`: datos procesados derivados (opcional, sin microdatos WBES)

## Requisitos

- R (recomendado: versión 4.2 o superior)
- Paquetes de R indicados en `env/repro-r.yml`

## Datos

Los microdatos WBES están sujetos a términos de uso y no se redistribuyen aquí. Para reproducir completamente desde cero, el usuario debe obtener las rondas y países usados en el estudio desde WBES y colocarlos localmente según las rutas indicadas en el script.

Si no se cuenta con los microdatos, este repositorio permite:
- verificar consistencia de cifras del manuscrito con los outputs incluidos en `outputs/` y `tables/`
- reproducir tablas y reportes a partir de los archivos ya procesados que se incluyen (cuando aplique)

## Cómo reproducir

1. Configure el entorno usando `env/repro-r.yml` (o instale manualmente los paquetes equivalentes en R).
2. Ejecute el script principal:

   - `scripts/reproduce_iso_export.R`

3. El script produce y/o actualiza:
   - outputs en `outputs/`
   - tablas en `tables/`

Nota: si las rutas a los microdatos WBES no están disponibles en su equipo, el script puede requerir ajustes mínimos de ruta o ejecutarse en el modo que reconstruye tablas a partir de outputs ya incluidos.

## Definición y construcción de variables clave (WBES)

- Certificación ISO: `b8` (recodificación: 1 = sí, 2 = no)
- Ventas anuales: `d2`
- Empleo permanente: `l1`
- Exportaciones directas: `d3b`
- Exportaciones indirectas: `d3c`
- Obstáculo de acceso a financiamiento: `k30`
- Sector (sector de muestreo WBES): `a4a`

Construcciones usadas en el manuscrito:
- Exportadora (margen extensivo): indicador que toma 1 si `d3b + d3c > 0`, y 0 si `d3b + d3c = 0`.
- Cuota exportadora (margen intensivo): `d3b + d3c` (0 a 100), analizada condicionalmente entre exportadoras.

## Outputs y trazabilidad (manuscrito ↔ archivos)

La siguiente tabla indica dónde se encuentra cada cifra clave reportada en el manuscrito.

| Elemento del manuscrito | Archivo fuente |
|---|---|
| Descriptivos pre matching (N, tasas de exportación, medianas de ventas y empleo) | `tables/Table_A1_descriptivos_pre_matching.csv` |
| Diagnósticos de balance pre y post matching (SMD) y composición sectorial | `tables/Table_A2_balance_pre_post.csv` |
| Resultados principales (OR y AME del modelo base) | `outputs/outputs_repro_v3.csv` y `outputs/outputs_repro_v3.json` |
| Balance SMD pre y post (covariables continuas) | `outputs/balance_smd_pre_post.csv` |
| Balance por sector (a4a, SMD post) | `outputs/sector_smd_post.csv` |
| Muestra emparejada (si se incluye) | `data_processed/matched_sample_nn_caliper005_exact_ctryyear.csv` |

Convención de reporte:
- OR: razón de momios (odds ratio) del modelo logit en la muestra emparejada
- AME: efecto marginal promedio sobre la probabilidad de exportar

## Notas metodológicas

- El balance se evalúa con diferencias estandarizadas de medias (SMD). En el manuscrito se usa un umbral de referencia de 10% (0,1) como criterio práctico.
- La robustez incluye variaciones razonables del emparejamiento y especificaciones alternativas. Cuando se utiliza probit, el efecto se compara mediante AME (no mediante OR).

## Citación del repositorio

Si desea citar este repositorio en el manuscrito o en materiales suplementarios, utilice el enlace del repositorio en GitHub y la fecha de consulta. Para preservación y citación formal con DOI, se recomienda archivar una versión del repositorio en un servicio que emita DOI (por ejemplo, Zenodo), si los términos de uso lo permiten.

## Licencia

Ver `LICENSE`.

