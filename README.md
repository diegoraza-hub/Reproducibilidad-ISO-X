# Reproducibilidad-ISO-X

Paquete de reproducibilidad: Certificación ISO y desempeño exportador
Fecha: 2026-02-01

Repositorio:
- Código y materiales complementarios para reproducir el procesamiento y los resultados del estudio.

Contenido del repositorio:
- iso_wbes_analysis.py          : Script principal (limpieza, construcción de variables y estimación)
- replicate_notebook.ipynb      : Notebook con la reproducción paso a paso de tablas y figuras
- README.txt / README.md        : Instrucciones

Nota sobre datos:
- Los microdatos de WBES (World Bank Enterprise Surveys) NO se redistribuyen en este repositorio.
  Para reproducir el estudio, descargue los archivos originales desde WBES y colóquelos localmente.

Requisitos sugeridos:
- Python 3.10+ (o entorno equivalente)
- Paquetes (referenciales): pandas, numpy, statsmodels, scikit-learn, linearmodels (si aplica)

Ejecución (esquema):
1) Ajuste rutas de entrada en iso_wbes_analysis.py (por ejemplo, carpeta ./data/raw/).
2) Ejecute:
   python iso_wbes_analysis.py
3) Abra replicate_notebook.ipynb para replicar tablas y figuras y validar resultados.

Salidas esperadas (ejemplos, si el script las genera):
- outputs/clean_data.csv (o .parquet)
- outputs/tables/*.csv
- outputs/figures/*.png

Licencias:
- Código: MIT (ver LICENSE).
- Datos WBES: sujetos a los términos del Banco Mundial (no se incluyen aquí).

Cita sugerida del repositorio (sin DOI):
- Raza, Diego. 2026. “Reproducibilidad-ISO-X: Paquete de reproducibilidad ISO y capacidad exportadora”. GitHub.
  URL: https://github.com/diegoraza-hub/Reproducibilidad-ISO-X (consultado el 2026-02-01).
