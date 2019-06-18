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
        ca-certificates \
        cmake \
        cron \
        fcgiwrap \
        findutils \
        git \
        gnupg \
        gosu \
        gzip \
        imagemagick \
        ldap-utils \
        less \
        libbz2-1.0 \
        libc6 \
        libc-client2007e \
        libevent-2.0-5 \
        libfcgi \
        libfcgi-bin \
        libfreetype6 \
        libgmp10 \
        libicu57 \
        libldap-2.4-2 \
        libltdl7 \
        libmemcached11 \
        libmcrypt4 \
        libpng16-16 \
        libxml2 \
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
        tar \
        tidy \
        tig \
        tmux \
        unzip \
        uw-mailutils \
        wget; \
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
        pdo \
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
    # NewRelic extension and agent.
    echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list; \
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - ; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        newrelic-php5; \
    sudo newrelic-install install; \
    rm /usr/local/etc/php/conf.d/newrelic.ini; \
    \
    # Sendmail
    apt-get update; \
    apt-get install -y --no-install-recommends \
        sendmail; \
    yes | sudo sendmailconfig; \
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
        rdkafka \
        uuid \
        xdebug \
        yaml; \
    \
    # Event extension should be loaded after sockets.
    # http://osmanov-dev-notes.blogspot.com/2013/07/fixing-php-start-up-error-unable-to.html
    mv /usr/local/etc/php/conf.d/docker-php-ext-event.ini /usr/local/etc/php/conf.d/z-docker-php-ext-event.ini; \
    \
    # Blackfire extension (they have free tier).
    wget -q -O - https://packages.blackfire.io/gpg.key | sudo apt-key add - ; \
    echo "deb http://packages.blackfire.io/debian any main" | sudo tee /etc/apt/sources.list.d/blackfire.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        blackfire-agent \
        blackfire-php; \
    docker-php-ext-enable blackfire; \
    \
    # Uploadprogress.
    mkdir -p /usr/src/php/ext/uploadprogress; \
    up_url="https://github.com/wodby/pecl-php-uploadprogress/archive/latest.tar.gz"; \
    wget -qO- "${up_url}" | tar xz --strip-components=1 -C /usr/src/php/ext/uploadprogress; \
    docker-php-ext-install uploadprogress; \
    \
    # Tideways xhprof.
    xhprof_ext_ver="5.0-beta2"; \
    mkdir -p /usr/src/php/ext/tideways_xhprof; \
    xhprof_url="https://github.com/tideways/php-xhprof-extension/archive/v${xhprof_ext_ver}.tar.gz"; \
    wget -qO- "${xhprof_url}" | tar xz --strip-components=1 -C /usr/src/php/ext/tideways_xhprof; \
    docker-php-ext-install tideways_xhprof; \
    \
    wget -qO- https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; \
    \
    # Install Walter (deprecated).
    walter_ver="1.4.0"; \
    walter_url="https://github.com/walter-cd/walter/releases/download/v${walter_ver}/walter_${walter_ver}_linux_amd64.tar.gz"; \
    wget -qO- "${walter_url}" | tar xz -C /tmp/; \
    mv /tmp/walter_linux_amd64/walter /usr/local/bin; \
    \
    { \
        echo 'export PS1="\u@${WODBY_APP_NAME:-php}.${WODBY_ENVIRONMENT_NAME:-container}:\w $ "'; \
        # Make sure PATH is the same for ssh sessions.
        echo "export PATH=${PATH}"; \
    } | tee /home/wodby/.shrc; \
    \
    cp /home/wodby/.shrc /home/wodby/.bashrc; \
    cp /home/wodby/.shrc /home/wodby/.bash_profile; \
    \
    { \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR"' ; \
        \
        if [[ -n "${PHP_DEV}" ]]; then \
            echo 'wodby ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'wodby ALL=(root) NOPASSWD:SETENV: ' ; \
            echo -n '/usr/local/bin/files_chmod, ' ; \
            echo -n '/usr/local/bin/files_chown, ' ; \
            echo -n '/usr/local/bin/files_sync, ' ; \
            echo -n '/usr/local/bin/gen_ssh_keys, ' ; \
            echo -n '/usr/local/bin/init_container, ' ; \
            echo -n '/usr/local/bin/migrate, ' ; \
            echo -n '/usr/local/sbin/php-fpm, ' ; \
            echo -n '/usr/sbin/sshd, ' ; \
            echo '/usr/sbin/cron' ; \
        fi; \
    } | tee /etc/sudoers.d/wodby; \
    \
    # Create the PrivSep empty dir if necessary
    if [ ! -d /var/run/sshd ]; then \
       sudo mkdir /var/run/sshd; \
       sudo chmod 0755 /var/run/sshd; \
    fi; \
    #echo "TLS_CACERTDIR /etc/ssl/certs/" >> /etc/openldap/ldap.conf; \
    \
    install -o wodby -g wodby -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        /home/wodby/.ssh; \
    \
    install -o www-data -g www-data -d \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${FILES_DIR}/sessions" \
        "${FILES_DIR}/xdebug/traces" \
        "${FILES_DIR}/xdebug/profiler" \
        /home/www-data/.ssh; \
    \
    chmod -R 775 "${FILES_DIR}"; \
    chown -R wodby:wodby \
        "${PHP_INI_DIR}/conf.d" \
        /usr/local/etc/php-fpm.d \
        /home/wodby/.[^.]*; \
    \
    touch /etc/ssh/sshd_config; \
    chown wodby: /etc/ssh/sshd_config; \
    \
    # rm /etc/crontabs/root; \
    # deprecated: remove in favor of bind mounts.
    touch /etc/cron.d/www-data; \
    chown root:www-data /etc/cron.d/www-data; \
    chmod 660 /etc/cron.d/www-data; \
    \
    # Microsoft SQL Server Prerequisites
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
       && curl https://packages.microsoft.com/config/debian/9/prod.list \
           > /etc/apt/sources.list.d/mssql-release.list; \
    \
    apt-get update;\
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
      unixodbc-dev \
      msodbcsql17 \
      libxml2-dev \
      mssql-tools; \
    \
    docker-php-ext-install mbstring; \
    pecl install sqlsrv pdo_sqlsrv; \
    docker-php-ext-enable sqlsrv pdo_sqlsrv; \
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc; \
    /bin/bash -c "source ~/.bashrc"; \
    \
    #
    composer clear-cache; \
    docker-php-source delete; \
    apt-get clean; \
    pecl clear-cache; \
    rm -rf \
        /var/lib/apt/lists/* \
        /usr/src/php/ext/ast \
        /usr/src/php/ext/uploadprogress \
        /usr/include/php \
        /usr/lib/php/build \
        /tmp/* \
        /root/.composer;

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 9000

COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY ./bin /usr/local/bin/

ENTRYPOINT ["/docker-entrypoint.sh"]
#CMD ["sudo", "-E", "LD_PRELOAD=/usr/lib/preloadable_libiconv.so", "php-fpm"]
CMD ["sudo", "-E", "php-fpm"]
