# Dicionário de dados

Convenções:

- **Silver** = `s3://<bucket>/silver/olist/<entidade>/`, database `olist`.
- **Gold** = `s3://<bucket>/gold/olist/<tabela>/`, database `olist_gold`.
- Colunas `dq_*` são flags de qualidade. Elas **sinalizam**, não removem registros.
- Nomes originais preservados, inclusive o erro de grafia `lenght` da fonte.
- IDs e prefixos de CEP ficam como `string` para manter zeros à esquerda (ex.: `01151`).

---

## Silver

### orders (1 linha por pedido; chave: `order_id`)

| Coluna | Tipo | Observação |
|---|---|---|
| order_id | string | Chave |
| customer_id | string | FK → customers |
| order_status | string | delivered, shipped, canceled, unavailable, invoiced, processing, created, approved |
| order_purchase_timestamp | timestamp | |
| order_approved_at | timestamp | Pode ser nulo |
| order_delivered_carrier_date | timestamp | Pode ser nulo |
| order_delivered_customer_date | timestamp | Pode ser nulo |
| order_estimated_delivery_date | timestamp | Vem às 00:00:00 |
| dq_delivered_sem_aprovacao | boolean | Pedido `delivered` sem data de aprovação |
| dq_delivered_sem_envio | boolean | Pedido `delivered` sem data de envio |
| dq_delivered_sem_entrega | boolean | Pedido `delivered` sem data de entrega |
| dq_alerta_datas_delivered | boolean | Qualquer uma das três anteriores |

### order_items (chave composta: `order_id` + `order_item_id`)

| Coluna | Tipo | Observação |
|---|---|---|
| order_id | string | FK → orders |
| order_item_id | int | Sequência do item no pedido |
| product_id | string | FK → products |
| seller_id | string | FK → sellers |
| shipping_limit_date | timestamp | |
| price | decimal(18,2) | Preço do item |
| freight_value | decimal(18,2) | Frete do item |

### order_payments (chave composta: `order_id` + `payment_sequential`)

| Coluna | Tipo | Observação |
|---|---|---|
| order_id | string | FK → orders |
| payment_sequential | int | |
| payment_type | string | credit_card, boleto, voucher, debit_card |
| payment_installments | int | |
| payment_value | decimal(18,2) | |

### customers (chave: `customer_id`)

| Coluna | Tipo |
|---|---|
| customer_id | string |
| customer_unique_id | string |
| customer_zip_code_prefix | string |
| customer_city | string |
| customer_state | string |

### sellers (chave: `seller_id`)

| Coluna | Tipo |
|---|---|
| seller_id | string |
| seller_zip_code_prefix | string |
| seller_city | string |
| seller_state | string |

### products (chave: `product_id`)

| Coluna | Tipo | Observação |
|---|---|---|
| product_id | string | |
| product_category_name | string | 610 nulos |
| product_name_lenght | int | 610 nulos |
| product_description_lenght | int | 610 nulos |
| product_photos_qty | int | 610 nulos |
| product_weight_g | int | 2 nulos |
| product_length_cm | int | 2 nulos |
| product_height_cm | int | 2 nulos |
| product_width_cm | int | 2 nulos |

### geolocation

| Coluna | Tipo | Observação |
|---|---|---|
| geolocation_zip_code_prefix | string | **Não é chave única**: o mesmo prefixo aparece com várias coordenadas |
| geolocation_lat | double | |
| geolocation_lng | double | |
| geolocation_city | string | |
| geolocation_state | string | |

---

## Gold

### gold_pedidos (1 linha por pedido)

Todas as colunas de `orders` (incluindo as flags `dq_*` de datas), mais:

| Coluna | Tipo | Definição |
|---|---|---|
| customer_unique_id | string | De `customers` |
| customer_city | string | De `customers` |
| customer_state | string | De `customers` |
| qtd_itens | bigint | Número de linhas de item do pedido. Nulo se o pedido não tem itens |
| qtd_produtos_distintos | bigint | Produtos distintos no pedido |
| valor_itens | decimal | Soma de `price` |
| valor_frete | decimal | Soma de `freight_value` |
| valor_itens_mais_frete | decimal | `valor_itens` + `valor_frete` |
| qtd_registros_pagamento | bigint | Número de registros de pagamento. Nulo se não há pagamento |
| qtd_tipos_pagamento | bigint | Tipos de pagamento distintos |
| valor_pago | decimal | Soma de `payment_value` |
| ano_mes_compra | string | `yyyy-MM` de `order_purchase_timestamp` |
| dq_sem_itens | boolean | Pedido sem nenhum item |
| dq_sem_pagamento | boolean | Pedido sem nenhum registro de pagamento |
| diferenca_pago_vs_itens_frete | decimal | `valor_pago` − `valor_itens_mais_frete`. Nulo se faltar um dos lados |
| dq_diferenca_pagamento | boolean | `true` se a diferença absoluta for maior que 0,01. Nulo se não avaliável |
| entregue_com_atraso | boolean | Data de entrega > data estimada (comparação por **data**). Nulo se faltar uma das datas |

**Nulo não é zero.** Valores e contagens ficam nulos quando o pedido não tem item ou pagamento, para não confundir ausência de dado com valor efetivamente zero.

### gold_vendas_mensal (1 linha por `ano_mes_compra` × `order_status`)

Contém só medidas **aditivas**. Razões e médias são calculadas na consulta, porque média de médias gera números errados ao reagregar.

| Coluna | Tipo | Definição |
|---|---|---|
| ano_mes_compra | string | Mês de compra (`yyyy-MM`) |
| order_status | string | Status do pedido |
| qtd_pedidos | bigint | Pedidos no grupo |
| qtd_pedidos_com_itens | bigint | Pedidos com pelo menos um item |
| qtd_pedidos_com_pagamento | bigint | Pedidos com pelo menos um pagamento |
| qtd_itens | bigint | Soma de itens |
| valor_itens | decimal | Soma do valor dos itens |
| valor_frete | decimal | Soma do frete |
| valor_pago | decimal | Soma dos pagamentos |
| qtd_entregas_avaliaveis | bigint | Pedidos com data de entrega **e** data estimada |
| qtd_entregas_com_atraso | bigint | Entre os avaliáveis, entregues após a data estimada |
| qtd_pedidos_dif_pagamento | bigint | Pedidos com `dq_diferenca_pagamento = true` |

---

## Definições de indicadores

| Indicador | Cálculo |
|---|---|
| Ticket médio dos itens | `valor_itens` ÷ `qtd_pedidos_com_itens` (sem frete) |
| Frete sobre itens (%) | `valor_frete` ÷ `valor_itens` × 100 |
| Entregas atrasadas (%) | `qtd_entregas_com_atraso` ÷ `qtd_entregas_avaliaveis` × 100 |

"Valor dos itens" **não é receita contábil**. Cada análise deve explicitar o filtro de status usado.
