# Installation et lancement

## Prérequis

- Docker avec Compose v2 (`docker compose version`)

## Démarrer l'environnement local

```sh
cp .env.example .env
docker compose up -d --wait
```

`--wait` rend la main quand tous les conteneurs sont sains. Au premier lancement, Postgres exécute `infra/postgres/init/` (schémas et rôles).

Avec le monitoring :

```sh
docker compose --profile demo up -d --wait
```

## Services

Tous les ports sont liés à `127.0.0.1` et se changent dans `.env`.

| Service | Image | Adresse depuis la machine | Adresse entre conteneurs | Rôle |
| --- | --- | --- | --- | --- |
| Postgres | `postgres:18-alpine` | `localhost:5432` | `postgres:5432` | Données des services, un schéma par service |
| Redis | `redis:8.8-alpine` | `localhost:6379` | `redis:6379` | État partagé, queues BullMQ (mot de passe obligatoire) |
| NATS | `nats:2.15-alpine` | `localhost:4222` | `nats:4222` | Messages entre services, JetStream activé |
| NATS monitoring | | http://localhost:8222 | `nats:8222` | `/healthz`, `/varz`, `/jsz` |
| Mailpit | `axllent/mailpit:v1.34` | SMTP `localhost:1025`, interface http://localhost:8025 | `mailpit:1025` | Capture les mails envoyés en local |
| Prometheus | `prom/prometheus:v3.16.0` | http://localhost:9090 | `prometheus:9090` | Profil `demo` |
| Grafana | `grafana/grafana:13.3` | http://localhost:3001 | `grafana:3000` | Profil `demo`, identifiants dans `.env` |

## Profils

| Commande | Ce qui démarre |
| --- | --- |
| `docker compose up` | L'infrastructure : Postgres, Redis, NATS, Mailpit |
| `docker compose --profile dev up` | L'infrastructure, puis les services applicatifs avec un réplica chacun |
| `docker compose --profile demo up` | Comme `dev`, avec plusieurs réplicas par service, Prometheus et Grafana |

Tant que les apps n'existent pas (T1), `dev` revient au lancement sans profil.

### Ajouter un service applicatif

Chaque app rejoint les deux profils et lit son nombre de réplicas dans une variable. Elle attend que l'infrastructure soit saine :

```yaml
user-service:
  build: { context: ., args: { APP: user-service } }
  profiles: [dev, demo]
  deploy:
    replicas: ${USER_SERVICE_REPLICAS:-1}
  env_file: .env
  depends_on:
    postgres: { condition: service_healthy }
    nats: { condition: service_healthy }
```

Un service répliqué ne publie pas de port fixe sur la machine, sinon les réplicas se disputent le port. Seule la gateway est exposée.

## Postgres : un schéma par service

Le script `infra/postgres/init/01-schemas.sh` crée un schéma par service, ainsi qu'un rôle `<schéma>_svc` qui en est propriétaire :

| Schéma | Rôle | Service |
| --- | --- | --- |
| `identity` | `identity_svc` | `user-service` |
| `ingestion` | `ingestion_svc` | `ingestion-service` |
| `detection` | `detection_svc` | `detection-service` |
| `clip` | `clip_svc` | `clip-service` |
| `jobs` | `jobs_svc` | `job-runner` |

Un rôle crée ses tables (migrations) dans son schéma, qui est aussi son `search_path`. Les autres schémas lui sont interdits, `public` compris. Chaque service se connecte donc avec son propre rôle, jamais avec le superutilisateur :

```
postgresql://identity_svc:${IDENTITY_DB_PASSWORD}@postgres:5432/hypeclip
```

Pour ajouter un schéma : une ligne `create_schema` dans le script, une variable `<SCHÉMA>_DB_PASSWORD` dans `.env.example` et `docker-compose.yml`, puis une réinitialisation.

## Commandes utiles

```sh
docker compose ps                           # état et santé des conteneurs
docker compose logs -f postgres             # logs d'un service
docker compose exec postgres psql -U hypeclip -d hypeclip
docker compose exec redis redis-cli -a redis-dev --no-auth-warning
docker compose --profile demo down          # arrêter en gardant les données
docker compose --profile demo down -v       # tout supprimer, l'init sera rejouée au prochain lancement
```

## Problèmes fréquents

- **Un port est déjà pris** : changer la variable `*_PORT` correspondante dans `.env`.
- **Le script d'init ne s'exécute pas** : il ne tourne que sur un volume vide. Après une modification, lancer `docker compose down -v`.
- **`required variable ... is missing`** : le fichier `.env` manque ou est incomplet. Le recopier depuis `.env.example`.
