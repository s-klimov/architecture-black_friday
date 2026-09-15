# Проектная работа: отказоустойчивость «Мобильного мира»

Репозиторий с решением проектной работы по подготовке онлайн-магазина к «чёрной пятнице»:
шардирование, репликация и кеширование MongoDB для приложения pymongo-api.

## Что в репозитории

| Директория / файл | Что внутри |
| --- | --- |
| [mongo-sharding](mongo-sharding) | Задание 2: шардирование (configSrv, 2 шарда, mongos) |
| [mongo-sharding-repl](mongo-sharding-repl) | Задание 3: то же + репликация, у каждого шарда 3 реплики |
| [sharding-repl-cache](sharding-repl-cache) | Задание 4: итоговый стенд — шардирование, репликация и кеш в Redis |
| [diagrams/task1_scheme.drawio](diagrams/task1_scheme.drawio) | Схемы (задания 1, 5, 6), 5 листов, итоговая — лист «5. CDN» |
| [api_app](api_app) | Исходники приложения из PoC |
| [compose.yaml](compose.yaml) | Исходный стенд PoC: приложение и одна нода MongoDB |

**Для проверки используйте директорию `sharding-repl-cache`** — в ней собраны решения заданий 2, 3 и 4.

## Как запустить итоговый стенд

```shell
cd sharding-repl-cache
docker compose up -d
./scripts/init-sharding.sh
./scripts/mongo-init.sh
```

Три шага: поднять сервисы, инициализировать реплика-сеты и шардирование, наполнить базу
1000 документами. Скрипты идемпотентности не требуют — выполняются один раз после `up`.

Приложение будет доступно на http://localhost:8080, документация API — на
http://localhost:8080/docs.

Если проект запускается на виртуальной машине, её белый ip можно узнать так:

```shell
curl --silent http://ifconfig.me
```

Тогда приложение открывается на `http://<ip виртуальной машины>:8080`.

## Состав итогового стенда

| Сервис | Тип | Порт |
| --- | --- | --- |
| configSrv | config server (replSet `config_server`) | 27017 |
| shard1-1, shard1-2, shard1-3 | реплика-сет `shard1` | 27018 |
| shard2-1, shard2-2, shard2-3 | реплика-сет `shard2` | 27019 |
| mongos_router | роутер mongos | 27020 |
| redis | кеш | 6379 |
| pymongo_api | приложение (`kazhem/pymongo_api:1.0.0`) | 8080 |

Наружу проброшены только порты приложения (8080) и роутера (27020).

> Образы в `compose.yaml` указаны через зеркало `dh-mirror.gitverse.ru`, потому что Docker Hub
> недоступен напрямую из сети, где собиралась работа. Образ приложения тот же самый —
> `kazhem/pymongo_api:1.0.0`. Если Docker Hub доступен, префикс `dh-mirror.gitverse.ru/`
> можно убрать.

## Что должно получиться

Статус сервисов:

```shell
docker compose ps
```

Главная страница приложения отдаёт JSON, где видно тип топологии `Sharded`, оба шарда
со всеми тремя репликами каждый, 1000 документов в коллекции `helloDoc` и `"cache_enabled": true`:

```shell
curl -s http://localhost:8080/
```

Количество документов в каждом шарде (в сумме 1000, запрос к любому узлу реплика-сета):

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

Реплики шарда и их роли (1 PRIMARY + 2 SECONDARY):

```shell
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(m => print(m.name, m.stateStr))
EOF
```

Кеширование на эндпоинте `/helloDoc/users`: первый запрос идёт в MongoDB (больше секунды),
повторный отдаётся из Redis быстрее 100 мс:

```shell
curl -s -o /dev/null -w "%{time_total}\n" http://localhost:8080/helloDoc/users
curl -s -o /dev/null -w "%{time_total}\n" http://localhost:8080/helloDoc/users
```

## Как остановить

```shell
docker compose down -v
```

## Схемы

Файл [diagrams/task1_scheme.drawio](diagrams/task1_scheme.drawio) содержит пять листов:

1. **1. Sharding** — шардирование, два шарда (задание 1, шаг 1)
2. **2. Replication** — репликация, у каждого шарда три реплики (задание 1, шаг 2)
3. **3. Caching** — добавлен Redis для кеширования (задание 1, шаг 3)
4. **4. Service Discovery + API Gateway** — несколько инстансов приложения, API Gateway
   для балансировки и кластер Consul для Service Discovery (задание 5)
5. **5. CDN** — итоговая схема: пользователи из разных регионов, узлы CDN и origin
   для статического контента (задание 6)
