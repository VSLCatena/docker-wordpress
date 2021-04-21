#!/bin/sh
docker-compose run --rm --user="33:33" -e HOME=/tmp wp_cli wp-cli $@

#wp-cli core install --url=192.168.1.4:9001 --title="WP-CLI" --admin_user=wpcli --admin_password=wpcli --admin_email=info@wp-cli.org --path='/var/www/html/'
#wp-cli plugin install better-wp-security redirection
