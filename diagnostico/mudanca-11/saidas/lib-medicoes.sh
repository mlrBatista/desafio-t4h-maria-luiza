#!/usr/bin/env bash
# Funções da mudança 11 (A-B-A). Tudo grava SÓ fora do repositório ($C11), exceto o que o scripts/medir.sh grava em resultados/.
ESC=/tmp/claude-1000/-home-malu-batista-meu-desafio/8257610d-cd47-4742-9195-56d608c5324c
C11=$ESC/carga-11
REPO=/home/malu_batista/meu-desafio
mkdir -p "$C11"
cd "$REPO"

energia() { powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; \$p = [System.Windows.Forms.SystemInformation]::PowerStatus; 'PowerLineStatus=' + \$p.PowerLineStatus + ' carga=' + [int](\$p.BatteryLifePercent*100) + '%'" 2>&1 | head -1 | tr -d '\r'; }

aquecer() { docker compose run --rm -e VUS=20 -e DURACAO=60s -e SEMENTE=43 carga run --quiet --no-summary /carga/teste-carga.js >/dev/null 2>&1; }

verificar_ambiente() { # $1 = rótulo
  local sujo a h e; sujo=$(git status --porcelain=v1 -uall -- . ':(exclude)resultados' | grep -c .)
  a=$(docker compose exec -T api sh -c 'cat src/*.js' | sha256sum | cut -c1-16); h=$(for f in db.js rotas.js server.js; do git show HEAD:api/src/$f; done | sha256sum | cut -c1-16)
  e=$(energia)
  echo "[$1] git sujo: $sujo | código container=$a HEAD=$h | api $(docker inspect --format 'NanoCpus={{.HostConfig.NanoCpus}}' $(docker compose ps -q api)) banco $(docker inspect --format 'NanoCpus={{.HostConfig.NanoCpus}}' $(docker compose ps -q banco)) | $e"
  [ "$sujo" = "0" ] && [ "$a" = "$h" ] && echo "$e" | grep -q "Online"
}

tamanhos() { # $1 = rótulo; grava fora do repositório
  { echo "# tamanhos dos índices de pedidos em $(date '+%F %T %z') ($1)"; docker compose exec -T banco psql -U loja -d loja -c "SELECT indexrelname AS indice, pg_relation_size(indexrelid) AS bytes, pg_size_pretty(pg_relation_size(indexrelid)) AS tamanho FROM pg_stat_user_indexes WHERE relname = 'pedidos' ORDER BY 1;" -c "SELECT count(*) AS indices, sum(pg_relation_size(indexrelid)) AS bytes_total, pg_size_pretty(sum(pg_relation_size(indexrelid))) AS tamanho_total FROM pg_stat_user_indexes WHERE relname = 'pedidos';" -c "SELECT indexname FROM pg_indexes WHERE tablename = 'pedidos' ORDER BY 1;"; } > "$C11/tamanhos-$1.txt" 2>&1
}

medir_serie() { # $1 = rótulo; 60 s de aquecimento sem gravar + 3 execuções do scripts/medir.sh
  local rot=$1 n d
  verificar_ambiente "$rot" || { echo "AMBIENTE NÃO OK antes da série $rot"; return 1; }
  tamanhos "$rot"
  echo "[$rot] aquecimento de 60 s (não grava resultados) em $(date '+%F %T')"; aquecer
  for n in 1 2 3; do
    scripts/medir.sh "$rot" > "$C11/medir-$rot-$n.log" 2>&1
    d=$(ls -d resultados/*-"$rot" | tail -1)
    echo "[$rot] execução $n: $(basename $d) | $(grep 'Requisições/s' $d/resumo.txt | tr -s ' ') | recursos.csv $(awk -F, 'NR==2{a=$1} END{print a" a "$1}' $d/recursos.csv) | $(grep -E '^arquivos' $d/contexto.txt) | $(grep -c 'Contrato mantido' $d/contrato.txt | sed 's/^/contrato mantido: /') | $(energia)"
  done
}

esperar_banco() { # espera a API e o autovacuum nas 4 tabelas após down -v / up
  local i n
  for i in $(seq 1 90); do curl -sf http://127.0.0.1:3000/saude >/dev/null && break; sleep 3; done
  for i in $(seq 1 55); do n=$(docker compose exec -T banco psql -U loja -d loja -At -c "select count(*) from pg_stat_user_tables where relname in ('clientes','produtos','pedidos','itens_pedido') and last_autovacuum is not null;" 2>/dev/null); [ "$n" = "4" ] && break; sleep 10; done
  echo "API: $(curl -s http://127.0.0.1:3000/saude) | tabelas com autovacuum: $n"
}
