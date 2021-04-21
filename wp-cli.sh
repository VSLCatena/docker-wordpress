#!/bin/sh
docker-compose run --rm wp-cli wp-cli "$@"
