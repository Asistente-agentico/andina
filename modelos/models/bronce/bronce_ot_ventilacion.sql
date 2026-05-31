{#-
    bronce_ot_ventilacion — Une las 4 hojas del Programa Semana 21 2026 en una sola vista
    de órdenes de trabajo, y resuelve la máquina de control (ubicacion_tecnica) + planta_canon
    vía join contra el catálogo de equipos.

    Cadena:
      snap_programa_*  ->  normaliza_ot_planta (macro, nombres reales + re-etiquetado sem 19)
                       ->  union 4 hojas
                       ->  JOIN normalizado contra equipos_ventilacion_catalogo por equipo_denom
                       ->  emite ubicacion_tecnica + planta_canon (única fuente de verdad).

    Las OT cuyo equipo_denom no está en el catálogo (ej. "Sistema Captación...", excluidos
    por ser agregaciones) quedan con ubicacion_tecnica NULL y se filtran aguas abajo en
    silver_relacion_ot_maqctrl (WHERE ubicacion_tecnica IS NOT NULL).

    Columnas de salida (consumidas por los silver de OT):
      orden_nro, ubicacion_tecnica, equipo_denom, planta_canon, ot_texto_breve, responsable,
      pto_trabajo_ejecutor, hh_planificadas, duracion_planificada, personal_prog, hh_reales,
      duracion_real, personal_real, cumpl_prog, adherencia_prog, anio, semana_nro,
      inicio_programado, dia_ejecutado, motivo_no_ejecucion, peso_motivo, fecha_reprogramacion,
      _bronce_fuente, _bronce_loaded_at
-#}
{{
    config(
        materialized='view',
        tags=['capa:bronce', 'dominio:codelco_andina']
    )
}}

WITH ot_todas AS (
    {{ normaliza_ot_planta(ref('snap_programa_chancado_fino')) }}
    UNION ALL
    {{ normaliza_ot_planta(ref('snap_programa_molienda')) }}
    UNION ALL
    {{ normaliza_ot_planta(ref('snap_programa_chancado_primario')) }}
    UNION ALL
    {{ normaliza_ot_planta(ref('snap_programa_general')) }}
),

ot_norm AS (
    SELECT
        *,
        lower(trim(regexp_replace(equipo_denom, '\s+', ' ', 'g'))) AS _denom_norm
    FROM ot_todas
),

-- Catálogo: resuelve ubicacion_tecnica + planta_canon desde el equipo_denom
catalogo AS (
    SELECT
        ubicacion_tecnica,
        planta_canon,
        lower(trim(regexp_replace(equipo_denom, '\s+', ' ', 'g'))) AS _denom_norm
    FROM {{ ref('equipos_ventilacion_catalogo') }}
)

SELECT
    o.orden_nro,
    c.ubicacion_tecnica,
    o.equipo_denom,
    c.planta_canon,
    o.ot_texto_breve,
    o.responsable,
    o.pto_trabajo_ejecutor,
    o.hh_planificadas,
    o.duracion_planificada,
    o.personal_prog,
    o.hh_reales,
    o.duracion_real,
    o.personal_real,
    o.cumpl_prog,
    o.adherencia_prog,
    o.anio,
    o.semana_nro,
    o.inicio_programado,
    o.dia_ejecutado,
    o.motivo_no_ejecucion,
    o.peso_motivo,
    o.fecha_reprogramacion,
    o.denom_ubic_tecnica,
    o.fecha_inicio_extrema,
    o.fecha_liberacion,
    o.clase_orden,
    o.clase_actividad_pm,
    o.status_sistema,
    o._bronce_fuente,
    o._bronce_loaded_at

FROM ot_norm o
LEFT JOIN catalogo c
    ON o._denom_norm = c._denom_norm
