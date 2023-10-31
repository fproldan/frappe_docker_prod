## Setup Inicial

```sh
cp .env.example .env
docker network create "$(grep -E '^DOCKER_DB_NETWORK_NAME=' .env | cut -d '=' -f2)"
docker compose build
```

## Ejecutar contenedor

```sh
docker compose up --remove-orphans --abort-on-container-exit
```

## Crear Sitio

1) Ingresar al contenedor de back:
```sh
docker compose exec -it backend bash
```

2) Crear el sitio:
```sh
# Nombre del sitio: frappe
site_name=frappe \
  && bench new-site "$site_name" \
    --db-name "$site_name" \
    --admin-password $ADMIN_PASSWORD \
    --db-password $DB_PASSWORD \
    --mariadb-root-password $DB_ROOT_PASSWORD \
    --no-mariadb-socket \
  && bench use "$site_name" \
  && bench setup requirements \
  && bench --site "$site_name" install-app $(cat sites/apps.json | jq -r 'keys[]' | tr '\n' ' ') \
  && bench --site "$site_name" migrate \
  && for APP_DIR in $(find apps -maxdepth 1 -mindepth 1 -type d -name "*" -not -name "frappe" -exec basename {} \;); do cp -r "apps/$APP_DIR/$APP_DIR/public" "sites/assets/$APP_DIR"; done

# TEMPORAL, sólo para desarrollo
# (docker kill $(docker ps -q) || true) && yes | docker system prune -a && yes | docker volume prune -a && docker network create "$(grep -E '^DOCKER_DB_NETWORK_NAME=' .env | cut -d '=' -f2)" && docker compose build && docker compose up --remove-orphans --abort-on-container-exit
bench set-config developer_mode true
```

## Ingresar

http://localhost:8000
