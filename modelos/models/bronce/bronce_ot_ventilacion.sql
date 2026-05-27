{#-
    bronce_ot_ventilacion — Une las 4 hojas del Programa Semana 21 2026 en una sola vista.

    Fuente: 4 snapshots (programa_general, programa_chancado_fino, programa_molienda,
    programa_chancado_primario).
    Macro: normaliza_ot_planta (maneja la normalización de columnas + metadata + planta_canon).

    Una fila por orden de trabajo. Cada hoja se etiqueta con el conjunto de plantas canónicas
    que cubre, según el mapeo de hoja → planta_canon.

    Columnas de salida:
      planta_canon, orden_nro, ot_texto_breve, equipo_denom, ubicacion_tecnica,
      pto_trabajo_ejecutor, responsable, inicio_programado, fecha_liberacion,
      fecha_inicio_extrema, status_sistema, hh_planificadas, duracion_planificada,
      personal_prog, hh_reales, duracion_real, semana_nro, anio,
      _bronce_fuente, _bronce_loaded_at
-#}
{{
    config(
        materialized='view',
        tags=['capa:bronce', 'dominio:codelco_andina']
    )
}}

{{ normaliza_ot_planta(ref('snap_programa_chancado_fino'),     'Chancado Fino',     'Chancado Sec/Terc + Chancado Terc/Cuat') }}
UNION ALL
{{ normaliza_ot_planta(ref('snap_programa_molienda'),          'Molienda',          'Molienda SAG')                            }}
UNION ALL
{{ normaliza_ot_planta(ref('snap_programa_chancado_primario'), 'Chancado Primario', 'Prechancado + Nodo 3500')                 }}
UNION ALL
{{ normaliza_ot_planta(ref('snap_programa_general'),           'Programa',          'CDM Linea 1 + CDM Linea 2')               }}
