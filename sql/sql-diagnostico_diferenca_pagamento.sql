-- 1) Sentido da diferença (print 03a)
SELECT
    COUNT(*)                                                           AS pedidos,
    SUM(CASE WHEN diferenca_pago_vs_itens_frete > 0 THEN 1 ELSE 0 END) AS pago_maior,
    SUM(CASE WHEN diferenca_pago_vs_itens_frete < 0 THEN 1 ELSE 0 END) AS pago_menor,
    MIN(diferenca_pago_vs_itens_frete)                                 AS menor_dif,
    MAX(diferenca_pago_vs_itens_frete)                                 AS maior_dif,
    SUM(diferenca_pago_vs_itens_frete)                                 AS soma_dif
FROM olist_gold.gold_pedidos
WHERE dq_diferenca_pagamento = true;

-- 2) Parcelado x à vista (print 03b)
-- O pagamento é agregado por pedido antes do join
SELECT
    CASE WHEN m.max_parcelas > 1 THEN 'parcelado' ELSE 'a vista' END AS forma,
    COUNT(*)                                                         AS pedidos_total,
    SUM(CASE WHEN g.dq_diferenca_pagamento THEN 1 ELSE 0 END)        AS pedidos_com_dif,
    ROUND(100.0 * SUM(CASE WHEN g.dq_diferenca_pagamento THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_com_dif
FROM olist_gold.gold_pedidos g
JOIN (
    SELECT order_id, MAX(payment_installments) AS max_parcelas
    FROM olist.order_payments
    GROUP BY order_id
) m ON m.order_id = g.order_id
WHERE g.dq_diferenca_pagamento IS NOT NULL
GROUP BY 1;

-- 3) Taxa por tipo de pagamento (print 03c)
-- Um pedido com mais de um tipo aparece em mais de uma linha
SELECT
    p.payment_type,
    COUNT(DISTINCT g.order_id)                                              AS pedidos_total,
    COUNT(DISTINCT CASE WHEN g.dq_diferenca_pagamento THEN g.order_id END)  AS pedidos_com_dif,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN g.dq_diferenca_pagamento THEN g.order_id END)
        / COUNT(DISTINCT g.order_id), 2
    )                                                                       AS pct_com_dif
FROM olist_gold.gold_pedidos g
JOIN olist.order_payments p ON p.order_id = g.order_id
WHERE g.dq_diferenca_pagamento IS NOT NULL
GROUP BY p.payment_type
ORDER BY pct_com_dif DESC;