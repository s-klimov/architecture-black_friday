#!/bin/bash
set -e

###
# Инициализируем шардированный кластер MongoDB
###

echo "1. Инициализируем config server"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<'JS'
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
JS

echo "2. Инициализируем шарды"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<'JS'
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1:27018" }]
})
JS

docker compose exec -T shard2 mongosh --port 27019 --quiet <<'JS'
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2:27019" }]
})
JS

echo "Ждём, пока реплика-сеты выберут primary"
sleep 15

echo "3. Добавляем шарды в кластер и включаем шардирование коллекции"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'JS'
sh.addShard("shard1/shard1:27018")
sh.addShard("shard2/shard2:27019")
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { name: "hashed" })
JS

echo "Шардирование настроено"
