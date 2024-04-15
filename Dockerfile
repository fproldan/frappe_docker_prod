FROM python:3.11.4-slim-bookworm AS base

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install --no-install-recommends -y \
        # To work inside the container:
        sudo \
        nano \
        vim \
        curl \
        jq \
        less \
        bash-completion \
        # For frappe framework:
        git \
        mariadb-client \
        gettext-base \
        wget \
        # Wkhtmltopdf dependencies:
        xfonts-75dpi \
        xfonts-base \
        # Weasyprint dependencies:
        libpango-1.0-0 \
        libharfbuzz0b \
        libpangoft2-1.0-0 \
        libpangocairo-1.0-0 \
        # Pandas dependencies:
        libbz2-dev \
        gcc \
        build-essential \
        # Other:
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

# Create the user.
RUN groupadd -g 1000 frappe \
    && useradd --no-log-init -r -m -u 1000 -g 1000 -G sudo frappe \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER frappe
WORKDIR /home/frappe

ARG SITE_NAME

# Install Node.js.
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

# Install wkhtmltopdf.
ENV WKHTMLTOPDF_VERSION 0.12.6.1-3
RUN if [ "$(uname -m)" = "aarch64" ]; then export ARCH=arm64; fi \
    && if [ "$(uname -m)" = "x86_64" ]; then export ARCH=amd64; fi \
    && downloaded_file=wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_${ARCH}.deb \
    && wget "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/$downloaded_file" \
    && sudo dpkg -i "$downloaded_file" \
    && rm "$downloaded_file"

# Install bench.
ENV PATH /home/frappe/.local/bin:$PATH
RUN git clone --depth 1 -b v5.x https://github.com/frappe/bench.git .bench \
    && pip install --no-cache-dir --user -e .bench \
    && echo "export PATH=/home/frappe/.local/bin:\$PATH" >> ~/.bashrc

# Setup bench and initial apps.
COPY local-apps /opt/apps
COPY apps.json /opt/apps/apps.json
RUN bench init \
        --frappe-branch=${FRAPPE_BRANCH} \
        --frappe-path=https://github.com/frappe/frappe \
        --apps_path=/opt/apps/apps.json \
        --no-procfile \
        --no-backups \
        --skip-redis-config-generation \
        --verbose \
        ~/frappe-bench \
    && echo "source ~/frappe-bench/env/bin/activate" >> ~/.bashrc

WORKDIR /home/frappe/frappe-bench

ARG DB_HOST
ARG REDIS_CACHE_HOST
ARG REDIS_QUEUE_HOST
ARG REDIS_SOCKETIO_HOST
RUN bench set-config -g db_host ${DB_HOST} \
    && bench set-redis-cache-host ${REDIS_CACHE_HOST} \
    && bench set-redis-queue-host ${REDIS_QUEUE_HOST} \
    && bench set-redis-socketio-host ${REDIS_SOCKETIO_HOST}

FROM base AS reverse_proxy

# Install NGINX.
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

RUN sudo bash -c "sed -i 's/\$SITE_NAME/${SITE_NAME}/g' /usr/local/bin/nginx-entrypoint.sh"
CMD [\
    "sudo", \
    "bash", \
    "/usr/local/bin/nginx-entrypoint.sh" \
]

FROM base AS server

COPY entrypoint.sh entrypoint.sh
RUN sudo chmod +x entrypoint.sh
ENTRYPOINT "/home/frappe/frappe-bench/entrypoint.sh"

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
