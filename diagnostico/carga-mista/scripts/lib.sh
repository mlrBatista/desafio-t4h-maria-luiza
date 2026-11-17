#!/usr/bin/env bash
# Funções do diagnóstico de carga mista. Tudo roda a partir da raiz do repositório e grava SÓ fora dele (em $CM),
# exceto o que o scripts/medir.sh grava em resultados/.
ESC=/tmp/claude-1000/-home-malu-batista-meu-desafio/8257610d-cd47-4742-9195-56d608c5324c
CM=$ESC/carga-mista
IMG=postgres:16.4
NET=desafio-performance_default
REPO=/home/malu_batista/meu-desafio
cd "$REPO"

aquecer() { # 60 s de carga sem gravar resultados (sem criar nada no repositório)
  docker compose run --rm -e VUS=20 -e DURACAO=60s -e SEMENTE=43 carga run --quiet --no-summary /carga/teste-carga.js >/dev/null 2>&1
}

verificar_ambiente() { # $1 = rótulo da série
  local sujo; sujo=$(git status --porcelain=v1 -uall -- . ':(exclude)resultados' | grep -c .)
  local a h; a=$(docker compose exec -T api sh -c 'cat src/*.js' | sha256sum | cut -c1-16); h=$(for f in db.js rotas.js server.js; do git show HEAD:api/src/$f; done | sha256sum | cut -c1-16)
  echo "[$1] git sujo: $sujo | código container=$a HEAD=$h | api $(docker inspect --format 'NanoCpus={{.HostConfig.NanoCpus}}' $(docker compose ps -q api)) banco $(docker inspect --format 'NanoCpus={{.HostConfig.NanoCpus}}' $(docker compose ps -q banco))"
  [ "$sujo" = "0" ] && [ "$a" = "$h" ]
}

# medir_serie <rotulo> <modo: A|B|C|D>; 3 execuções do scripts/medir.sh. Modos:
#  A = só o medir.sh | B = + pgbench de escrita (-c 2 -T 75 -R 50), iniciado quando o medir.sh começa o aquecimento
#  C = + REFRESH normal das 2 views, ~45 s depois de o medir.sh começar | D = + REFRESH CONCURRENTLY de vendas_por_dia_mv, no mesmo momento
medir_serie() {
  local rot=$1 modo=$2 n
  verificar_ambiente "$rot" || { echo "AMBIENTE NÃO OK antes da série $rot"; return 1; }
  echo "[$rot] aquecimento de 60 s (não grava resultados) em $(date '+%F %T')"; aquecer
  for n in 1 2 3; do
    local log=$CM/medir-$rot-$n.log
    local TM0; TM0=$(date +%s.%N)
    scripts/medir.sh "$rot" > "$log" 2>&1 &
    local MP=$!
    for i in $(seq 1 150); do grep -q "Aquecendo" "$log" 2>/dev/null && break; sleep 0.2; done
    local PG=""
    if [ "$modo" = "B" ]; then
      local PI; PI=$(date +%s.%N)
      docker run --rm --network "$NET" -v "$CM/pgb:/s:ro" -e PGDATABASE=loja --entrypoint pgbench "$IMG" \
        -h banco -U loja -n -c 2 -T 75 -R 50 -f /s/escrita.sql loja > "$CM/pgbench-$rot-$n.txt" 2>&1 &
      PG=$!
      echo "medir_inicio_epoch=$TM0 pgbench_inicio_epoch=$PI" > "$CM/tempos-$rot-$n.txt"
    fi
    if [ "$modo" = "C" ] || [ "$modo" = "D" ]; then
      local alvo; alvo=$(echo "$TM0 + 45" | bc); local agora; agora=$(date +%s.%N); local esp; esp=$(echo "$alvo - $agora" | bc)
      sleep "$esp"
      local f=refresh-normal.sql; [ "$modo" = "D" ] && f=refresh-concorrente.sql
      local RI; RI=$(date +%s.%N)
      docker compose exec -T banco psql -U loja -d loja -v ON_ERROR_STOP=1 -f - < "$CM/pgb/$f" > "$CM/refresh-$rot-$n.txt" 2>&1
      local RF; RF=$(date +%s.%N)
      echo "medir_inicio_epoch=$TM0 refresh_inicio_epoch=$RI refresh_fim_epoch=$RF (inicio $(date -d @${RI%.*} '+%F %T'))" > "$CM/tempos-$rot-$n.txt"
    fi
    wait "$MP"; [ -n "$PG" ] && wait "$PG"
    local d; d=$(ls -d resultados/*-"$rot" | tail -1)
    echo "[$rot] execução $n: $(basename $d) | $(grep 'Requisições/s' $d/resumo.txt | tr -s ' ') | recursos.csv $(awk -F, 'NR==2{a=$1} END{print a" a "$1}' $d/recursos.csv) | $(grep -E '^arquivos' $d/contexto.txt) | $(tail -3 "$log" | grep -i 'contrato' | head -1)"
  done
}
