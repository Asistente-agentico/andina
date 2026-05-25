SELECT
    planta,
    COUNT(CASE WHEN estado_limite = 'sobre_limite' THEN 1 END) AS valor_actual,
    COUNT(*)                                                    AS puntos_totales
FROM {{ modelo_oro }}
WHERE 1=1
{{ where_gobernanza }}
GROUP BY planta
ORDER BY valor_actual DESC
