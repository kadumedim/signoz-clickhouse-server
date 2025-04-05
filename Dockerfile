FROM clickhouse/clickhouse-server:24.1.2-alpine

RUN apk add --no-cache gettext

# Copy configuration files
COPY config.xml /etc/clickhouse-server/config.xml
COPY users.xml /etc/clickhouse-server/users.xml
COPY custom-function.xml /etc/clickhouse-server/custom-function.xml
COPY cluster.xml /etc/clickhouse-server/config.d/cluster.xml.template

# Create directories
RUN mkdir -p /var/lib/clickhouse/user_scripts/ \
    && chown -R clickhouse:clickhouse /var/lib/clickhouse/

# Copy the histogram quantile binary
RUN wget -O /tmp/histogram-quantile.tar.gz "https://github.com/SigNoz/signoz/releases/download/histogram-quantile%2Fv0.0.1/histogram-quantile_linux_amd64.tar.gz" \
    && tar -xvzf /tmp/histogram-quantile.tar.gz -C /tmp \
    && mv /tmp/histogram-quantile /var/lib/clickhouse/user_scripts/histogramQuantile \
    && chmod +x /var/lib/clickhouse/user_scripts/histogramQuantile \
    && chown clickhouse:clickhouse /var/lib/clickhouse/user_scripts/histogramQuantile

# Create startup script that will substitute environment variables
RUN echo '#!/bin/sh \n\
envsubst < /etc/clickhouse-server/config.d/cluster.xml.template > /etc/clickhouse-server/config.d/cluster.xml \n\
exec /entrypoint.sh "$@"' > /docker-entrypoint-custom.sh && \
chmod +x /docker-entrypoint-custom.sh

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget --spider -q 0.0.0.0:8123/ping

# Expose ports
EXPOSE 8123 9000 9009

ENTRYPOINT ["/docker-entrypoint-custom.sh"]
CMD ["clickhouse", "server"]