#!/usr/bin/env bash
# Diagnóstico dos índices de banco/03-indices.sql. Só leitura: cada DROP INDEX roda dentro de uma
# transação que termina em ROLLBACK, então o banco volta ao estado original.
# Uso: diagnostico/diagnosticar-indices.sh depois-indices   (rode na raiz, com o banco ocioso)
set -euo pipefail
cd "$(dirname "$0")/.."

ROTULO="${1:?informe o rótulo, por exemplo: depois-indices}"
SAIDA="diagnostico/$(date +%Y%m%d)-${ROTULO}"
CONSULTAS="diagnostico/explain-rotas.sql"
psqlb() { docker compose exec -T banco psql -U loja -d loja "$@"; }

ATIVAS="$(psqlb -At -c "select count(*) from pg_stat_activity where backend_type='client backend' and datname='loja' and pid <> pg_backend_pid() and state <> 'idle';")"
if [ "$ATIVAS" != "0" ]; then echo "Há $ATIVAS consulta(s) ativa(s) no banco; espere ficar ocioso." >&2; exit 1; fi

mkdir -p "$SAIDA"

# 1) Uso e tamanho, capturados ANTES dos EXPLAIN (que também incrementam idx_scan).
psqlb -c '\dx' > "$SAIDA/extensoes.txt"
psqlb -c "select s.relname as tabela, s.indexrelname as indice, s.idx_scan, s.idx_tup_read, s.idx_tup_fetch from pg_stat_user_indexes s order by s.idx_scan desc, s.indexrelname;" > "$SAIDA/uso-indices.txt"
psqlb -c "select stats_reset from pg_stat_database where datname='loja';" >> "$SAIDA/uso-indices.txt"
psqlb -c "select s.indexrelname as indice, s.relname as tabela, pg_relation_size(s.indexrelid) as bytes, pg_size_pretty(pg_relation_size(s.indexrelid)) as tamanho from pg_stat_user_indexes s order by pg_relation_size(s.indexrelid) desc;" > "$SAIDA/tamanho-indices.txt"
psqlb -At -c "select indexname from pg_indexes where schemaname='public' and indexname like 'idx_%' order by 1;" > "$SAIDA/indices-presentes.txt"

# 2) EXPLAIN com todos os índices. Cada situação roda 2 vezes e guarda a 2ª (cache aquecido).
rodar() { # $1 = arquivo de saída, $2 = índice a remover (opcional)
  for passo in 1 2; do
    { echo "BEGIN;"; [ -n "${2:-}" ] && echo "DROP INDEX $2;"; cat "$CONSULTAS"; echo "ROLLBACK;"; } | psqlb > "$1.tmp" 2>&1
  done
  mv "$1.tmp" "$1"
}
rodar "$SAIDA/com-todos.txt"
while read -r idx; do rodar "$SAIDA/sem-${idx}.txt" "$idx"; done < "$SAIDA/indices-presentes.txt"

# 3) Confere que o banco voltou ao estado original.
psqlb -At -c "select indexname from pg_indexes where schemaname='public' and indexname like 'idx_%' order by 1;" | diff - "$SAIDA/indices-presentes.txt" && echo "Índices intactos depois do diagnóstico." | tee "$SAIDA/verificacao.txt"
echo "Saída em $SAIDA"
