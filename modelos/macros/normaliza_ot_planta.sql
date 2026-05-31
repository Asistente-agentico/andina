{#-
    normaliza_ot_planta — Normaliza una hoja del Programa de Ventilación (semana 21 2026)
    al formato común del bronce de OT.

    Estructura REAL de entrada (CSV de landing programa_*):
      Denominación, Orden, Operación, Orden+Op, Txt.brv., Pto.Trab.Ejecutor, Responsable,
      FechaInicMásTmp, HorasHombreProg., DuraciónProg., PersonalProg, HorasHombreReal,
      DuraciónReal, PersonalReal, CumplProg, AdherenciaProg,
      + 7 columnas-día (fechas de la semana 21: 2026-05-18 .. 2026-05-24) con las HH
        planificadas el día agendado.

    Reglas aplicadas:
      - BK orden_nro: cast TEXT + trim + UPPER + zero-key (-1).
      - ubicacion_tecnica NO viene en el Programa: se resuelve en bronce_ot_ventilacion
        vía join contra equipos_ventilacion_catalogo por equipo_denom.
      - Re-etiquetado temporal (decisión B): la semana 21 se re-etiqueta a la semana 19
        (anio=2026, semana_nro=19) y las fechas descriptivas se desplazan -14 días para
        quedar internamente consistentes con el rango del demo (semanas 1-19).
      - Campos de no-ejecución (motivo/peso/fecha_reprog) NO vienen: se sintetizan de forma
        determinista cuando cumpl_prog = 0 (lista controlada).

    Parámetro:
      snapshot_ref — ref() al snapshot de la hoja del Programa.
-#}
{% macro normaliza_ot_planta(snapshot_ref) %}
WITH base AS (
    SELECT
        COALESCE(NULLIF(UPPER(TRIM(CAST("Orden" AS VARCHAR))), ''), '-1')   AS orden_nro,
        NULLIF(TRIM(CAST("Denominación" AS VARCHAR)), '')                   AS equipo_denom,
        NULLIF(TRIM(CAST("Txt.brv." AS VARCHAR)), '')                       AS ot_texto_breve,
        NULLIF(TRIM(CAST("Responsable" AS VARCHAR)), '')                    AS responsable,
        NULLIF(TRIM(CAST("Pto.Trab.Ejecutor" AS VARCHAR)), '')              AS pto_trabajo_ejecutor,
        TRY_CAST("HorasHombreProg." AS DOUBLE)                              AS hh_planificadas,
        TRY_CAST("DuraciónProg."   AS DOUBLE)                               AS duracion_planificada,
        TRY_CAST(" PersonalProg"   AS INTEGER)                              AS personal_prog,
        TRY_CAST("HorasHombreReal" AS DOUBLE)                              AS hh_reales,
        TRY_CAST("DuraciónReal"    AS DOUBLE)                               AS duracion_real,
        TRY_CAST("PersonalReal"    AS INTEGER)                              AS personal_real,
        TRY_CAST("CumplProg"       AS INTEGER)                              AS cumpl_prog,
        TRY_CAST("AdherenciaProg"  AS DOUBLE)                               AS adherencia_prog,
        NULLIF(TRIM(CAST("FechaInicMásTmp" AS VARCHAR)), '')                AS fecha_inicio_extrema,
        -- Día agendado: primera de las 7 columnas-día con valor no nulo (HH de ese día).
        -- Se desplaza -14 días (semana 21 -> semana 19).
        COALESCE(
            CASE WHEN "2026-05-18 00:00:00" IS NOT NULL THEN DATE '2026-05-18' END,
            CASE WHEN "2026-05-19 00:00:00" IS NOT NULL THEN DATE '2026-05-19' END,
            CASE WHEN "2026-05-20 00:00:00" IS NOT NULL THEN DATE '2026-05-20' END,
            CASE WHEN "2026-05-21 00:00:00" IS NOT NULL THEN DATE '2026-05-21' END,
            CASE WHEN "2026-05-22 00:00:00" IS NOT NULL THEN DATE '2026-05-22' END,
            CASE WHEN "2026-05-23 00:00:00" IS NOT NULL THEN DATE '2026-05-23' END,
            CASE WHEN "2026-05-24 00:00:00" IS NOT NULL THEN DATE '2026-05-24' END,
            DATE '2026-05-18'
        ) - INTERVAL '14 days'                                              AS dia_programado
    FROM {{ snapshot_ref }}
    WHERE dbt_valid_to IS NULL
      AND "Orden" IS NOT NULL
      AND TRIM(CAST("Orden" AS VARCHAR)) != ''
)
SELECT
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    responsable,
    pto_trabajo_ejecutor,
    hh_planificadas,
    duracion_planificada,
    personal_prog,
    hh_reales,
    duracion_real,
    personal_real,
    cumpl_prog,
    adherencia_prog,

    -- Re-etiquetado temporal a semana 19 / 2026 (decisión B)
    2026                                                AS anio,
    19                                                  AS semana_nro,
    strftime(dia_programado, '%Y-%m-%dT%H:%M:%SZ')      AS inicio_programado,
    strftime(dia_programado, '%Y-%m-%d')                AS dia_ejecutado,

    -- Campos de no-ejecución sintéticos (deterministas) cuando cumpl_prog = 0
    CASE WHEN cumpl_prog = 0 THEN
        (ARRAY['Falta de repuestos','Falta de personal','Reprogramado por operaciones','Equipo en uso productivo'])
        [ (abs(hash(orden_nro)) % 4) + 1 ]
    END                                                 AS motivo_no_ejecucion,
    CASE WHEN cumpl_prog = 0 THEN
        (ARRAY[0.9, 0.7, 0.5, 0.6])[ (abs(hash(orden_nro)) % 4) + 1 ]
    END                                                 AS peso_motivo,
    CASE WHEN cumpl_prog = 0 THEN
        strftime(dia_programado + INTERVAL '7 days', '%Y-%m-%dT%H:%M:%SZ')
    END                                                 AS fecha_reprogramacion,

    -- Atributos descriptivos para silver_detalle_ot_descr / ot_programacion
    equipo_denom                                        AS denom_ubic_tecnica,
    fecha_inicio_extrema,
    NULL::VARCHAR                                       AS fecha_liberacion,
    NULL::VARCHAR                                       AS clase_orden,
    NULL::VARCHAR                                       AS clase_actividad_pm,
    NULL::VARCHAR                                       AS status_sistema,

    '{{ snapshot_ref }}'                                AS _bronce_fuente,
    {{ utc_ahora() }}                                   AS _bronce_loaded_at
FROM base
{% endmacro %}
