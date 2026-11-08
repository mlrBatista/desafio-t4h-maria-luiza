-- Consulta candidata: agregar vendas-por-dia no SQL (31 dias: 2025-01-01 a 2025-01-31), banco ocioso.
EXPLAIN (ANALYZE, BUFFERS)
SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia,
       count(DISTINCT p.id) AS pedidos,
       sum(i.quantidade) AS itens,
       sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN '2025-01-01' AND '2025-01-31'
   AND p.status <> 'cancelado'
 GROUP BY 1
 ORDER BY 1;
