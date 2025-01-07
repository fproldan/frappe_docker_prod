<details><summary>Producción</summary>

## Setup Inicial

#### 1) Completar el archivo `apps.json` y `.env` a conveniencia.

```sh
cp .env.example .env
cp apps.example.json apps.json
```

_Ejemplo del contenido de `apps.json`:_
```
[
  {
    "url": "https://github.com/frappe/wiki",
    "branch": "master"
  },
  {
    "url": "https://<token>@github.com/<usuario>/<repositorio>", // Repo privado
    "branch": "develop"
  }
]
```

#### 2) Construir las imágenes

```sh
docker compose build
```

## Ejecutar contenedores

### Ejecutar el contenedor en primer plano

```sh
docker compose up --remove-orphans --abort-on-container-exit
```

### Ejecutar el contenedor en segundo plano

```sh
docker compose up --remove-orphans -d
```

## Modo desarrollo

#### 1) Ingresar al contenedor de back

```sh
docker compose exec -it server bash
```

#### 2) Poner el sitio en modo desarrollo

```sh
echo "export BENCH_DEVELOPER=1" >> ~/.bashrc \
  && bench --site "$SITE_NAME" set-config developer_mode 1 \
  && bench --site "$SITE_NAME" clear-cache
```

## Manejar instancias

### Detener contenedores

```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .env | cut -d '=' -f2)" \
  && docker kill $(docker ps --format="{{.Names}}" | grep "$prefix") || true
```

### Eliminar instancias de docker levantadas junto a sus volúmenes

```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .env | cut -d '=' -f2)" \
  && # Delete containers:
     docker rm $(docker ps -a --format="{{.Names}}" | grep "$prefix") || true \
  && # Delete volumes:
     docker volume rm $(docker volume ls --format="{{.Name}}" | grep "$prefix") || true
```

</details>

<details><summary>Desarrollo (VSCode)</summary>

## Requisitos

- Instalar la Extensión "Dev Containers" (`ms-vscode-remote.remote-containers`) para VSCode.

## Setup Inicial

Completar el archivo `apps.json` y `.devcontainer/.env` a conveniencia.

```sh
cp .devcontainer/.env.example .devcontainer/.env
cp apps.example.json apps.json
```

_Ejemplo del contenido de `apps.json`:_
```
[
  {
    "url": "https://github.com/frappe/wiki",
    "branch": "master"
  }
]
```

## Ejecutar contenedores

### Primera vez

En la paleta de comandos de VSCode (Ctrl + Shift + P) ejecutar:
```
>Dev Containers: Rebuild and Reopen in Container
```

### Ya creados

En la paleta de comandos de VSCode (Ctrl + Shift + P) ejecutar:
```
>Dev Containers: Reopen in Container
```

## Manejar instancias

### Detener contenedores (VSCode)

En la paleta de comandos de VSCode (Ctrl + Shift + P) ejecutar:
```
>Remote: Close Remote Connection
```

### Detener contenedores (terminal)

```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .devcontainer/.env | cut -d '=' -f2)" \
  && docker kill $(docker ps --format="{{.Names}}" | grep "$prefix") || true
```

### Eliminar instancias de docker levantadas junto a sus volúmenes

```sh
prefix="$(grep -E '^DOCKER_NAME_PREFIX=' .devcontainer/.env | cut -d '=' -f2)" \
  && # Delete containers:
    docker rm $(docker ps -a --format="{{.Names}}" | grep "$prefix") || true \
  && # Delete volumes:
    docker volume rm $(docker volume ls --format="{{.Name}}" | grep "$prefix") || true \
  && # Delete bind mounts:
    (
      cd .devcontainer ;
      awk \
          '/volumes:/ { while (getline > 0) { if ($1 ~ /^-/) { split($2, parts, ":"); if (parts[1] ~ /^\./) { print parts[1] } } else { break } } }' \
          docker-compose.yml \
        | xargs -I {} sudo rm -rf {}
    )
```

</details>
