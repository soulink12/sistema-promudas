#!/bin/bash
set -euo pipefail

# cron não herda as env vars do container — grava o ambiente atual num
# arquivo que o job do crontab carrega antes de rodar o backup.sh.
printenv | sed -E "s/^([A-Z_][A-Z0-9_]*)=(.*)$/export \1='\2'/" > /etc/backup_env

exec crond -f -l 2
