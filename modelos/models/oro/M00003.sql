{#-
    P00003 — Condiciones completas de la medición con mayor concentración histórica por área.
    Incluye: fecha, operador, técnico, horario, punto de medición exacto.
    Chunk: uno por planta con el detalle completo de su peak histórico.
    Temporal policy: vigente (siempre el peak más alto conocido).
-#}
{{
    config(
        tags=['capa:oro', 'dominio:minera_prueba', 'regla:P00003']
    )
}}

WITH limite_interno AS (
    SELECT MIN(concentracion_min_mg_m3) AS mg_m3
    FROM {{ ref('semaforo_polvo_respirable') }}
    WHERE es_sobre_limite_interno = true
),

ranked AS (
    SELECT
        planta,
        punto_evaluacion,
        anio,
        semana,
        concentracion_mg_m3,
        fecha,
        hora_inicio,
        hora_termino,
        operador_alias,
        tecnico_alias,
        ROW_NUMBER() OVER (
            PARTITION BY planta
            ORDER BY concentracion_mg_m3 DESC
        ) AS rn
    FROM {{ ref('bronce_mediciones') }}
    WHERE concentracion_mg_m3 IS NOT NULL
),

peak AS (
    SELECT * FROM ranked WHERE rn = 1
),

con_personas AS (
    SELECT
        p.planta,
        p.punto_evaluacion,
        p.anio,
        p.semana,
        p.concentracion_mg_m3,
        p.fecha,
        p.hora_inicio,
        p.hora_termino,
        MAX(CASE WHEN ep_op.tipo_persona = 'operador' THEN ep_op.nombre_completo END) AS operador,
        MAX(CASE WHEN ep_tc.tipo_persona = 'tecnico'  THEN ep_tc.nombre_completo END) AS tecnico,
        MAX(CASE WHEN ep_op.tipo_persona = 'operador' THEN ep_op.dni END)             AS operador_dni,
        MAX(CASE WHEN ep_tc.tipo_persona = 'tecnico'  THEN ep_tc.dni END)             AS tecnico_dni
    FROM peak p
    LEFT JOIN {{ ref('personas_alias') }} op_a
        ON trim(p.operador_alias) = op_a.alias_fuente
    LEFT JOIN {{ ref('silver_entidad_persona') }} ep_op
        ON {{ huella_registro(['op_a.dni', 'op_a.tipo_dni', 'op_a.dni_pais_emisor']) }} = ep_op.huella_registro
    LEFT JOIN {{ ref('personas_alias') }} tc_a
        ON trim(p.tecnico_alias) = tc_a.alias_fuente
    LEFT JOIN {{ ref('silver_entidad_persona') }} ep_tc
        ON {{ huella_registro(['tc_a.dni', 'tc_a.tipo_dni', 'tc_a.dni_pais_emisor']) }} = ep_tc.huella_registro
    GROUP BY
        p.planta, p.punto_evaluacion, p.anio, p.semana,
        p.concentracion_mg_m3, p.fecha, p.hora_inicio, p.hora_termino
)

SELECT
    cp.planta,
    cp.punto_evaluacion,
    cp.anio,
    cp.semana,
    cp.concentracion_mg_m3,
    ROUND(cp.concentracion_mg_m3 / li.mg_m3, 2)    AS veces_sobre_limite,
    cp.fecha,
    cp.hora_inicio,
    cp.hora_termino,
    cp.operador,
    cp.operador_dni,
    cp.tecnico,
    cp.tecnico_dni,
    li.mg_m3                                        AS limite_interno_mg_m3,
    s.nivel                                         AS nivel_semaforo,
    s.color                                         AS color_semaforo,
    s.etiqueta                                      AS etiqueta_semaforo
FROM con_personas cp
CROSS JOIN limite_interno li
LEFT JOIN {{ ref('semaforo_polvo_respirable') }} s
    ON cp.concentracion_mg_m3 >= s.concentracion_min_mg_m3
    AND (cp.concentracion_mg_m3 < s.concentracion_max_mg_m3
         OR s.concentracion_max_mg_m3 IS NULL)
ORDER BY cp.planta
