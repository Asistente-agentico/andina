{#-
    bronce_equipos_ventilacion — Limpia el catálogo de equipos de ventilación (DAND)
    y normaliza los códigos de tipo y familia.

    Fuente: snap_equipos_ventilacion_catalogo (desde source equipos_ventilacion_catalogo).
    Macro: parsea_codigo_equipo (extrae tipo_equipo y familia_equipo del código ANCO-...).

    Una fila por equipo de control de polvo. Se conserva el código completo y se derivan:
      tipo_equipo:    último segmento del código (HDP / CDP / EPZ / VEX / VIN / PVA / PVM / PTV / PIN / DAM)
      familia_equipo: penúltimo segmento (SVE → renovacion_aire ; SCP → abatidor_polvo)

    Columnas de salida:
      equipo_denom, ubicacion_tecnica, tipo_equipo, familia_equipo,
      planta_canon, sector,
      _bronce_fuente, _bronce_loaded_at
-#}
{{
    config(
        materialized='view',
        tags=['capa:bronce', 'dominio:codelco_andina']
    )
}}

{{ parsea_codigo_equipo(ref('snap_equipos_ventilacion_catalogo'), 'Equipos_Ventilacion_DAND') }}
