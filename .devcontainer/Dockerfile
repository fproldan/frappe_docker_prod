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
    && useradd \
        --no-log-init \
        --system \
        --create-home \
        --shell /bin/bash \
        --uid 1000 \
        --gid 1000 \
        --groups sudo \
        frappe \
    && echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER frappe
WORKDIR /home/frappe

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

COPY local-apps /opt/apps
COPY apps.json /opt/apps/apps.json

RUN echo "export BENCH_DEVELOPER=1" >> ~/.bashrc \
    && echo "export DEV_SERVER=1" >> ~/.bashrc \
    && echo "source ~/frappe-bench/env/bin/activate" >> ~/.bashrc

FROM base AS editor

# Required for VSCode.
RUN DEBIAN_FRONTEND=noninteractive \
    sudo apt-get update \
    && sudo apt-get install --no-install-recommends -y net-tools

CMD ["sleep", "infinity"]

FROM base AS setup

COPY .devcontainer/.vscode .vscode
COPY .devcontainer/entrypoint.sh entrypoint.sh
RUN sudo chmod +x entrypoint.sh
ENTRYPOINT "/home/frappe/entrypoint.sh"

FROM base AS websocket
WORKDIR /home/frappe/frappe-bench
CMD [\
    "bash", \
    "-c", \
    "cd ~/frappe-bench && node apps/frappe/socketio.js" \
]

FROM base AS scheduler
WORKDIR /home/frappe/frappe-bench
CMD [\
    "bash", \
    "-c", \
    "cd ~/frappe-bench && bench schedule" \
]
