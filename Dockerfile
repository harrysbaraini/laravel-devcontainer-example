ARG BASE_IMAGE=ubuntu:22.04

ARG NODE_VERSION='14'
FROM node:${NODE_VERSION}-slim AS node

# build final image
FROM ${BASE_IMAGE}
LABEL maintainer="Vanderlei Amancio (hello@vanderleis.me)"

ARG PHP_VERSION="8.2"

ENV DEBIAN_FRONTEND="noninteractive" \
    TZ=UTC \
    PHP_DATE_TIMEZONE="UTC" \
    PHP_DISPLAY_ERRORS=Off \
    PHP_DISPLAY_STARTUP_ERRORS=Off \
    PHP_ERROR_REPORTING="22527" \
    PHP_MEMORY_LIMIT="256M" \
    PHP_MAX_EXECUTION_TIME="99" \
    PHP_OPEN_BASEDIR="$WEBUSER_HOME:/dev/stdout:/tmp" \
    PHP_POST_MAX_SIZE="100M" \
    PHP_UPLOAD_MAX_FILE_SIZE="100M" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    COMPOSER_MAX_PARALLEL_HTTP=24 \
    WEBUSER_HOME="/home/webuser" \
    PUID=9999 \
    PGID=9999 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome

COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /opt/yarn-v1.22.19 /opt/yarn-v1.22.19
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /opt/yarn-v1.22.19/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn-v1.22.19/bin/yarnpkg /usr/local/bin/yarnpkg

RUN  \
    # configure web user and group
    groupadd -r -g $PGID webgroup \
    && useradd --no-log-init -r -s /usr/bin/bash -d $WEBUSER_HOME -u $PUID -g $PGID webuser \
    # timezone
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    # install system dependencies
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        ca-certificates \
        curl \
        unzip \
    # Add required apt repositories
    && curl --output /usr/share/keyrings/nginx-keyring.gpg https://unit.nginx.org/keys/nginx-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-keyring.gpg] https://packages.nginx.org/unit/ubuntu/ jammy unit" > /etc/apt/sources.list.d/unit.list \
    && echo "deb-src [signed-by=/usr/share/keyrings/nginx-keyring.gpg] https://packages.nginx.org/unit/ubuntu/ jammy unit" >> /etc/apt/sources.list.d/unit.list \
    && apt-get install -y --no-install-recommends gnupg2 ca-certificates software-properties-common \
    && add-apt-repository -y ppa:ondrej/php \
    # Update packages and install stuff
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        # Install Nginx Unit and PHP extensions
        php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-imagick php${PHP_VERSION}-redis php${PHP_VERSION}-gd \
        php${PHP_VERSION}-igbinary php${PHP_VERSION}-readline php${PHP_VERSION}-curl php${PHP_VERSION}-intl \
        php${PHP_VERSION}-curl php${PHP_VERSION}-tokenizer php${PHP_VERSION}-mbstring php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-sqlite3 \
        unit unit-php \
        # Install dependencies
        cmake ghostscript gconf-service libasound2 libatk1.0-0 libatk-bridge2.0-0 libc6 \
        libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 \
        libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 \
        libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 \
        libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
        libxi6 libxrandr2 libxrender1 libxss1 libxtst6 ca-certificates \
        fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils wget libgbm-dev \
    # Install Google Chrome
    && curl -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb \
    # Clean up
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR ${WEBUSER_HOME}/code
RUN chown -R webuser:webgroup ${WEBUSER_HOME}

STOPSIGNAL SIGTERM
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock"]
