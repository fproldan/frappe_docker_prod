#!/bin/bash
set -e

if [[ ! -d ~/frappe-bench/sites/"$SITE_NAME" ]]; then
    sudo chmod +777 ~/frappe-bench

    # Install bench.
    bench init \
        --frappe-branch="$FRAPPE_BRANCH" \
        --frappe-path=https://github.com/frappe/frappe \
        --apps_path=/opt/apps/apps.json \
        --no-procfile \
        --no-backups \
        --skip-redis-config-generation \
        --ignore-exist \
        --verbose \
        frappe-bench
    cd frappe-bench
    echo "source ~/frappe-bench/env/bin/activate" >> ~/.bashrc
    source ~/.bashrc

    # Config bench.
    bench set-config -g db_host "$DB_HOST"
    bench set-redis-cache-host "$REDIS_CACHE_HOST"
    bench set-redis-queue-host "$REDIS_QUEUE_HOST"
    bench set-redis-socketio-host "$REDIS_SOCKETIO_HOST"

    # Create new site.
    bench new-site "$SITE_NAME" \
        --db-name "$SITE_NAME" \
        --admin-password "$ADMIN_PASSWORD" \
        --db-password "$DB_PASSWORD" \
        --mariadb-root-password "$DB_ROOT_PASSWORD" \
        --no-mariadb-socket
    bench use "$SITE_NAME"

    # Install apps.
    bench setup requirements
    bench --site "$SITE_NAME" install-app $(jq -r 'keys[]' < sites/apps.json | tr '\n' ' ')
    bench --site "$SITE_NAME" migrate

    cp -r ~/.vscode .

    echo "Setup done"
fi

sleep infinity
