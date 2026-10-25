# Decisões de arquitetura

Registro curto de cada decisão, o motivo e o que ficou de fora.

## 1. Preservar a Raw sem limpeza

**Decisão:** enviar os CSVs ao S3 exatamente como vieram, uma pasta por entidade.
**Motivo:** manter a origem intacta e deixar toda transformação em código reproduzível. A orientação da AWS para a camada raw é manter os dados no formato original.
**Consequência:** nenhuma regra de limpeza existe fora dos notebooks.

## 2. Ler os CSVs direto do S3, sem passar pelo catálogo da Raw

**Contexto:** o crawler catalogou `orders` com colunas genéricas (`col0`, `col1`, ...), isto é, sem reconhecer o cabeçalho, embora o arquivo tenha cabeçalho correto.
**Decisão:** ler os CSVs com Spark (`header=true`, `inferSchema=false`, tudo como texto) e controlar a tipagem no código. O database `olist_raw` ficou como exploração, fora do fluxo.
**Alternativa não adotada:** criar um classificador CSV personalizado e refazer o crawler. É viável, mas a leitura direta separa o erro de catalogação do tratamento dos dados.
**Papel do catálogo:** passa a ser usado nas camadas Silver e Gold, onde o esquema é conhecido e o Parquet o preserva.

## 3. Parquet na Release 1; Iceberg na Release 2

**Decisão:** gravar Silver e Gold em Parquet (snappy), com modo `errorifexists`.
**Motivo:** a Release 1 é uma carga completa, sem upsert nem reprocessamento incremental. Parquet resolve, e `errorifexists` impede sobrescrita acidental.
**Plano:** migrar para Iceberg quando entrar carga incremental, porque o Athena suporta `MERGE INTO` em tabelas Iceberg. Delta Lake seria a alternativa, mas o suporte documentado do Athena é para Iceberg.

## 4. Preservar nulos e sinalizar com flags `dq_*`

**Decisão:** não aplicar `dropna()`, não preencher datas e não usar zero no lugar de ausência.
**Motivo:** as ausências carregam significado. Pedidos `shipped` não têm data de entrega, e isso é esperado. Pedidos `delivered` sem data de entrega são um alerta.
**Consequência:** os indicadores declaram quantos registros ficaram fora do cálculo (`qtd_entregas_avaliaveis`).

## 5. IDs e CEPs como texto

**Decisão:** manter `string` em IDs e prefixos de CEP.
**Motivo:** preservar zeros à esquerda (`01151`) e evitar conversões desnecessárias.

## 6. Agregar antes de juntar

**Decisão:** agregar itens e pagamentos para uma linha por pedido antes dos joins, com `LEFT JOIN`.
**Motivo:** um pedido pode ter vários itens e vários pagamentos. Juntar os dois no detalhe multiplica os valores.
**Prova:** as somas de itens, frete e pagamentos na Gold são idênticas às da Silver.

## 7. `geolocation` sem deduplicação por CEP

**Decisão:** não deduplicar nem usar o prefixo de CEP como chave.
**Motivo:** o mesmo prefixo aparece com várias coordenadas. Se for usada em análises geográficas, a tabela exige uma regra explícita de representação.

## 8. Mart mensal só com medidas aditivas

**Decisão:** `gold_vendas_mensal` guarda contagens e somas; ticket médio e percentuais são calculados na consulta.
**Motivo:** média de médias gera números errados ao reagregar por mês, status ou ano.

## 9. Limite de "amostra pequena"

**Decisão:** sinalizar meses com menos de 100 pedidos nas consultas.
**Motivo:** com poucos pedidos, os percentuais oscilam muito. Em 2016-09 há um único pedido entregue, com 100% de atraso.
**Observação:** o limite de 100 é uma escolha deste projeto, não uma regra da fonte.

## 10. Databases separados por camada

**Decisão:** `olist_raw` (exploratório), `olist` (Silver) e `olist_gold` (Gold).
**Observação:** o database `olist` contém a Silver. Renomear para `olist_silver` é opcional e só exige refazer o crawler, sem regravar dados.

## Pendências conhecidas

- A diferença entre valor pago e itens + frete (303 pedidos) é consistente com acréscimos de parcelamento, mas não está confirmada. Os 34 casos à vista e os 39 com valor pago menor não foram explicados.
- Os notebooks são executados manualmente. A conversão em jobs e a orquestração estão na Release 3.
