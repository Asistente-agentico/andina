{#-
    M00003 — M_DETALLE_MEDICION
    Datamart oro: detalle completo de cada medición (fecha, hora, responsables, motivo si no se midió).
    Sirve a las preguntas:
      P00009 — fecha y horario de la medición en el punto X de la planta Y
      P00010 — quién fue el responsable de la medición
      P00011 — por qué no se tomó la medición en la fecha X
    Ámbito: fiscalizacion (denormalizado como literal).

    Construcción desde silver:
      L_MEDICION + S_MEDICION_VALOR        (fecha, hora, estado, motivo)
      L_PUNTO_PLANTA + S_PLANTA_DESCR      (planta canónica)
      S_PUNTO_DESCR                        (nombre del punto)
      L_MEDICION_PERSONA + S_PERSONA_DESCR (responsables: operador de panel y técnico en higiene)
      S_SEMANA_DESCR                       (fecha calendario)

    Los filtros particulares de cada pregunta (por punto, por planta, estado='no_medido') viven
    en configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT
        lm.huella_registro          AS medicion_hk,
        lm.ent_punto_medicion_hk,
        lm.ent_semana_hk,
        lm.punto_nro,
        lm.anio,
        lm.semana_nro,
        sm.concentracion_mg_m3,
        sm.fecha_medicion,
        sm.hora_inicio,
        sm.hora_termino,
        sm.estado,
        sm.motivo_no_medicion
    FROM {{ ref('silver_relacion_medicion') }} lm
    LEFT JOIN {{ ref('silver_detalle_medicion') }} sm
        ON lm.huella_registro = sm.huella_registro
       AND sm.valid_to IS NULL
),

punto AS (
    SELECT
        sp.huella_registro          AS ent_punto_medicion_hk,
        sp.nombre_punto
    FROM {{ ref('silver_detalle_punto_medicion') }} sp
    WHERE sp.valid_to IS NULL
),

planta AS (
    SELECT
        lpp.ent_punto_medicion_hk,
        lpp.planta_canon
    FROM {{ ref('silver_relacion_punto_planta') }} lpp
),

semana AS (
    SELECT
        ss.huella_registro          AS ent_semana_hk,
        ss.fecha_inicio_semana,
        ss.fecha_fin_semana
    FROM {{ ref('silver_detalle_semana') }} ss
    WHERE ss.valid_to IS NULL
),

-- Responsables resueltos vía el link rel_medicion_persona (operador / técnico por rol).
responsables AS (
    SELECT
        lmp.ent_punto_medicion_hk,
        lmp.ent_semana_hk,
        MAX(CASE WHEN lmp.rol = 'operador' THEN sp.nombre_completo END) AS operador_panel,
        MAX(CASE WHEN lmp.rol = 'tecnico'  THEN sp.nombre_completo END) AS tecnico_higiene
    FROM {{ ref('silver_relacion_medicion_persona') }} lmp
    LEFT JOIN {{ ref('silver_detalle_persona') }} sp
        ON lmp.ent_persona_hk = sp.huella_registro
       AND sp.valid_to IS NULL
    GROUP BY lmp.ent_punto_medicion_hk, lmp.ent_semana_hk
)

SELECT
    p.planta_canon,
    m.punto_nro,
    pt.nombre_punto,
    m.anio,
    m.semana_nro,
    s.fecha_inicio_semana,
    s.fecha_fin_semana,
    m.fecha_medicion,
    m.hora_inicio,
    m.hora_termino,
    m.concentracion_mg_m3,
    m.estado,
    m.motivo_no_medicion,
    r.operador_panel,
    r.tecnico_higiene,
    'fiscalizacion'::text   AS ambito
FROM medicion m
LEFT JOIN punto        pt ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta       p  ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
LEFT JOIN semana       s  ON m.ent_semana_hk         = s.ent_semana_hk
LEFT JOIN responsables r  ON m.ent_punto_medicion_hk = r.ent_punto_medicion_hk
                         AND m.ent_semana_hk         = r.ent_semana_hk
