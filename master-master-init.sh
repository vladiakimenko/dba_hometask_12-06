#!/bin/bash
set -e

wait_for_healthy() {
  local container=$1
  local retries=30
  local wait=2

  echo "[INFO] Waiting for $container to be ready..."
  for i in $(seq 1 $retries); do
    if docker exec "$container" sh -c "mysql -uroot -p\$MYSQL_ROOT_PASSWORD -e 'SELECT 1;' " &>/dev/null; then
      echo "[INFO] $container is ready."
      return 0
    fi
    echo -n "."
    sleep $wait
  done

  echo "[ERROR] $container did not come ready!"
  exit 1
}

echo "[INFO] Cleaning previous deploys..."
docker compose down -v
rm -rf dbdata*
docker rm -f mysql-master-1 mysql-master-2 2>/dev/null || true
docker network rm mysql-net 2>/dev/null || true
rm -rf ./mysql-data-1 ./mysql-data-2

echo "[INFO] Starting containers..."
docker network create mysql-net
docker run -d \
  --name mysql-master-1 \
  --net mysql-net \
  -e MYSQL_ROOT_PASSWORD=StrongPassword12345 \
  -e MYSQL_DATABASE=testdb \
  -v ./mysql-data-1:/var/lib/mysql \
  mysql:8.0.32 --server-id=1 --log-bin=mysql-bin --binlog-format=ROW --gtid-mode=ON --enforce-gtid-consistency=ON --master-info-repository=TABLE --relay-log-info-repository=TABLE --read-only=0

docker run -d \
  --name mysql-master-2 \
  --net mysql-net \
  -e MYSQL_ROOT_PASSWORD=StrongPassword12345 \
  -e MYSQL_DATABASE=testdb \
  -v ./mysql-data-2:/var/lib/mysql \
  mysql:8.0.32 --server-id=2 --log-bin=mysql-bin --binlog-format=ROW --gtid-mode=ON --enforce-gtid-consistency=ON --master-info-repository=TABLE --relay-log-info-repository=TABLE --read-only=0

wait_for_healthy mysql-master-1
wait_for_healthy mysql-master-2

echo "[INFO] Creating replication user on both masters..."
for master in mysql-master-1 mysql-master-2; do
  docker exec -i $master mysql -uroot -pStrongPassword12345 -e "
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'ReplicationPass123!';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
"
done

echo "[INFO] Configuring master-master replication..."
docker exec -i mysql-master-1 mysql -uroot -pStrongPassword12345 -e "
CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysql-master-2', SOURCE_USER='repl', SOURCE_PASSWORD='ReplicationPass123!', SOURCE_AUTO_POSITION=1;
START REPLICA;
SHOW REPLICA STATUS\G;
"
docker exec -i mysql-master-2 mysql -uroot -pStrongPassword12345 -e "
CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysql-master-1', SOURCE_USER='repl', SOURCE_PASSWORD='ReplicationPass123!', SOURCE_AUTO_POSITION=1;
START REPLICA;
SHOW REPLICA STATUS\G;
"

echo "[INFO] Done."