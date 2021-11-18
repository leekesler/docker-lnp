# ---------------------------------------------- Build Time Arguments --------------------------------------------------
ARG ALPINE_VERSION="3.14"
ARG NGINX_PREFIX=/etc/nginx
ARG NGINX_VERSION="1.17.4"
ARG PHP_PREFIX=/etc/php7
ARG PHP_VERSION="7.4.25"

# ======================================================================================================================
# ======================================================================================================================
#                                                  --- NGINX ---
# ======================================================================================================================
# ======================================================================================================================
FROM alpine:${ALPINE_VERSION} AS nginx

ARG NGINX_PREFIX
ARG NGINX_VERSION

# compile Nginx from latest source
RUN apk --update add openssl-dev pcre-dev zlib-dev wget build-base && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxvf nginx-${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/nginx-${NGINX_VERSION} && \
    ./configure \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --prefix=${NGINX_PREFIX} \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log && \
    make && make install && \
    apk del build-base && \
    rm -rf /tmp/src && rm -rf /var/cache/apk/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log


# ======================================================================================================================
#                                                   --- PHP-Common ---
# ---------------------------  PHP extenstions, plugins and add all needed configurations  ----------------------------
# ======================================================================================================================
FROM alpine:${ALPINE_VERSION} AS php-common	

ARG NGINX_PREFIX
ARG PHP_PREFIX
ARG PHP_VERSION
ENV PATH ${PHP_PREFIX}/bin:$PATH

# install required modules
RUN apk add --no-cache make \
        g++ \
        tar \
        file \
        perl \
        xz \
        gcc \
        autoconf \
        pkgconf \
        curl \
		curl-dev \
        libsodium-dev \
        libedit-dev \
        apr-dev \
        apr-util-dev \
        coreutils \
        libxml2-dev \
        openssl \
		openssl-dev \
        sqlite-dev \
        ca-certificates \
        re2c \
        dpkg \
		dpkg-dev \
        argon2-dev \
        libc-dev

# set directory to php path
WORKDIR $PHP_PREFIX

# create www-data user if it does not exist
RUN set -x && \
	getent group www-data || addgroup -g 82 -S www-data && \
	adduser -u 82 -D -S -G www-data www-data && \
    mkdir -p "$PHP_PREFIX" chown www-data:www-data "$PHP_PREFIX"

# compile PHP from latest source
RUN wget https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz && \
    gzip -d php-${PHP_VERSION}.tar.gz && \
    tar -xf php-${PHP_VERSION}.tar && \
    rm php-${PHP_VERSION}.tar && \
    cd php-${PHP_VERSION} && ./configure \
        --enable-fpm \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --prefix=${PHP_PREFIX} \
    && make && make install

# setup php-fpm and remove alpine cache
RUN mv etc/php-fpm.d/www.conf.default etc/php-fpm.d/www.conf
RUN mv etc/php-fpm.conf.default etc/php-fpm.conf
RUN rm -rf php-${PHP_VERSION} && rm -rf /var/cache/apk/*

# compile xdebug module from latest source
RUN wget https://pecl.php.net/get/xdebug-3.1.1.tar && \
    tar -xf xdebug-3.1.1.tar && \
    cd xdebug-3.1.1 && \
    ${PHP_PREFIX}/bin/phpize && \
    ./configure --enable-xdebug && \
    make && \
    make install && \
    cd ../ && \
    rm xdebug-3.1.1.tar && \
    rm -rf xdebug-3.1.1/

# configure xdebug
ADD --chown=root:root include/xdebug.ini ${PHP_PREFIX}/conf.d/xdebug.ini

# compile redis module from latest source
RUN wget https://pecl.php.net/get/redis-5.3.4.tar && \
    tar -xf redis-5.3.4.tar && \
    cd redis-5.3.4 && \
    ${PHP_PREFIX}/bin/phpize && \
    ./configure --enable-redis && \
    make && make install && \
    cd ../ && \
    rm redis-5.3.4.tar && \
    rm -rf redis-5.3.4/

# ======================================================================================================================
#                                                   --- Base ---
# ======================================================================================================================
FROM alpine:${ALPINE_VERSION}

ARG NGINX_PREFIX
ARG NGINX_VERSION
ARG PHP_PREFIX
ARG PHP_VERSION

# install required modules
RUN apk add --no-cache \
    bash \
    tar \
    curl \
    xz \
    ca-certificates \
    openssl \
    sqlite-dev
    
# create www-data user if it does not exist
RUN set -x && \
	getent group www-data || addgroup -g 82 -S www-data && \
	adduser -u 82 -D -S -G www-data www-data

# setup paths
ENV PATH ${PHP_PREFIX}/bin:$PATH
ENV PATH ${NGINX_PREFIX}/sbin:$PATH
RUN mkdir -p "$PHP_PREFIX" chown www-data:www-data "$PHP_PREFIX"
RUN mkdir -p "$NGINX_PREFIX" chown www-data:www-data "$NGINX_PREFIX"

# copy php binaries from base
RUN apk add --no-cache \
    argon2-libs \
    libedit \
    libxml2
COPY --from=php-common ${PHP_PREFIX} ${PHP_PREFIX}

# copy nginx binaries from base
RUN apk add --no-cache \
    openssl \
    pcre \
    zlib
COPY --from=nginx ${NGINX_PREFIX} ${NGINX_PREFIX}

# copy required files and set volume
COPY include/default.conf ${NGINX_PREFIX}/conf/
COPY include/nginx.conf ${NGINX_PREFIX}/conf/
COPY include/launch.sh ${NGINX_PREFIX}/sbin
VOLUME ["/var/log/nginx"]

# set php initialization file
COPY include/php.ini ${PHP_PREFIX}/lib/php.ini

# set working dir
WORKDIR /var/www/html/

EXPOSE 80

CMD ["launch.sh"]
