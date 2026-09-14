# mongo-sharding

Шардированный кластер MongoDB (1 config server, 2 шарда, роутер mongos) и приложение pymongo-api.

## Состав стенда

| Сервис | Тип | Порт |
| --- | --- | --- |
| configSrv | config server (replSet `config_server`) | 27017 |
| shard1 | шард (replSet `shard1`) | 27018 |
| shard2 | шард (replSet `shard2`) | 27019 |
| mongos_router | роутер mongos | 27020 |
| pymongo_api | приложение | 8080 |

## Как запустить

Запускаем кластер и приложение

```shell
docker compose up -d
```

Инициализируем шардирование: реплика-сеты config server и шардов, добавление шардов
в кластер, включение шардирования для `somedb.helloDoc` по хешированному ключу `name`

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
2. на shard1 и shard2 — `rs.initiate()` для реплика-сетов `shard1` и `shard2`;
3. на mongos_router — `sh.addShard()` для обоих шардов, `sh.enableSharding("somedb")`
   и `sh.shardCollection("somedb.helloDoc", { name: "hashed" })`.

`mongo-init.sh` вставляет 1000 документов в коллекцию `helloDoc` базы `somedb`.

## Как проверить

Откройте в браузере http://localhost:8080 — приложение покажет тип топологии
`Sharded`, список шардов и общее количество документов (1000).

Документация API (swagger): http://localhost:8080/docs

Количество документов в каждом шарде:

```shell
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

```shell
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

Сумма документов по шардам равна 1000.

## Как остановить

```shell
docker compose down -v
```
