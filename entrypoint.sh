#!/bin/bash
set -e

source ~/frappe-bench/env/bin/activate

if [[ ! -d ~/frappe-bench/sites/"$SITE_NAME" ]]; then
    # Create new site.
    bench new-site "$SITE_NAME" \
        --db-name "$SITE_NAME" \
        --admin-password "$ADMIN_PASSWORD" \
        --db-password "$DB_PASSWORD" \
        --mariadb-root-password "$DB_ROOT_PASSWORD" \
        --no-mariadb-socket
    bench use "$SITE_NAME"

    # Install apps.
    bench enable-scheduler 
    bench setup requirements
    bench --site "$SITE_NAME" install-app $(jq -r 'keys[]' < sites/apps.json | tr '\n' ' ')
    bench --site "$SITE_NAME" migrate
fi

gunicorn \
    --chdir=/home/frappe/frappe-bench/sites \
    --bind=0.0.0.0:8000 \
    --threads=4 \
    --workers=2 \
    --worker-class=gthread \
    --worker-tmp-dir=/dev/shm \
    --timeout=120 \
    --preload frappe.app:application
