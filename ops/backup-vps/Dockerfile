FROM alpine:3.20
RUN apk add --no-cache openssh-client bash tzdata dcron
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/entrypoint.sh
COPY crontab.txt /etc/crontabs/root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
