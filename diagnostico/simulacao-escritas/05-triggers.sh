#!/usr/bin/env bash
# Passo 5: custo dos triggers de pedidos_por_status sob escritas simultâneas, SÓ em loja_teste (cópia).
# 8 combinações x 3 execuções de pgbench -n -T 30: trigger (com/sem) x clientes (1 / 10 com -j 2) x status (fixo 'pago' / sorteado entre os 4).
# A ordem das combinações muda a cada rodada (ordem normal, invertida e rotacionada), para o aquecimento e o autovacuum não favorecerem um lado.
# O pgbench roda em um container separado (postgres:16.4, mesma rede); o servidor continua com 1 CPU e 512 MB.
set -euo pipefail
cd "$(dirname "$0")/../.."
D=diagnostico/simulacao-escritas
IMG=postgres:16.4
NET=desafio-performance_default
OUT="$D/05-pgbench-triggers.txt"

pg() { docker compose exec -T banco psql -U loja -d loja_teste -v ON_ERROR_STOP=1 "$@"; }

COMBOS=("com 1 fixo" "sem 1 fixo" "com 1 sorteado" "sem 1 sorteado" "com 10 fixo" "sem 10 fixo" "com 10 sorteado" "sem 10 sorteado")
ordem() { # $1 = rodada -> imprime os índices das combinações na ordem desta rodada
  case "$1" in
    1) echo "0 1 2 3 4 5 6 7";;
    2) echo "7 6 5 4 3 2 1 0";;
    3) echo "3 4 5 6 7 0 1 2";;
  esac
}

# Condições e estado inicial (não toca no banco loja)
{
  echo "##### INÍCIO $(date '+%F %T %z')"
  pg -At -c "SELECT 'banco: ' || current_database();"
  pg -c "SELECT status, total FROM pedidos_por_status ORDER BY status;" -c "SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;"
} >> "$OUT" 2>&1

for rodada in 1 2 3; do
  for i in $(ordem "$rodada"); do
    read -r TRIG CLI ST <<< "${COMBOS[$i]}"
    if [ "$TRIG" = "sem" ]; then ACAO=DISABLE; else ACAO=ENABLE; fi
    pg -c "ALTER TABLE pedidos $ACAO TRIGGER pedidos_por_status_insert;" -c "ALTER TABLE pedidos $ACAO TRIGGER pedidos_por_status_delete;" > /dev/null
    ESTADO=$(pg -At -c "SELECT string_agg(tgname || '=' || tgenabled::text, ',' ORDER BY tgname) FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND tgname IN ('pedidos_por_status_insert', 'pedidos_por_status_delete');")
    if [ "$CLI" = "1" ]; then J=1; else J=2; fi
    echo "##### rodada $rodada | trigger=$TRIG | clientes=$CLI | status=$ST | início $(date '+%F %T %z') | estado dos triggers: $ESTADO" >> "$OUT"
    docker run --rm --network "$NET" -v "$PWD/$D/pgbench:/s:ro" -e PGDATABASE=loja_teste --entrypoint pgbench "$IMG" \
      -h banco -U loja -n -T 30 -c "$CLI" -j "$J" -f "/s/escrita-$ST.sql" loja_teste >> "$OUT" 2>&1
    sleep 2
  done
done

# Religa tudo e confere
pg -c "ALTER TABLE pedidos ENABLE TRIGGER pedidos_por_status_insert;" -c "ALTER TABLE pedidos ENABLE TRIGGER pedidos_por_status_delete;" > /dev/null
{
  echo "##### FIM $(date '+%F %T %z') | triggers religados"
  pg -c "SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'pedidos'::regclass AND NOT tgisinternal ORDER BY 1;" \
     -c "SELECT s.status, s.total AS resumo, c.n AS contagem, (s.total = c.n) AS bate FROM pedidos_por_status s FULL JOIN (SELECT status, count(*) AS n FROM pedidos GROUP BY status) c ON c.status = s.status ORDER BY 1;" \
     -c "SELECT relname, n_live_tup, n_dead_tup, last_autovacuum, autovacuum_count FROM pg_stat_user_tables WHERE relname IN ('pedidos', 'pedidos_por_status') ORDER BY 1;"
} >> "$OUT" 2>&1
echo "terminado"
