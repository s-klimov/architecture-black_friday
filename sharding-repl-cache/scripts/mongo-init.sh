#!/bin/bash
set -e

###
# Заполняем бд через роутер mongos
###

docker compose exec -T mongos_router mongosh --port 27020 --quiet <<'JS'
use somedb
for (var i = 0; i < 1000; i++) db.helloDoc.insertOne({ age: i, name: "ly" + i })
db.helloDoc.countDocuments()
JS
