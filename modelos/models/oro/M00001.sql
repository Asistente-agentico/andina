{#-
    P00001 — Puntos que superaron el límite interno en la semana más reciente.
    Limite interno leído desde semaforo_polvo_respirable (es_sobre_limite_interno = true).
    Chunk: uno por punto que supera el límite interno.
    Temporal policy: vigente (semana en curso = max(anio, semana) con datos).
-#}
{{
    config(
        tags=['capa:oro', 'dominio:minera_prueba', 'regla:P00001']
    )
}}

WITH limite_interno AS (
    SELECT MIN(concentracion_min_mg_m3) AS mg_m3
    FROM {{ ref('semaforo_polvo_respirable') }}
    WHERE es_sobre_limite_interno = true
),

ultima_sesion AS (
    SELECT planta, MAX(anio * 100 + semana) AS sesion_max
    FROM {{ ref('silver_entidad_sesion_medicion') }}
    GROUP BY planta
),

mediciones_vigentes AS (
    SELECT
        b.planta,
        b.punto_evaluacion,
        b.anio,
        b.semana,
        b.concentracion_mg_m3,
        b.fecha,
        b.hora_inicio,
        b.hora_termino,
        b.operador_alias,
        b.tecnico_alias
    FROM {{ ref('bronce_mediciones') }} b
    JOIN ultima_sesion u
        ON b.planta = u.planta
       AND (b.anio * 100 + b.semana) = u.sesion_max
    WHERE b.concentracion_mg_m3 > (SELECT mg_m3 FROM limite_interno)
),

con_personas AS (
    SELECT
        m.planta,
        m.punto_evaluacion,
        m.anio,
        m.semana,
        m.concentracion_mg_m3,
        m.fecha,
        m.hora_inicio,
        m.hora_termino,
        MAX(CASE WHEN p_op.tipo_persona = 'operador' THEN p_op.nombre_completo END) AS operador,
        MAX(CASE WHEN p_tc.tipo_persona = 'tecnico'  THEN p_tc.nombre_completo END) AS tecnico
    FROM mediciones_vigentes m
    LEFT JOIN {{ ref('personas_alias') }} op_a
        ON trim(m.operador_alias) = op_a.alias_fuente
    LEFT JOIN {{ ref('silver_entidad_persona') }} p_op
        ON {{ huella_registro(['op_a.dni', 'op_a.tipo_dni', 'op_a.dni_pais_emisor']) }} = p_op.huella_registro
    LEFT JOIN {{ ref('personas_alias') }} tc_a
        ON trim(m.tecnico_alias) = tc_a.alias_fuente
    LEFT JOIN {{ ref('silver_entidad_persona') }} p_tc
        ON {{ huella_registro(['tc_a.dni', 'tc_a.tipo_dni', 'tc_a.dni_pais_emisor']) }} = p_tc.huella_registro
    GROUP BY
        m.planta, m.punto_evaluacion, m.anio, m.semana,
        m.concentracion_mg_m3, m.fecha, m.hora_inicio, m.hora_termino
)

SELECT
    cp.planta,
    cp.punto_evaluacion,
    cp.anio,
    cp.semana,
    cp.concentracion_mg_m3,
    ROUND(cp.concentracion_mg_m3 / li.mg_m3, 2)                        AS veces_sobre_limite,
    cp.fecha,
    cp.hora_inicio,
    cp.hora_termino,
    cp.operador,
    cp.tecnico,
    li.mg_m3                                                            AS limite_interno_mg_m3,
    s.nivel                                                             AS nivel_semaforo,
    s.color                                                             AS color_semaforo,
    s.etiqueta                                                          AS etiqueta_semaforo
FROM con_personas cp
CROSS JOIN limite_interno li
LEFT JOIN {{ ref('semaforo_polvo_respirable') }} s
    ON cp.concentracion_mg_m3 >= s.concentracion_min_mg_m3
    AND (cp.concentracion_mg_m3 < s.concentracion_max_mg_m3
         OR s.concentracion_max_mg_m3 IS NULL)
ORDER BY cp.concentracion_mg_m3 DESC
