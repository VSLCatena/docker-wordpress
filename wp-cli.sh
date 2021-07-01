#!/bin/sh
if [[ $1 == "init" ]]; then
    wp_url=$2
    wp_title=$3
    wp_user="netcie"
    wp_mail="netcie@vslcatena.nl"
    wp_pw=$4
    wp_container=$5
    wp_docker="docker-compose run --rm --user="33:33" -e HOME=/tmp $wp_container"
    if [ -f './.WP_INITIALIZED' ]; then
        echo "already initialised"
    else
        touch ./.WP_INITIALIZED
        $wp_docker core install --url=$wp_url --title=$wp_title --admin_user=$wp_user --admin_password=$wp_pw --admin_email=$wp_mail
        $wp_docker plugin install --activate better-wp-security redirection cookie-notice disable-comments google-calendar-events wp-mail-smtp maintenance wordfence
        $wp_docker plugin auto-updates enable --all
     #   $wp_docker user create $username $mail --role=administrator
    fi
else
    $wp_docker $@
fi
    

