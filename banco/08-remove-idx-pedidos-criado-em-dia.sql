-- Remove o idx_pedidos_criado_em_dia (mudança 11).
-- Ele foi criado na mudança 02 (banco/03-indices.sql) para a consulta antiga de GET /relatorios/vendas-por-dia
-- (WHERE p.criado_em::date BETWEEN ...). Desde a mudança 06 essa rota lê vendas_por_dia_mv, e nenhuma consulta
-- das rotas usa o índice: o idx_scan ficou em 0 antes e depois das medições da mudança 07
-- (diagnostico/idx-scan-depois-07.txt), e o EXPLAIN das consultas de todas as rotas tem a mesma forma de plano
-- com e sem ele (diagnostico/mudanca-11/01-planos-resumo.txt).
-- Ele ocupa 3552 kB e é atualizado a cada escrita em pedidos; a carga do desafio só lê, então o ganho nas escritas não é medido.
-- Observação: um SELECT count(*) FROM pedidos pode usar este índice (é o menor índice da tabela), mas nenhuma rota faz isso;
-- sem ele, o count(*) usaria outro índice.
-- Não edita o 03-indices.sql: o histórico mostra que o índice foi criado na 02 e removido na 11.
-- Roda só quando o banco é criado do zero, depois de 07-pedidos-por-status.sql.

DROP INDEX idx_pedidos_criado_em_dia;
