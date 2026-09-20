#!/bin/bash
set -euo pipefail

DEST_DIR="/backups"
DATA=$(date +%Y%m%d_%H%M%S)
ARQUIVO="$DEST_DIR/sistema_mudas_${DATA}.sql.gz"

ssh -i /run/secrets/ssh_key \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=15 \
    "${VPS_USER}@${VPS_HOST}" \
    "docker exec ${CONTAINER_MYSQL} sh -c 'export MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\"; mysqldump -u root --single-transaction --routines --triggers \"\$MYSQL_DATABASE\"'" \
    | gzip > "$ARQUIVO"

TAMANHO=$(du -h "$ARQUIVO" | cut -f1)
echo "[$(date '+%F %T')] Backup concluído: $ARQUIVO ($TAMANHO)"

# Retenção: apaga backups mais velhos que N dias (padrão 14)
find "$DEST_DIR" -name 'sistema_mudas_*.sql.gz' -mtime "+${RETENCAO_DIAS:-14}" -delete
