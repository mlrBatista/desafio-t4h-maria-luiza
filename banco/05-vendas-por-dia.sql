-- Dado derivado para GET /relatorios/vendas-por-dia (ver diagnostico/ e a mudança 06).
-- A view guarda o resumo de vendas por dia, calculado uma vez na criação do banco, com as mesmas
-- definições da consulta da rota: pedidos não cancelados, pedidos = count(DISTINCT p.id),
-- itens = sum(quantidade), receita = sum(quantidade * preço unitário).
-- Ela é uma FOTO da criação do banco: NÃO acompanha mudanças posteriores em pedidos/itens_pedido.
-- Se os dados mudarem, é preciso rodar REFRESH MATERIALIZED VIEW vendas_por_dia_mv
-- (ou REFRESH MATERIALIZED VIEW CONCURRENTLY, possível por causa do índice único em dia).
-- A API só lê dados, então aqui a view não fica desatualizada.
-- Roda só quando o banco é criado do zero, depois de 04-top-produtos.sql.

CREATE MATERIALIZED VIEW vendas_por_dia_mv AS
SELECT p.criado_em::date AS dia,
       count(DISTINCT p.id) AS pedidos,
       sum(i.quantidade) AS itens,
       sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.status <> 'cancelado'
 GROUP BY p.criado_em::date;

CREATE UNIQUE INDEX idx_vendas_por_dia_mv_dia ON vendas_por_dia_mv (dia);

ANALYZE vendas_por_dia_mv;
