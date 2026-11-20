#!/bin/sh
# Exécuté par l'image postgres au premier démarrage seulement (volume vide).
# Pour le rejouer : docker compose down -v && docker compose up
#
# Chaque service reçoit un rôle `<schéma>_svc`, propriétaire de son seul schéma :
# il peut y créer ses tables (migrations) mais ne voit pas les schémas des autres.
set -eu

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
-- Personne ne travaille dans `public` : chaque service a son schéma.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
SQL

create_schema() {
  schema="$1"
  password="$2"
  echo "Création du schéma $schema et du rôle ${schema}_svc"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -v schema="$schema" -v role="${schema}_svc" -v password="$password" -v db="$POSTGRES_DB" <<'SQL'
CREATE ROLE :"role" LOGIN PASSWORD :'password';
CREATE SCHEMA :"schema" AUTHORIZATION :"role";
ALTER ROLE :"role" SET search_path = :"schema";
GRANT CONNECT ON DATABASE :"db" TO :"role";
SQL
}

create_schema identity "${IDENTITY_DB_PASSWORD:?}"
create_schema ingestion "${INGESTION_DB_PASSWORD:?}"
create_schema detection "${DETECTION_DB_PASSWORD:?}"
create_schema clip "${CLIP_DB_PASSWORD:?}"
create_schema jobs "${JOBS_DB_PASSWORD:?}"
