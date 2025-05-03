FROM php:8.3-apache

ARG GLPI_VERSION=10.0.14

# Install required PHP extensions and system packages
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libxml2-dev libonig-dev libzip-dev libicu-dev \
    libldap2-dev libssl-dev libbz2-dev \
    unzip curl build-essential rsync \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install \
    pdo pdo_mysql mysqli gd xml mbstring zip bcmath intl \
    exif ldap bz2 opcache \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache rewrite
RUN a2enmod rewrite


# Set working directory and download/extract GLPI
WORKDIR /var/www/
# First copy the tar file into the image
COPY glpi-10.0.18.tgz /tmp/

# Now run the tar command to extract it
RUN tar -xzvf /tmp/glpi-10.0.18.tgz -C /var/www/

# Set ownership and permissions for GLPI
RUN chown -R www-data:www-data /var/www/glpi && \
    chmod -R 755 /var/www/glpi

# Move GLPI variable data to /var/lib/glpi and create required directories with correct permissions
RUN mv /var/www/glpi/files /var/lib/glpi && \
    mkdir -p /var/lib/glpi/{_cache,_cron,_dumps,_graphs,_lock,_pictures,_plugins,_rss,_sessions,_tmp,_uploads} && \
    mkdir -p /var/log/glpi && \
    chown -R www-data:www-data /var/lib/glpi /var/log/glpi && \
    chmod -R 775 /var/lib/glpi /var/log/glpi

# Configure downstream.php
RUN echo "<?php \
define('GLPI_CONFIG_DIR', '/var/www/glpi/config/'); \
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) { \
    require_once GLPI_CONFIG_DIR . '/local_define.php'; \
} \
?>" > /var/www/glpi/inc/downstream.php

# Configure local_define.php for GLPI configuration
RUN mkdir -p /etc/glpi && \
    echo "<?php \
define('GLPI_VAR_DIR', '/var/lib/glpi'); \
define('GLPI_LOG_DIR', '/var/log/glpi'); \
?>" > /var/www/glpi/config/local_define.php

# Configure PHP settings
RUN echo "memory_limit = 256M" > /usr/local/etc/php/conf.d/glpi.ini \
 && echo "upload_max_filesize = 20M" >> /usr/local/etc/php/conf.d/glpi.ini \
 && echo "post_max_size = 20M" >> /usr/local/etc/php/conf.d/glpi.ini \
 && echo "max_execution_time = 60" >> /usr/local/etc/php/conf.d/glpi.ini \
 && echo "session.cookie_httponly = On" >> /usr/local/etc/php/conf.d/glpi.ini

# Copy Apache config for GLPI site
COPY glpi.conf /etc/apache2/sites-available/000-default.conf

EXPOSE 80
