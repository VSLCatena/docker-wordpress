#!/bin/sh
#db_name=$(grep -Po '(?<=WORDPRESS_DB_NAME: )(.*)' docker-compose.yml)
#db_user=$(grep -Po '(?<=WORDPRESS_DB_USER: )(.*)' docker-compose.yml)
#db_pass=$(grep -Po '(?<=WORDPRESS_DB_PASSWD: )(.*)' docker-compose.yml)
#db_host=$(grep -Po '(?<=WORDPRESS_DB_HOST: )(.*)' docker-compose.yml)
docker-compose run wp-cli user list

#docker run -it --rm \
#    --volumes-from wp \
#    --network container:wp  \
#    --env DB_USER=db_user --env DB_PASSWORD=db_pass --env DB_HOST=db_host \
#     wordpress:cli-php8.0 user list
