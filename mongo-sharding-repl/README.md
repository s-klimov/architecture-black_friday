# mongo-sharding-repl

Шардированный кластер MongoDB с репликацией шардов (1 config server, 2 шарда по 3 реплики,
роутер mongos) и приложение pymongo-api.

## Состав стенда

| Сервис | Тип | Порт |
| --- | --- | --- |
| configSrv | config server (replSet `config_server`) | 27017 |
| shard1-1, shard1-2, shard1-3 | реплика-сет `shard1` | 27018 |
| shard2-1, shard2-2, shard2-3 | реплика-сет `shard2` | 27019 |
| mongos_router | роутер mongos | 27020 |
| pymongo_api | приложение | 8080 |

Наружу проброшены только порты приложения (8080) и роутера (27020), узлы MongoDB
доступны внутри сети docker compose.

## Как запустить

Запускаем кластер и приложение

```shell
docker compose up -d
```

Инициализируем реплика-сеты и шардирование

```shell
./scripts/init-sharding.sh
```

Заполняем бд 1000 документами (через роутер mongos)

```shell
./scripts/mongo-init.sh
```

### Что делают скрипты

`init-sharding.sh` выполняет по шагам:

1. на configSrv — `rs.initiate()` для реплика-сета `config_server`;
2. на shard1-1 — `rs.initiate()` для реплика-сета `shard1` с тремя членами
   (shard1-1, shard1-2, shard1-3);
3. на shard2-1 — `rs.initiate()` для реплика-сета `shard2` с тремя членами
   (shard2-1, shard2-2, shard2-3);
4. ждёт выбора primary в реплика-сетах;
5. на mongos_router — `sh.addShard()` для обоих реплика-сетов,
   `sh.enableSharding("somedb")` и `sh.shardCollection("somedb.helloDoc", { name: "hashed" })`.

`mongo-init.sh` вставляет 1000 документов в коллекцию `helloDoc` базы `somedb`.

## Как проверить

Откройте в браузере http://localhost:8080 — приложение покажет тип топологии
`Sharded`, общее количество документов (1000) и список шардов, где у каждого шарда
перечислены все три реплики.

Документация API (swagger): http://localhost:8080/docs

Количество документов в каждом шарде (запрос к primary каждого реплика-сета):

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Сумма документов по шардам равна 1000.

Состояние репликации шарда (роли и количество узлов):

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name, m.stateStr))
EOF
```

## Как остановить

```shell
docker compose down -v
```
