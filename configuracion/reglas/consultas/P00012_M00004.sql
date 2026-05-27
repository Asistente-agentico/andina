-- P00012 — ¿Qué máquinas fueron medidas en la semana X?
-- Devuelve las máquinas generadoras medidas en una semana específica, con su concentración.
SELECT DISTINCT
    planta_canon,
    maquina_gen_nombre,
    punto_nro,
    nombre_punto,
    concentracion_mg_m3,
    fecha_medicion,
    anio,
    semana_nro
FROM {{ mart('M00004') }}
WHERE anio = {{ anio }}
  AND semana_nro = {{ semana }}
  AND estado = 'medido'
ORDER BY planta_canon, maquina_gen_nombre
