{#-
    bronce_mediciones — Transforma las 9 hojas de medición del formato ancho al largo
    (1 fila por planta + punto + semana) y las ENRIQUECE con el catálogo de puntos.

    Cadena:
      snap_puntos_*  →  unpivot_mediciones_planta (macro)  →  union 9 plantas
                     →  JOIN normalizado contra seed puntos_catalogo
                     →  emite las columnas que la capa silver espera.

    El JOIN es robusto (Opción B): normaliza punto_evaluacion en ambos lados
    (minúsculas + trim + colapso de espacios) para tolerar dobles espacios y
    diferencias de formato entre el snapshot y el seed.

    Columnas de salida (consumidas por los 5 silver de medición):
      planta, planta_canon, punto_evaluacion, punto_nro,
      maquina_gen_codigo, componente_codigo, componente_codigo_full,
      nombre_punto, descripcion_punto, tipo_punto, maquina_gen_nombre, tipo_maquina_gen, descripcion,
      anio, semana_nro, concentracion_mg_m3,
      estado, motivo_no_medicion, fecha_medicion,
      operador_alias, tecnico_alias, hora_inicio, hora_termino,
      _col_posicion, _bronce_fuente, _bronce_loaded_at
-#}
{{
    config(
        materialized='view',
        tags=['capa:bronce', 'dominio:codelco_andina']
    )
}}

WITH unpivot_todas AS (
    {{ unpivot_mediciones_planta(ref('snap_puntos_prechancado'),           'Prechancado')           }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_chancado_2_3'),          'Chancado 2° y 3°')      }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_terciario'),             'Chancado Fino 3°')      }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_cuaternario'),           'Chancado Fino 4°')      }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_molienda_sag'),          'Molienda SAG')          }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_molienda_convencional'), 'Molienda Convencional') }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_cdm_1'),                 'CDM Linea 1')           }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_cdm_2'),                 'CDM Linea 2')           }}
    UNION ALL
    {{ unpivot_mediciones_planta(ref('snap_puntos_nodo'),                  'Nodo 3500')             }}
),

-- Normaliza el texto del punto para el JOIN robusto (Opción B)
medicion_norm AS (
    SELECT
        *,
        lower(trim(regexp_replace(punto_evaluacion, '\s+', ' ', 'g'))) AS _punto_eval_norm
    FROM unpivot_todas
),

-- Catálogo de puntos: el puente texto → número + planta + máquina + componente
catalogo AS (
    SELECT
        punto_nro,
        planta_canon,
        maquina_gen_codigo,
        componente_codigo,
        nombre_punto,
        descripcion_punto,
        tipo_punto,
        maquina_gen_nombre,
        tipo_maquina_gen,
        descripcion,
        lower(trim(regexp_replace(punto_evaluacion, '\s+', ' ', 'g'))) AS _punto_eval_norm
    FROM {{ ref('puntos_catalogo') }}
)

SELECT
    m.planta,
    c.planta_canon,
    m.punto_evaluacion,
    c.punto_nro,
    c.maquina_gen_codigo,
    c.componente_codigo,
    c.maquina_gen_codigo || '_' || c.componente_codigo   AS componente_codigo_full,
    c.nombre_punto,
    c.descripcion_punto,
    c.tipo_punto,
    c.maquina_gen_nombre,
    c.tipo_maquina_gen,
    c.descripcion,
    m.anio,
    m.semana                                AS semana_nro,
    m.concentracion_mg_m3,
    CASE
        WHEN m.concentracion_mg_m3 IS NULL THEN 'no_medido'
        ELSE 'medido'
    END                                     AS estado,
    CASE
        WHEN m.concentracion_mg_m3 IS NULL THEN 'sin_registro'
        ELSE NULL
    END                                     AS motivo_no_medicion,
    m.fecha                                 AS fecha_medicion,
    m.operador_alias,
    m.tecnico_alias,
    m.hora_inicio,
    m.hora_termino,
    m._col_posicion,
    m._bronce_fuente,
    m._bronce_loaded_at

FROM medicion_norm m
LEFT JOIN catalogo c
    ON m._punto_eval_norm = c._punto_eval_norm
