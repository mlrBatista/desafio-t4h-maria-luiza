#!/usr/bin/env bash
# Passo 4: o REFRESH trava as leituras? pgbench de leitura (5 clientes, 20 s) em loja_teste (cópia), em 3 situações:
#   sem-refresh (linha de referência), refresh-normal e refresh-concorrente (o REFRESH é disparado ~8 s depois de iniciar o pgbench).
# O pgbench roda em um container separado (mesma imagem do banco, mesma rede), para não dividir a CPU limitada do container do banco.
# Uso: 04-leituras-vs-refresh.sh <pasta de logs fora do repositório>
set -euo pipefail
cd "$(dirname "$0")/../.."
D=diagnostico/simulacao-escritas
LOGS="${1:?informe a pasta de logs}"
IMG=postgres:16.4
NET=desafio-performance_default
mkdir -p "$LOGS" && chmod 777 "$LOGS"
: > "$D/04-janelas-refresh.txt"

pg() { docker compose exec -T banco psql -U loja -d loja_teste -v ON_ERROR_STOP=1 "$@"; }

for caso in sem-refresh refresh-normal refresh-concorrente; do
  echo "##### caso $caso | início $(date '+%F %T %z')" | tee -a "$D/04-pgbench-leituras.txt"
  docker run --rm --network "$NET" -v "$PWD/$D/pgbench:/s:ro" -v "$LOGS:/logs" -e PGDATABASE=loja_teste --entrypoint pgbench "$IMG" \
    -h banco -U loja -n -c 5 -T 20 --progress=1 -l --log-prefix="/logs/leitura-$caso" -f /s/leitura.sql loja_teste \
    >> "$D/04-pgbench-leituras.txt" 2>&1 &
  PID=$!
  if [ "$caso" != "sem-refresh" ]; then
    sleep 8
    T0=$(date +%s.%N)
    pg -f - < "$D/refresh-${caso#refresh-}.sql" > "$D/04-refresh-$caso.txt" 2>&1
    T1=$(date +%s.%N)
    echo "$caso refresh_inicio_epoch=$T0 refresh_fim_epoch=$T1" >> "$D/04-janelas-refresh.txt"
  fi
  wait "$PID"
  echo "##### fim do caso $caso | $(date '+%F %T %z')" >> "$D/04-pgbench-leituras.txt"
  sleep 3
done
docker run --rm -v "$LOGS:/logs" alpine chmod -R a+r /logs >/dev/null 2>&1 || true
echo "logs por transação em $LOGS"
