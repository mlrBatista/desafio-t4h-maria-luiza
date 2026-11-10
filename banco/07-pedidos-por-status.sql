-- Tabela-resumo com o total de pedidos por status, mantida por trigger (mudança 08).
-- Motivo: a contagem de GET /pedidos (SELECT count(*) FROM pedidos WHERE status = $1) lê centenas de milhares
-- de entradas de índice a cada chamada (diagnostico/explain-pedidos-07-resumo.txt: mediana de 205.306 ms em
-- 'pago' com o banco ocioso). Lendo o total de uma tabela de 4 linhas, a contagem deixa de usar CPU do banco.
-- Por que trigger e não materialized view: o total precisa continuar correto se pedidos forem inseridos,
-- apagados ou mudarem de status, sem depender de REFRESH (a view de top_produtos_mv e a de vendas_por_dia_mv
-- são fotos da criação do banco; esta tabela não é).
-- Custo: cada INSERT, DELETE ou mudança de status em pedidos passa a atualizar também uma linha desta tabela.
-- Limite de concorrência: todas as escritas de um mesmo status atualizam a MESMA linha e esperam umas pelas
-- outras até o fim da transação. A carga do desafio só lê, então ela nunca dispara estes triggers; a evidência
-- de que eles estão certos está em diagnostico/ (teste dentro de BEGIN/ROLLBACK).
-- TRUNCATE: coberto por um trigger por comando, que zera os totais.
-- Roda só quando o banco é criado do zero, depois de 06-pedidos-indice-cobrindo.sql.

CREATE TABLE pedidos_por_status (
    status text   PRIMARY KEY,
    total  bigint NOT NULL
);

-- Preenchimento inicial, com os pedidos já carregados por 02-dados.sql (os triggers só existem depois).
INSERT INTO pedidos_por_status (status, total)
SELECT status, count(*) FROM pedidos GROUP BY status;

CREATE FUNCTION pedidos_por_status_ajusta() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO pedidos_por_status (status, total) VALUES (NEW.status, 1)
        ON CONFLICT (status) DO UPDATE SET total = pedidos_por_status.total + 1;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE pedidos_por_status SET total = total - 1 WHERE status = OLD.status;
    ELSIF TG_OP = 'UPDATE' THEN
        UPDATE pedidos_por_status SET total = total - 1 WHERE status = OLD.status;
        INSERT INTO pedidos_por_status (status, total) VALUES (NEW.status, 1)
        ON CONFLICT (status) DO UPDATE SET total = pedidos_por_status.total + 1;
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION pedidos_por_status_zera() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE pedidos_por_status SET total = 0;
    RETURN NULL;
END;
$$;

CREATE TRIGGER pedidos_por_status_insert
    AFTER INSERT ON pedidos
    FOR EACH ROW EXECUTE FUNCTION pedidos_por_status_ajusta();

CREATE TRIGGER pedidos_por_status_delete
    AFTER DELETE ON pedidos
    FOR EACH ROW EXECUTE FUNCTION pedidos_por_status_ajusta();

-- Só dispara quando o status realmente muda (UPDATE de outras colunas, ou do mesmo valor, não custa nada).
CREATE TRIGGER pedidos_por_status_update
    AFTER UPDATE OF status ON pedidos
    FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION pedidos_por_status_ajusta();

CREATE TRIGGER pedidos_por_status_truncate
    AFTER TRUNCATE ON pedidos
    FOR EACH STATEMENT EXECUTE FUNCTION pedidos_por_status_zera();

ANALYZE pedidos_por_status;
