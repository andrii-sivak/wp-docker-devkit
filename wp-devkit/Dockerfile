# syntax=docker/dockerfile:1

# Default pin is the multi-arch index digest validated on 24 October 2026.
# PHP 8.4.27 / WordPress 7.1.3 on Debian 13. Override PHP_BASE_IMAGE to try
# another tag; do not treat an untested tag as a supported runtime.
ARG PHP_BASE_IMAGE=wordpress:php8.4-fpm@sha256:41fcfa8617e811e41516783bda46046f0945d94d547f346617bbea5e189b30bc
FROM ${PHP_BASE_IMAGE}

ARG COMPOSER_VERSION=2.10.3
ARG COMPOSER_SHA256=7a2d379d5b8ffdaa028580ef26494c36d2feef4b178d3dd1473a4dbc5e17c8d6
ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA256=ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c
ARG INSTALL_PDO_MYSQL=0

# The upstream entrypoint must start as root. It repairs a root-owned mount
# and then runs PHP-FPM workers as www-data (uid 33). Setting USER earlier
# breaks that contract, so this image intentionally keeps a root entrypoint.
# Debian 11's security index still lists mariadb-client 10.5.29 and
# libfcgi-bin 2.4.2-2+deb11u1, but those pool files return HTTP 404.
# That is an archive mismatch, not a PHP failure. Fall back to the
# main-archive versions, which are present, and do not keep the pin.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && packages='ca-certificates curl less libfcgi-bin mariadb-client unzip' \
    && if ! apt-get install -y --no-install-recommends $packages; then \
         printf 'Package: *\nPin: release l=Debian-Security\nPin-Priority: -1\n' \
           > /etc/apt/preferences.d/wp-devkit-skip-broken-security; \
         apt-get install -y --no-install-recommends $packages; \
         rm -f /etc/apt/preferences.d/wp-devkit-skip-broken-security; \
       fi \
    && if [ "$INSTALL_PDO_MYSQL" = "1" ]; then \
         docker-php-ext-install pdo_mysql; \
       fi \
    && curl -fsSL -o /usr/local/bin/composer \
        "https://github.com/composer/composer/releases/download/${COMPOSER_VERSION}/composer.phar" \
    && echo "${COMPOSER_SHA256}  /usr/local/bin/composer" | sha256sum -c - \
    && chmod 755 /usr/local/bin/composer \
    && curl -fsSL -o /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && echo "${WP_CLI_SHA256}  /usr/local/bin/wp" | sha256sum -c - \
    && chmod 755 /usr/local/bin/wp \
    && composer --version \
    && wp --info

COPY php/zz-devkit.conf /usr/local/etc/php-fpm.d/zz-devkit.conf
COPY php/devkit.ini /usr/local/etc/php/conf.d/devkit.ini
COPY php/zz-client.cnf /etc/mysql/conf.d/zz-devkit.cnf
COPY bin/wp-devkit-entrypoint.sh /usr/local/bin/wp-devkit-entrypoint.sh
COPY bin/wp-cli-wrapper.sh /usr/local/bin/wp-cli-wrapper.sh
COPY bin/php-fpm-devkit.sh /usr/local/bin/php-fpm
COPY bin/sql-client-wrapper.sh /usr/local/bin/sql-client-wrapper.sh
RUN chmod 755 /usr/local/bin/wp-devkit-entrypoint.sh /usr/local/bin/wp-cli-wrapper.sh /usr/local/bin/php-fpm /usr/local/bin/sql-client-wrapper.sh \
    && mv /usr/local/bin/wp /usr/local/lib/wp-cli.phar \
    && cp /usr/local/bin/wp-cli-wrapper.sh /usr/local/bin/wp \
    && chmod 755 /usr/local/bin/wp \
    && for cmd in mysql mariadb mysqldump mariadb-dump mysqlcheck mariadb-check; do \
         if [ -x "/usr/bin/$cmd" ]; then \
           cp /usr/local/bin/sql-client-wrapper.sh "/usr/local/bin/$cmd"; \
         fi; \
       done

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["wp-devkit-entrypoint.sh"]
CMD ["php-fpm"]

LABEL org.opencontainers.image.title="wp-docker-devkit-php" \
      org.opencontainers.image.description="WordPress PHP-FPM with Composer, WP-CLI, and a MariaDB/MySQL client"
