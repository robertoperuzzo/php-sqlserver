ARG FROM_TAG

FROM php:${FROM_TAG}

ARG PHP_DEV
ARG PHP_DEBUG

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

ENV PHP_DEV="${PHP_DEV}" \
    PHP_DEBUG="${PHP_DEBUG}"
    # \
    # LD_PRELOAD="/usr/lib/preloadable_libiconv.so php"

ENV APP_ROOT="/var/www/html" \
    CONF_DIR="/var/www/conf" \
    FILES_DIR="/mnt/files"

ENV PATH="${PATH}:/home/wodby/.composer/vendor/bin:${APP_ROOT}/vendor/bin:${APP_ROOT}/bin" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/wodby/.shrc" \
    \
    GIT_USER_EMAIL="wodby@robertoperuzzo.it" \
    GIT_USER_NAME="wodby"

RUN set -xe; \
    \
    # Delete existing user/group if uid/gid occupied.
    existing_group=$(getent group "${WODBY_GROUP_ID}" | cut -d: -f1); \
    if [[ -n "${existing_group}" ]]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${WODBY_USER_ID}" | cut -d: -f1); \
    if [[ -n "${existing_user}" ]]; then deluser "${existing_user}"; fi; \
    \
    addgroup --system --gid "${WODBY_GROUP_ID}" wodby; \
    adduser --system -u "${WODBY_USER_ID}"  --shell /bin/bash --ingroup wodby wodby; \
    adduser wodby www-data; \
    sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    # Debian packages
    apt-get update; \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        autoconf \
        bzip2 \
        cmake \
        fcgiwrap \
        findutils \
        git \
        gnupg \
        imagemagick \
        ldap-utils \
        less \
        libbz2-1.0 \
        libc-client2007e \
        libevent-2.0-5 \
        libfreetype6 \
        libgmp10 \
        libicu57 \
        #libjpeg62-turbo \
        libldap-2.4-2 \
        libltdl7 \
        libmemcached11 \
        libmcrypt4 \
        libpng16-16 \
        #librdkafka1 \
        #libuuid1 \
        #libwebp6 \
        libxml2 \
        #libxslt1.1 \
        libyaml-0-2 \
        libzip4 \
        locales \
        make \
        mariadb-client \
        nano \
        openssh-server \
        openssh-client \
        patch \
        pkg-config \
        rsync \
        sudo \
        tidy \
        tig \
        tmux \
        uw-mailutils; \
    \
    # Debian dev packages needed.
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libbz2-dev \
        libc-dev \
        libc-client2007e-dev \
        libevent-dev \
        libfreetype6-dev \
        libgmp-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libldap2-dev \
        libmagickwand-dev \
        libmagickcore-dev \
        libmcrypt-dev \
        libmemcached-dev \
        librabbitmq-dev \
        librdkafka-dev \
        libtidy-dev \
        uuid-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt1-dev \
        libyaml-dev \
        libzip-dev; \
    \
    docker-php-source extract; \
    \
    docker-php-ext-install \
        bcmath \
        bz2 \
        calendar \
        exif \
        gmp \
        intl \
        ldap \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        soap \
        sockets \
        tidy \
        xmlrpc \
        xsl \
        zip; \
    \
    # GD
    docker-php-ext-configure gd \
        --with-gd \
        --with-webp-dir \
        --with-freetype-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/; \
      NPROC=$(getconf _NPROCESSORS_ONLN); \
      docker-php-ext-install "-j${NPROC}" gd; \
    \
    pecl config-set php_ini "${PHP_INI_DIR}/php.ini"; \
    \
    # IMAP
    docker-php-ext-configure imap \
        --with-kerberos \
        --with-imap-ssl; \
    docker-php-ext-install "-j${NPROC}" imap; \
    # mcrypt moved to pecl in PHP 7.2
    pecl install mcrypt-1.0.2; \
    docker-php-ext-enable mcrypt; \
    \
    pecl install \
        amqp-1.9.4 \
        apcu-5.1.17 \
        ast-1.0.0 \
        ds-1.2.6 \
        event-2.4.4 \
        grpc-1.17.0 \
        igbinary-3.0.0 \
        imagick-3.4.3 \
        memcached-3.1.3 \
        mongodb-1.5.3 \
        oauth-2.0.3 \
        rdkafka-3.1.0 \
        #redis-4.2.0 \
        uuid-1.0.4 \
        xdebug-2.7.1 \
        yaml-2.0.4; \
    \
    docker-php-ext-enable \
        amqp \
        apcu \
        ast \
        ds \
        event \
        igbinary \
        imagick \
        grpc \
        memcached \
        mongodb \
        oauth \
        #redis \
        rdkafka \
        uuid \
        xdebug \
        yaml;

    # # Microsoft SQL Server Prerequisites
    # curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    #    && curl https://packages.microsoft.com/config/debian/9/prod.list \
    #        > /etc/apt/sources.list.d/mssql-release.list \
    # ;
    # apt-get update; \
    # apt-get install -y --no-install-recommends \
    #   unixodbc-dev \
    #   msodbcsql17 \
    #   libxml2-dev \
    # ;\
    # docker-php-ext-install mbstring pdo pdo_mysql soap; \
    # pecl install sqlsrv pdo_sqlsrv xdebug; \
    # docker-php-ext-enable sqlsrv pdo_sqlsrv xdebug;
    # /
    # apt-get clean; \
    # rm -rf \
    #     /var/lib/apt/lists/* \
    #     /tmp/*;

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 9000

COPY docker-entrypoint.sh /
#COPY ./bin /usr/local/bin/

#ENTRYPOINT ["/docker-entrypoint.sh"]
#CMD ["sudo", "-E", "LD_PRELOAD=/usr/lib/preloadable_libiconv.so", "php-fpm"]
