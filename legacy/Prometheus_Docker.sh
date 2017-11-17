#!/bin/bash

sudo cp /home/asu/collectd.conf /etc/collectd/

sudo /etc/init.d/collectd restart

docker pull prom/prometheus:latest

docker pull prom/collectd-exporter:latest

docker pull prom/snmp-exporter:latest

docker pull timescale/pg_prometheus:master

docker pull timescale/prometheus-postgresql-adapter:master

docker pull portainer/portainer:latest

docker volume create prometheus_data

docker volume create postgres_data

docker volume create portainer_data

#if docker network ls --filter "name=br0" --quiet
#then
#echo "Network already exists, skipping"
#else
docker network create \
--driver=bridge \
--subnet=172.18.0.0/16 \
--ip-range=172.18.1.0/24 \
--gateway=172.18.1.1 \
--opt com.docker.network.bridge.enable_icc=true \
br0
echo "Creating network 'br0'"
#fi

if docker exec -d prometheus_postgres stat /etc/passwd
then
echo "Container already exists, skipping"
else
docker run -itd -e "TZ=Europe/Moscow" \
--name prometheus_postgres \
--network br0 \
--ip=172.18.1.5 \
--publish 5432:5432 \
--memory="4G" \
--restart on-failure:5 \
--health-cmd='stat /etc/passwd || exit 1' \
--health-interval=1m \
--mount source=postgres_data,target=/var/lib/postgresql/data \
timescale/pg_prometheus:master \
-csynchronous_commit=off
echo "Starting container 'prometheus_postgres'"
fi

if docker exec -d prometheus_adapter stat /etc/passwd
then
echo "Container already exists, skipping"
else
docker run -itd \
--name prometheus_adapter \
--network br0 \
--ip=172.18.1.6 \
--expose 9201 \
--memory="64M" \
--restart on-failure:5 \
--health-cmd='stat /etc/passwd || exit 1' \
--health-interval=1m \
timescale/prometheus-postgresql-adapter \
-pg-host=prometheus_postgres \
-pg-prometheus-log-samples \
-pg-use-timescaledb=false
echo "Starting container 'prometheus-adapter'"
fi

if docker exec -d prometheus stat /etc/passwd
then
echo "Container already exists, skipping"
else
docker run -itd \
--name prometheus \
--network br0 \
--ip=172.18.1.2 \
--publish 9090:9090/tcp \
--memory="512M" \
--restart on-failure:5 \
--health-cmd='stat /etc/passwd || exit 1' \
--health-interval=1m \
--mount source=prometheus_data,target=/prometheus \
prom/prometheus \
-storage.local.retention=62d \
-storage.local.series-file-shrink-ratio=0.3

docker cp /home/asu/prometheus.yml prometheus:/etc/prometheus/
docker cp /home/asu/M1.rules prometheus:/etc/prometheus/
docker cp /home/asu/M2.rules prometheus:/etc/prometheus/
docker cp /home/asu/M3.rules prometheus:/etc/prometheus/

docker container restart prometheus

echo "Starting container 'prometheus'"
fi

if docker exec -d prometheus_collectd stat /etc/passwd
then
echo "Container already exists, skipping"
else
docker run -itd \
--name prometheus_collectd \
--network br0 \
--ip=172.18.1.3 \
--publish 9103:9103 \
--publish 25826:25826/udp \
--memory="64M" \
--restart on-failure:5 \
--health-cmd='stat /etc/passwd || exit 1' \
--health-interval=1m \
prom/collectd-exporter \
--collectd.listen-address=":25826"
echo "Starting container 'prometheus_collectd'"
fi

if docker exec -d prometheus_snmp stat /etc/passwd
then
echo "Container already exists, skipping"
else
docker run -itd \
--name prometheus_snmp \
--network br0 \
--ip=172.18.1.4 \
--publish 9116:9116 \
--memory="64M" \
--restart on-failure:5 \
--health-cmd='stat /etc/passwd || exit 1' \
--health-interval=1m \
prom/snmp-exporter:latest
echo "Starting container 'prometheus_snmp'"
fi

#if docker exec -d portainer stat /etc/passwd || exit 1
#then
#echo "Container already exists, skipping"
#else
docker run -itd \
--name portainer \
--publish 9000:9000 \
--memory="64M" \
--restart on-failure:5 \
--volume /var/run/docker.sock:/var/run/docker.sock \
--mount source=portainer_data,target=/data \
portainer/portainer
echo "Starting container 'portainer'"
#fi

echo "Done!"
exit 0
