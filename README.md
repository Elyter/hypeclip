# Hypeclip

Hypeclip crée automatiquement des clips Twitch quand le chat d'un stream s'enflamme, et les diffuse en direct dans un fil.

Projet du module WebService (Ynov).

## Équipe

| Membre | Rôle | Périmètre |
| --- | --- | --- |
| William | Référent technique | `ingestion-service`, `detection-service`, `packages/contracts`, `packages/redis-keys` |
| César | Product Owner, Référent UX/UI | `front`, temps réel de la gateway |
| Raph | Scrum Master | `clip-service`, `job-runner`, `packages/twitch` |
| Eliott | Référent DevSecOps | `gateway` (auth, rôles, Swagger), CI/CD, infrastructure |

## Architecture

Une gateway NestJS, trois micro-services (`ingestion-service`, `detection-service`, `clip-service`), un job-runner BullMQ et un front React. Les services communiquent par NATS et partagent leur état dans Redis ; les données sont dans Postgres.

Le détail est dans [`docs/`](docs/).

## Contribuer

- Branches : `main` (évaluée), `develop` (intégration), une branche par user story (`feat/us7-clip-create`).
- Commits au format [conventional commits](https://www.conventionalcommits.org/fr/) : `feat(clip): create clip from moment`.
- Tout passe par une pull request relue par une autre personne, sans squash.
