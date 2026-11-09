-- Índice cobrindo para GET /pedidos?status=&pagina= (mudança 07).
-- Motivo: a consulta da página usa OFFSET e, com SELECT *, visita a tabela para cada linha que percorre
-- (na página 1000 de 'pago', 20101 buffers lidos). Em 'cancelado' e 'pendente' o plano chega a trocar para
-- Parallel Bitmap Heap Scan com ordenação em disco. Com este índice e a consulta pedindo só as 4 colunas
-- da resposta (id, cliente_id, status, criado_em), a página vira Index Only Scan.
-- O índice substitui o idx_pedidos_status_criado_em do 03-indices.sql: ele tem as mesmas colunas de chave
-- mais cliente_id em INCLUDE, então atende também a contagem por status e a ordenação da página.
-- O índice e a mudança na rota (api/src/rotas.js) formam uma hipótese só: um não funciona sem o outro.
-- Evidência: diagnostico/explain-pedidos-resumo.txt (EXPLAIN com o índice cobrindo dentro de BEGIN/ROLLBACK).
-- Roda só quando o banco é criado do zero, depois de 05-vendas-por-dia.sql.

DROP INDEX idx_pedidos_status_criado_em;

CREATE INDEX idx_pedidos_status_criado_em_cobrindo
    ON pedidos (status, criado_em DESC, id DESC) INCLUDE (cliente_id);

ANALYZE pedidos;
