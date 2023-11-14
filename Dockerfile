FROM python:3.11.4-slim-bookworm AS base

# DONE
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install --no-install-recommends -y \
        # To work inside the container.
        sudo \
        nano \
        vim \
        curl \
        jq \
        less \
        bash-completion \

        # For frappe framework.
        git \
        mariadb-client \
        gettext-base \
        wget \

        # Wkhtmltopdf dependencies.
        xfonts-75dpi \
        xfonts-base \

        # Weasyprint dependencies.
        libpango-1.0-0 \
        libharfbuzz0b \
        libpangoft2-1.0-0 \
        libpangocairo-1.0-0 \

        # Pandas dependencies.
        libbz2-dev \
        gcc \
        build-essential \

        # Other.
        libffi-dev \
        liblcms2-dev \
        libldap2-dev \
        libmariadb-dev \
        libsasl2-dev \
        libtiff5-dev \
        libwebp-dev \
        redis-tools \
        rlwrap \
        tk8.6-dev \
        cron \

        && rm -rf /var/lib/apt/lists/*

# Creamos un usuario.
RUN groupadd -g 1000 frappe \
    && useradd --no-log-init -r -m -u 1000 -g 1000 -G sudo frappe \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER frappe
WORKDIR /home/frappe

# Instalamos Node.js.
ENV NODE_VERSION 18.18.1
ENV NVM_DIR /home/frappe/.nvm
ENV PATH ${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:$PATH
RUN wget -O- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash \
    && . ${NVM_DIR}/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm use v${NODE_VERSION} \
    && npm install -g yarn \
    && nvm alias default v${NODE_VERSION} \
    && rm -rf ${NVM_DIR}/.cache \
    && echo 'export NVM_DIR="${NVM_DIR}"' >> ~/.bashrc \
    && echo "export PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:\$PATH" >> ~/.bashrc \
    && echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> ~/.bashrc \
    && echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> ~/.bashrc

# Instalamos wkhtmltopdf.
ENV WKHTMLTOPDF_VERSION 0.12.6.1-3
RUN if [ "$(uname -m)" = "aarch64" ]; then export ARCH=arm64; fi \
    && if [ "$(uname -m)" = "x86_64" ]; then export ARCH=amd64; fi \
    && downloaded_file=wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_${ARCH}.deb \
    && wget "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/$downloaded_file" \
    && sudo dpkg -i "$downloaded_file" \
    && rm "$downloaded_file"

# Instalamos bench.
ENV PATH /home/frappe/.local/bin:$PATH
RUN git clone --depth 1 -b v5.x https://github.com/frappe/bench.git .bench \
    && pip install --no-cache-dir --user -e .bench \
    && echo "export PATH=/home/frappe/.local/bin:\$PATH" >> ~/.bashrc

# Iniciamos bench e instalamos frappe.
ARG FRAPPE_BRANCH
COPY apps.json /opt/frappe/apps.json
RUN bench init \
        --frappe-branch=${FRAPPE_BRANCH} \
        --frappe-path=https://github.com/frappe/frappe \
        --apps_path=/opt/frappe/apps.json \
        --no-procfile \
        --no-backups \
        --skip-redis-config-generation \
        --verbose \
        ~/frappe-bench \
    && echo "source ~/frappe-bench/env/bin/activate" >> ~/.bashrc

WORKDIR /home/frappe/frappe-bench

ARG DOCKER_DB_SERVICE_NAME
ARG DOCKER_REDIS_CACHE_SERVICE_NAME
ARG DOCKER_REDIS_QUEUE_SERVICE_NAME
ARG DOCKER_REDIS_SOCKETIO_SERVICE_NAME
RUN bench set-config -g db_host ${DOCKER_DB_SERVICE_NAME} \
    && bench set-redis-cache-host ${DOCKER_REDIS_CACHE_SERVICE_NAME}:6379 \
    && bench set-redis-queue-host ${DOCKER_REDIS_QUEUE_SERVICE_NAME}:6379 \
    && bench set-redis-socketio-host ${DOCKER_REDIS_SOCKETIO_SERVICE_NAME}:6379

FROM base AS frontend

# Instalamos NGINX.
RUN DEBIAN_FRONTEND=noninteractive \
    && sudo apt-get update \
    && sudo apt-get install --no-install-recommends -y nginx \
    && sudo chown -R frappe /var/lib/nginx \
    && sudo ln -sf /dev/stdout /var/log/nginx/access.log \
    && sudo ln -sf /dev/stderr /var/log/nginx/error.log \
    && sudo chown -R frappe /var/log/nginx \
    && sudo chown -R frappe /etc/nginx \
    && rm -rf /etc/nginx/sites-enabled/default \
    && sed -i '/user www-data/d' /etc/nginx/nginx.conf \
    && sudo touch /run/nginx.pid \
    && sudo chown -R frappe /run/nginx.pid
COPY resources/nginx-template.conf /templates/nginx/frappe.conf.template
COPY resources/nginx-entrypoint.sh /usr/local/bin/nginx-entrypoint.sh

ARG SITE_NAME
RUN sudo bash -c "sed -i 's/\$SITE_NAME/${SITE_NAME}/g' /usr/local/bin/nginx-entrypoint.sh"
CMD [\
    "sudo", \
    "bash", \
    "/usr/local/bin/nginx-entrypoint.sh" \
]

FROM base AS backend

CMD [\
    "bash", \
    "-c", \
    "source ~/frappe-bench/env/bin/activate && gunicorn --chdir=/home/frappe/frappe-bench/sites --bind=0.0.0.0:8000 --threads=4 --workers=2 --worker-class=gthread --worker-tmp-dir=/dev/shm --timeout=120 --preload frappe.app:application" \
]

FROM base AS websocket
CMD [\
    "node", \
    "apps/frappe/socketio.js" \
]

FROM base AS scheduler
CMD [\
    "bench", \
    "schedule" \
]

FROM base AS queue-default
CMD [\
    "bench", \
    "worker", \
    "--queue", \
    "default" \
]

FROM base AS queue-short
CMD [\
    "bench", \
    "worker", \
    "--queue", \
    "short" \
]

FROM base AS queue-long
CMD [\
    "bench", \
    "worker", \
    "--queue", \
    "long" \
]
