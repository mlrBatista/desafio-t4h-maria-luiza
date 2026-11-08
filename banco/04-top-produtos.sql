-- Dado derivado para GET /relatorios/top-produtos (ver diagnostico/explain-top-produtos-mv.txt).
-- A view guarda o resultado da agregação feita uma vez, na criação do banco.
-- Ela NÃO acompanha mudanças posteriores em pedidos/itens_pedido: para atualizar, é preciso
-- rodar REFRESH MATERIALIZED VIEW top_produtos_mv. A API só lê dados, então aqui não fica desatualizada.
-- Roda só quando o banco é criado do zero, depois de 03-indices.sql.

CREATE MATERIALIZED VIEW top_produtos_mv AS
SELECT pr.id, pr.nome, pr.categoria,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
  FROM itens_pedido i
  JOIN pedidos p ON p.id = i.pedido_id
  JOIN produtos pr ON pr.id = i.produto_id
 WHERE p.status <> 'cancelado'
 GROUP BY pr.id, pr.nome, pr.categoria;

CREATE INDEX idx_top_produtos_mv_receita ON top_produtos_mv (receita_centavos DESC, id);

ANALYZE top_produtos_mv;
