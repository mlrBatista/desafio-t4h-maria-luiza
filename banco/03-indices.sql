-- Índices para as consultas das rotas (ver diagnostico/explain-rotas.txt).
-- Roda só quando o banco é criado do zero, depois de 01-estrutura.sql e 02-dados.sql.

-- GET /clientes?email= (WHERE lower(email) = lower($1))
CREATE INDEX idx_clientes_email_lower ON clientes (lower(email));

-- GET /clientes/:id/pedidos (pedidos do cliente e itens de cada pedido)
CREATE INDEX idx_pedidos_cliente_id ON pedidos (cliente_id);
CREATE INDEX idx_itens_pedido_pedido_id ON itens_pedido (pedido_id);

-- GET /pedidos?status=&pagina= (filtro por status, ordenado por criado_em DESC, id DESC)
CREATE INDEX idx_pedidos_status_criado_em ON pedidos (status, criado_em DESC, id DESC);

-- GET /relatorios/vendas-por-dia (WHERE criado_em::date BETWEEN ...)
CREATE INDEX idx_pedidos_criado_em_dia ON pedidos ((criado_em::date));

-- GET /produtos/busca?q= (nome ILIKE '%termo%')
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_produtos_nome_trgm ON produtos USING gin (nome gin_trgm_ops);

-- Estatísticas atualizadas para os índices novos, inclusive os de expressão.
ANALYZE;
