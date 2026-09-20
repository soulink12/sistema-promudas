FROM alpine:3.20
# tini como PID 1 de verdade — dcron tenta setpgid() nos jobs, o que falha
# ("setpgid: Operation not permitted") quando ELE MESMO é o PID 1 do
# container. Com tini na frente, o cron roda como processo filho normal.
RUN apk add --no-cache openssh-client bash tzdata dcron tini
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/entrypoint.sh
COPY crontab.txt /etc/crontabs/root
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
