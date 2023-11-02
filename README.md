## Setup Inicial

```sh
cp .env.example .env
cp apps.example.json apps.json
docker network create "$(grep -E '^DOCKER_NAME_PREFIX=' .env | cut -d '=' -f2)"_"$(grep -E '^DOCKER_DB_NETWORK_NAME=' .env | cut -d '=' -f2)"
docker compose build
```

_Completar el archivo `apps.json` recién generado y editar el archivo `.env` a conveniencia._

Ejemplo del contenido de `apps.json`:
```
[
  {
    "url": "https://github.com/frappe/wiki",
    "branch": "master"
  }
]
```

## Ejecutar contenedor

Hay dos maneras de ejecutar el contenedor.

A) Ejecutar el contenedor en primer plano:
```sh
docker compose up --remove-orphans --abort-on-container-exit
```

B) Ejecutar el contenedor en segundo plano:
```sh
docker compose up --remove-orphans -d
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
  &&
    for APP_DIR in $(
      find apps -maxdepth 1 -mindepth 1 -type d -name "*" -not -name "frappe" -exec basename {} \;
    ); do
      # La sentencia `|| true` es para prevenir el error `cannot copy a directory, <*>, into itself`
      cp -r "apps/$APP_DIR/$APP_DIR/public" "sites/assets/$APP_DIR" || true;
    done
```

## Modo desarrollo

1) Ingresar al contenedor de back:
```sh
docker compose exec -it backend bash
```

2) Poner un sitio en modo desarrollo:
```sh
# Nombre del sitio: frappe
# ⚠️ Igualmente se define una variable de entorno que afecta a todos los sitios.
site_name=frappe \
  echo "export BENCH_DEVELOPER=1" >> ~/.bashrc \
  bench --site "$site_name" set-config developer_mode 1 && \
  bench --site "$site_name" clear-cache
```

## Manejar instancias

Detener contenedores:
```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .env | cut -d '=' -f2)" \
  && docker kill $(docker ps --format="{{.Names}}" | grep "$prefix")
```

Eliminar instancias de docker levantadas, junto a sus volúmenes y networks:
```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .env | cut -d '=' -f2)" \
  && docker rm $(docker ps -a --format="{{.Names}}" | grep "$prefix") \
  && docker volume rm $(docker volume ls --format="{{.Name}}" | grep "$prefix") \
  && docker network rm $(docker network ls --format="{{.Name}}" | grep "$prefix")
```
