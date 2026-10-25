-- Evolução mensal dos pedidos entregues
-- "amostra pequena" = menos de 100 pedidos (critério do projeto)
SELECT
    ano_mes_compra,
    qtd_pedidos,
    valor_itens,
    ROUND(CAST(valor_itens AS DOUBLE) / NULLIF(qtd_pedidos_com_itens, 0), 2) AS ticket_medio_itens,
    ROUND(100.0 * CAST(valor_frete AS DOUBLE) / NULLIF(CAST(valor_itens AS DOUBLE), 0), 2) AS frete_sobre_itens_pct,
    ROUND(100.0 * qtd_entregas_com_atraso / NULLIF(qtd_entregas_avaliaveis, 0), 2) AS entregas_atrasadas_pct,
    CASE WHEN qtd_pedidos < 100 THEN 'amostra pequena' ELSE 'ok' END AS volume
FROM olist_gold.gold_vendas_mensal
WHERE order_status = 'delivered'
ORDER BY ano_mes_compra;