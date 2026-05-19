# Penpot local Docker install

This folder contains Penpot's official Docker Compose setup, downloaded from:

https://raw.githubusercontent.com/penpot/penpot/main/docker/images/docker-compose.yaml

The project is isolated under the Docker Compose project name `penpot`, with persistent data in Docker volumes.

## Start

```sh
cd /Users/Anthony.Madrazo2/Documents/Projects/research/focus/penpot
docker compose -p penpot -f docker-compose.yaml up -d
```

Penpot will listen at:

http://localhost:9001

Mailcatcher for local email testing will listen at:

http://localhost:1080

## Stop

```sh
cd /Users/Anthony.Madrazo2/Documents/Projects/research/focus/penpot
docker compose -p penpot -f docker-compose.yaml down
```

## Update images

```sh
cd /Users/Anthony.Madrazo2/Documents/Projects/research/focus/penpot
docker compose -p penpot -f docker-compose.yaml pull
docker compose -p penpot -f docker-compose.yaml up -d
```

## Version pinning

The `.env` file pins `PENPOT_VERSION=2.15`, matching the current default in the official compose file at the time this folder was created. Change that value when you intentionally upgrade Penpot.

## Notes

- This local setup keeps Penpot's default local-development flags, including disabled email verification and insecure session cookies for `localhost`.
- Do not expose this compose stack directly to the internet without reviewing the Penpot HTTPS/proxy and security guidance.
- The `PENPOT_SECRET_KEY` in `.env` is generated for this local instance. Keep it stable after first start so existing sessions and encrypted values remain readable.
