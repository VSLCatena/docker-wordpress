#!/bin/sh
read -p "wp-cli container name:" container
if [ -f './.WP_INITIALIZED' ]; then
    docker-compose run --rm --user="33:33" -e HOME=/tmp $container wp-cli $@
else
    touch ./.WP_INITIALIZED
    read -p "Mail address of new user:" mail
    read -p "Username of new user:" username
    docker-compose run --rm --user="33:33" -e HOME=/tmp $container plugin install --activate better-wp-security redirection cookie-notice disable-comments google-calendar-events wp-mail-smtp maintenance wordfence
    #docker-compose run --rm --user="33:33" -e HOME=/tmp $container plugin auto-updates enable --all
    docker-compose run --rm --user="33:33" -e HOME=/tmp $container user create $username $mail --role=administrator
fi
